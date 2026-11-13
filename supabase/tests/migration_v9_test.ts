// Exercises migration_v9_identify_requests.sql on an in-process Postgres (PGlite),
// with a minimal stand-in for Supabase's auth schema and API roles.
// Run: deno test --node-modules-dir=none -A supabase/tests/
import { assertEquals } from "jsr:@std/assert@1";
import { PGlite } from "npm:@electric-sql/pglite@0.5.13";

const MIGRATION = await Deno.readTextFile(new URL("../../migration_v9_identify_requests.sql", import.meta.url));

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
`;

const ALICE = "00000000-0000-0000-0000-00000000000a";
const BOB = "00000000-0000-0000-0000-00000000000b";

async function freshDb(): Promise<PGlite> {
  const db = new PGlite();
  await db.exec(SUPABASE_STUB);
  await db.exec(`insert into auth.users (id) values ('${ALICE}'), ('${BOB}');`);
  await db.exec(MIGRATION);
  await db.exec("grant select, insert, update on public.ai_identify_requests to service_role;");
  return db;
}

type Claim = { allowed: boolean; request_id: string | null; used: number; reason: string };

async function claim(db: PGlite, user: string, monthly: number, global = 300): Promise<Claim> {
  const res = await db.query<Claim>("select * from public.claim_identify_slot($1, $2, $3)", [user, monthly, global]);
  return res.rows[0];
}

Deno.test("migration is safe to re-run", async () => {
  const db = await freshDb();
  await db.exec(MIGRATION);
  await db.exec(MIGRATION);
  const res = await db.query<{ n: number }>("select count(*)::int as n from public.ai_identify_requests");
  assertEquals(res.rows[0].n, 0);
  await db.close();
});

Deno.test("claims count up to the monthly limit, then refuse", async () => {
  const db = await freshDb();
  const results = [];
  for (let i = 0; i < 4; i++) results.push(await claim(db, ALICE, 3));
  assertEquals(results.map((r) => [r.allowed, r.used, r.reason]), [
    [true, 1, "ok"],
    [true, 2, "ok"],
    [true, 3, "ok"],
    [false, 3, "monthly_limit"],
  ]);
  assertEquals(results[3].request_id, null);
  // Another user has their own quota.
  assertEquals((await claim(db, BOB, 3)).used, 1);
  await db.close();
});

Deno.test("failed requests stop counting against the quota", async () => {
  const db = await freshDb();
  const first = await claim(db, ALICE, 1);
  assertEquals((await claim(db, ALICE, 1)).allowed, false);
  await db.query("update public.ai_identify_requests set status = 'failed' where id = $1", [first.request_id]);
  const retry = await claim(db, ALICE, 1);
  assertEquals([retry.allowed, retry.used], [true, 1]);
  await db.close();
});

Deno.test("requests from earlier months don't count", async () => {
  const db = await freshDb();
  await db.query(
    `insert into public.ai_identify_requests (user_id, status, created_at)
     values ($1, 'ok', date_trunc('month', now()) - interval '1 day')`,
    [ALICE],
  );
  const res = await claim(db, ALICE, 1);
  assertEquals([res.allowed, res.used], [true, 1]);
  await db.close();
});

Deno.test("the global 24-hour cap applies across users", async () => {
  const db = await freshDb();
  assertEquals((await claim(db, ALICE, 10, 2)).allowed, true);
  assertEquals((await claim(db, BOB, 10, 2)).allowed, true);
  const third = await claim(db, ALICE, 10, 2);
  assertEquals([third.allowed, third.reason, third.used], [false, "global_limit", 1]);
  await db.close();
});

Deno.test("only the service role can execute claim_identify_slot", async () => {
  const db = await freshDb();
  const canExecute = async (role: string) =>
    (await db.query<{ ok: boolean }>(
      "select has_function_privilege($1, 'public.claim_identify_slot(uuid, integer, integer)', 'execute') as ok",
      [role],
    )).rows[0].ok;
  assertEquals(await canExecute("anon"), false);
  assertEquals(await canExecute("authenticated"), false);
  assertEquals(await canExecute("service_role"), true);
  await db.close();
});

Deno.test("users can read only their own request rows", async () => {
  const db = await freshDb();
  await claim(db, ALICE, 5);
  await claim(db, BOB, 5);
  await db.exec("grant select on public.ai_identify_requests to authenticated;");
  await db.exec(`set role authenticated; set request.jwt.claim.sub = '${ALICE}';`);
  const rows = await db.query<{ user_id: string }>("select user_id from public.ai_identify_requests");
  await db.exec("reset role;");
  assertEquals(rows.rows.map((r) => r.user_id), [ALICE]);
  await db.close();
});
