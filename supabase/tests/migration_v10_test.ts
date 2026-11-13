// Exercises migration_v10_verified_pro_purchases.sql on an in-process Postgres
// (PGlite), on top of v6 (profiles), with a minimal stand-in for Supabase's auth
// schema, API roles and default grants.
// Run: deno test --node-modules-dir=none -A supabase/tests/
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { PGlite } from "npm:@electric-sql/pglite@0.5.13";

const V6 = await Deno.readTextFile(new URL("../../migration_v6_profiles.sql", import.meta.url));
const V10 = await Deno.readTextFile(new URL("../../migration_v10_verified_pro_purchases.sql", import.meta.url));

// Supabase grants every API role full privileges on new tables and functions in
// public; RLS and explicit revokes are what actually lock them down. The stub
// mirrors that so a missing revoke shows up here.
const SUPABASE_STUB = `
  create role anon nologin;
  create role authenticated nologin;
  create role service_role nologin bypassrls;
  create schema auth;
  create table auth.users (id uuid primary key);
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  grant usage on schema auth to anon, authenticated, service_role;
  grant execute on function auth.uid() to anon, authenticated, service_role;
  grant usage on schema public to anon, authenticated, service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
`;

const ALICE = "00000000-0000-0000-0000-00000000000a";
const BOB = "00000000-0000-0000-0000-00000000000b";

const PURCHASE = "2000000123456789";
const T0 = "2026-11-13T10:00:00Z"; // purchase signed
const T1 = "2026-11-14T10:00:00Z"; // refund signed
const T2 = "2026-11-15T10:00:00Z"; // refund reversed

async function freshDb({ withV10 = true } = {}): Promise<PGlite> {
  const db = new PGlite();
  await db.exec(SUPABASE_STUB);
  await db.exec(`insert into auth.users (id) values ('${ALICE}'), ('${BOB}');`);
  await db.exec(V6);
  if (withV10) await db.exec(V10);
  return db;
}

/** Runs `body` as a signed-in user, the way PostgREST does for a client request. */
async function asUser<T>(db: PGlite, userId: string, body: () => Promise<T>): Promise<T> {
  await db.exec(`set role authenticated; set request.jwt.claim.sub = '${userId}';`);
  try {
    return await body();
  } finally {
    await db.exec("reset role; reset request.jwt.claim.sub;");
  }
}

async function isPro(db: PGlite, userId: string): Promise<boolean | null> {
  const res = await db.query<{ is_pro: boolean }>("select is_pro from public.profiles where id = $1", [userId]);
  return res.rows[0]?.is_pro ?? null;
}

// The two ways a client could write the flag through the REST API:
// PATCH /profiles?id=eq.<uid> and POST /profiles with merge-duplicates.
const patchIsPro = (db: PGlite, userId: string) =>
  db.query("update public.profiles set is_pro = true where id = $1", [userId]);
const upsertIsPro = (db: PGlite, userId: string) =>
  db.query(
    `insert into public.profiles (id, is_pro) values ($1, true)
     on conflict (id) do update set is_pro = excluded.is_pro`,
    [userId],
  );

type Recorded = { outcome: string; caller_is_pro: boolean };

async function record(
  db: PGlite,
  userId: string,
  opts: { signedAt: string; revokedAt?: string | null; originalId?: string; environment?: string },
): Promise<Recorded> {
  await db.exec("set role service_role;");
  try {
    const res = await db.query<Recorded>(
      "select * from public.record_pro_transaction($1, $2, $3, $4, $5, $6, $7, $8, $9)",
      [
        userId,
        opts.originalId ?? PURCHASE,
        opts.originalId ?? PURCHASE,
        "com.yaremchuk.app.pro.lifetime",
        opts.environment ?? "Production",
        T0,
        opts.revokedAt ?? null,
        opts.revokedAt ? 0 : null,
        opts.signedAt,
      ],
    );
    return res.rows[0];
  } finally {
    await db.exec("reset role;");
  }
}

// ── The hole, and that v10 closes it ─────────────────────────────────────────

Deno.test("before v10, a signed-in user can grant themselves Pro", async () => {
  const db = await freshDb({ withV10: false });
  await asUser(db, ALICE, () => upsertIsPro(db, ALICE));
  assertEquals(await isPro(db, ALICE), true);

  await db.query("update public.profiles set is_pro = false where id = $1", [ALICE]);
  await asUser(db, ALICE, () => patchIsPro(db, ALICE));
  assertEquals(await isPro(db, ALICE), true);
  await db.close();
});

Deno.test("after v10, PATCH can't change is_pro", async () => {
  const db = await freshDb();
  await db.query("insert into public.profiles (id, is_pro) values ($1, false)", [ALICE]);

  await assertRejects(() => asUser(db, ALICE, () => patchIsPro(db, ALICE)), Error, "permission denied");
  assertEquals(await isPro(db, ALICE), false);
  await db.close();
});

Deno.test("after v10, insert and upsert can't create a Pro profile", async () => {
  const db = await freshDb();
  await assertRejects(() => asUser(db, ALICE, () => upsertIsPro(db, ALICE)), Error, "permission denied");
  assertEquals(await isPro(db, ALICE), null);

  await db.query("insert into public.profiles (id, is_pro) values ($1, false)", [ALICE]);
  await assertRejects(() => asUser(db, ALICE, () => upsertIsPro(db, ALICE)), Error, "permission denied");
  assertEquals(await isPro(db, ALICE), false);
  await db.close();
});

Deno.test("after v10, clients can't delete their profile either", async () => {
  const db = await freshDb();
  await db.query("insert into public.profiles (id, is_pro) values ($1, true)", [ALICE]);
  await assertRejects(
    () => asUser(db, ALICE, () => db.query("delete from public.profiles where id = $1", [ALICE])),
    Error,
    "permission denied",
  );
  await db.close();
});

Deno.test("users still read their own profile, and only their own", async () => {
  const db = await freshDb();
  await db.query("insert into public.profiles (id, is_pro) values ($1, true), ($2, false)", [ALICE, BOB]);
  const rows = await asUser(db, ALICE, () => db.query<{ id: string; is_pro: boolean }>("select id, is_pro from public.profiles"));
  assertEquals(rows.rows, [{ id: ALICE, is_pro: true }]);
  await db.close();
});

Deno.test("clients can't read or write pro_purchases", async () => {
  const db = await freshDb();
  await record(db, ALICE, { signedAt: T0 });
  await assertRejects(
    () => asUser(db, ALICE, () => db.query("select * from public.pro_purchases")),
    Error,
    "permission denied",
  );
  await assertRejects(
    () =>
      asUser(db, BOB, () =>
        db.query(
          `insert into public.pro_purchases (original_transaction_id, user_id, transaction_id, product_id, environment, signed_at)
           values ('1', $1, '1', 'com.yaremchuk.app.pro.lifetime', 'Production', now())`,
          [BOB],
        )),
    Error,
    "permission denied",
  );
  await db.close();
});

Deno.test("only the service role can execute record_pro_transaction", async () => {
  const db = await freshDb();
  const canExecute = async (role: string) =>
    (await db.query<{ ok: boolean }>(
      `select has_function_privilege($1,
         'public.record_pro_transaction(uuid, text, text, text, text, timestamptz, timestamptz, integer, timestamptz)',
         'execute') as ok`,
      [role],
    )).rows[0].ok;
  assertEquals(await canExecute("anon"), false);
  assertEquals(await canExecute("authenticated"), false);
  assertEquals(await canExecute("service_role"), true);

  await assertRejects(
    () =>
      asUser(db, ALICE, () =>
        db.query(
          "select * from public.record_pro_transaction($1, '1', '1', 'p', 'Production', now(), null, null, now())",
          [ALICE],
        )),
    Error,
    "permission denied",
  );
  assertEquals(await isPro(db, ALICE), null);
  await db.close();
});

Deno.test("migration is safe to re-run", async () => {
  const db = await freshDb();
  await record(db, ALICE, { signedAt: T0 });
  await db.exec(V10);
  await db.exec(V10);
  assertEquals(await isPro(db, ALICE), true);
  await assertRejects(() => asUser(db, ALICE, () => patchIsPro(db, ALICE)), Error, "permission denied");
  await db.close();
});

Deno.test("migration clears is_pro that no verified purchase backs", async () => {
  const db = await freshDb({ withV10: false });
  // Written through the old policies, as the exploit would have.
  await asUser(db, ALICE, () => upsertIsPro(db, ALICE));
  await db.exec(V10);
  assertEquals(await isPro(db, ALICE), false);
  await db.close();
});

// ── record_pro_transaction ───────────────────────────────────────────────────

Deno.test("a verified purchase makes its owner Pro", async () => {
  const db = await freshDb();
  assertEquals(await record(db, ALICE, { signedAt: T0 }), { outcome: "active", caller_is_pro: true });
  assertEquals(await isPro(db, ALICE), true);
  // Re-syncing the same transaction changes nothing.
  assertEquals(await record(db, ALICE, { signedAt: T0 }), { outcome: "active", caller_is_pro: true });
  await db.close();
});

Deno.test("a purchase can't be claimed by a second account", async () => {
  const db = await freshDb();
  await record(db, ALICE, { signedAt: T0 });
  assertEquals(await record(db, BOB, { signedAt: T0 }), { outcome: "claimed_by_other_account", caller_is_pro: false });
  // Not with a newer JWS for the same purchase either.
  assertEquals(await record(db, BOB, { signedAt: T2 }), { outcome: "claimed_by_other_account", caller_is_pro: false });
  assertEquals(await isPro(db, BOB), null);
  assertEquals(await isPro(db, ALICE), true);
  const owner = await db.query<{ user_id: string }>("select user_id from public.pro_purchases");
  assertEquals(owner.rows, [{ user_id: ALICE }]);
  await db.close();
});

Deno.test("a refund takes Pro away, and replaying the purchase JWS doesn't restore it", async () => {
  const db = await freshDb();
  await record(db, ALICE, { signedAt: T0 });
  assertEquals(await record(db, ALICE, { signedAt: T1, revokedAt: T1 }), { outcome: "revoked", caller_is_pro: false });
  assertEquals(await isPro(db, ALICE), false);

  // The JWS from the original purchase is still validly signed, but older.
  assertEquals(await record(db, ALICE, { signedAt: T0 }), { outcome: "revoked", caller_is_pro: false });
  assertEquals(await isPro(db, ALICE), false);
  await db.close();
});

Deno.test("a reversed refund (newer active JWS) restores Pro", async () => {
  const db = await freshDb();
  await record(db, ALICE, { signedAt: T0 });
  await record(db, ALICE, { signedAt: T1, revokedAt: T1 });
  assertEquals(await record(db, ALICE, { signedAt: T2 }), { outcome: "active", caller_is_pro: true });
  assertEquals(await isPro(db, ALICE), true);
  await db.close();
});

Deno.test("a revocation reported from another account still revokes the owner's Pro", async () => {
  const db = await freshDb();
  await record(db, ALICE, { signedAt: T0 });
  // Bob's device shares Alice's Apple ID and saw the refund first.
  assertEquals(await record(db, BOB, { signedAt: T1, revokedAt: T1 }), { outcome: "revoked", caller_is_pro: false });
  assertEquals(await isPro(db, ALICE), false);
  assertEquals(await isPro(db, BOB), null);
  await db.close();
});

Deno.test("a revoked purchase seen first is stored, so its old JWS can't be replayed", async () => {
  const db = await freshDb();
  assertEquals(await record(db, ALICE, { signedAt: T1, revokedAt: T1 }), { outcome: "revoked", caller_is_pro: false });
  assertEquals(await record(db, BOB, { signedAt: T0 }), { outcome: "revoked", caller_is_pro: false });
  assertEquals(await record(db, ALICE, { signedAt: T0 }), { outcome: "revoked", caller_is_pro: false });
  assertEquals(await isPro(db, BOB), null);
  assertEquals(await isPro(db, ALICE), false);
  await db.close();
});

Deno.test("a second purchase keeps Pro when the first is refunded", async () => {
  const db = await freshDb();
  await record(db, ALICE, { signedAt: T0, originalId: "1000" });
  await record(db, ALICE, { signedAt: T0, originalId: "2000" });
  assertEquals(await record(db, ALICE, { signedAt: T1, revokedAt: T1, originalId: "1000" }), {
    outcome: "revoked",
    caller_is_pro: true,
  });
  assertEquals(await isPro(db, ALICE), true);
  await db.close();
});

Deno.test("deleting the owning account frees the purchase", async () => {
  const db = await freshDb();
  await record(db, ALICE, { signedAt: T0 });
  await db.query("delete from auth.users where id = $1", [ALICE]);
  assertEquals(await record(db, BOB, { signedAt: T0 }), { outcome: "active", caller_is_pro: true });
  await db.close();
});

Deno.test("the purchase row keeps the newest state Apple signed", async () => {
  const db = await freshDb();
  await record(db, ALICE, { signedAt: T0 });
  await record(db, ALICE, { signedAt: T1, revokedAt: T1 });
  await record(db, ALICE, { signedAt: T0 });
  const row = await db.query<{ revoked_at: Date | null; signed_at: Date; revocation_reason: number | null }>(
    "select revoked_at, signed_at, revocation_reason from public.pro_purchases",
  );
  assertEquals(row.rows.length, 1);
  assert(row.rows[0].revoked_at !== null);
  assertEquals(row.rows[0].signed_at.toISOString(), new Date(T1).toISOString());
  assertEquals(row.rows[0].revocation_reason, 0);
  await db.close();
});
