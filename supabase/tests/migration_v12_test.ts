// Exercises migration_v12_identify_offers.sql on top of v9 and v11, on an in-process
// Postgres (PGlite), including the claim and release updates identify-product makes.
// Run: deno test --node-modules-dir=none -A supabase/tests/
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { PGlite } from "npm:@electric-sql/pglite@0.5.13";

const read = (name: string) => Deno.readTextFile(new URL(`../../${name}`, import.meta.url));
const V9 = await read("migration_v9_identify_requests.sql");
const V11 = await read("migration_v11_identify_trials.sql");
const V12 = await read("migration_v12_identify_offers.sql");

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

async function freshDb(): Promise<PGlite> {
  const db = new PGlite();
  await db.exec(SUPABASE_STUB);
  await db.exec(`insert into auth.users (id) values ('${ALICE}');`);
  await db.exec(V9);
  await db.exec(V11);
  await db.exec(V12);
  return db;
}

/** An identification row as identify-product leaves it after the model answered. */
async function identification(db: PGlite, resultStatus: string, status = "ok"): Promise<string> {
  const res = await db.query<{ id: string }>(
    `insert into public.ai_identify_requests (user_id, status, result_status)
     values ($1, $2, $3) returning id`,
    [ALICE, status, resultStatus],
  );
  return res.rows[0].id;
}

// The same conditional updates index.ts sends through PostgREST.
async function claimOffers(db: PGlite, id: string): Promise<boolean> {
  const res = await db.query(
    `update public.ai_identify_requests set offers_status = 'pending'
     where id = $1 and offers_status is null and status = 'ok' and result_status in ('identified', 'similar')
     returning id`,
    [id],
  );
  return res.rows.length > 0;
}

async function releaseOffers(db: PGlite, id: string): Promise<void> {
  await db.query(
    "update public.ai_identify_requests set offers_status = null where id = $1 and offers_status = 'pending'",
    [id],
  );
}

async function offersStatus(db: PGlite, id: string): Promise<string | null> {
  const res = await db.query<{ offers_status: string | null }>(
    "select offers_status from public.ai_identify_requests where id = $1",
    [id],
  );
  return res.rows[0].offers_status;
}

Deno.test("v12 is safe to re-run", async () => {
  const db = await freshDb();
  await db.exec(V12);
  await db.exec(V12);
  const id = await identification(db, "identified");
  assertEquals(await claimOffers(db, id), true);
  await db.close();
});

Deno.test("each identified product gets exactly one shop search", async () => {
  const db = await freshDb();
  const id = await identification(db, "identified");
  assertEquals(await offersStatus(db, id), null);
  assertEquals(await claimOffers(db, id), true);
  assertEquals(await claimOffers(db, id), false, "already pending");

  await db.query(
    `update public.ai_identify_requests set offers_status = 'ok', offers_found = 2, offers_searches = 2,
       offers_input_tokens = 9000, offers_output_tokens = 1200, offers_latency_ms = 21000,
       offers_model = 'claude-opus-5-5'
     where id = $1`,
    [id],
  );
  assertEquals(await claimOffers(db, id), false, "already searched");
  await db.close();
});

Deno.test("only an identified product or a close match can be searched", async () => {
  const db = await freshDb();
  for (const [resultStatus, status] of [["unclear", "ok"], ["not_a_product", "not_product"], ["identified", "failed"]]) {
    const id = await identification(db, resultStatus, status);
    assertEquals(await claimOffers(db, id), false, `${resultStatus}/${status}`);
  }
  assertEquals(await claimOffers(db, await identification(db, "similar")), true, "a close match");
  await db.close();
});

Deno.test("a released search can be claimed again; a finished one can't be released", async () => {
  const db = await freshDb();
  const id = await identification(db, "identified");
  await claimOffers(db, id);
  await releaseOffers(db, id);
  assertEquals(await offersStatus(db, id), null);
  assertEquals(await claimOffers(db, id), true);

  await db.query("update public.ai_identify_requests set offers_status = 'none' where id = $1", [id]);
  await releaseOffers(db, id);
  assertEquals(await offersStatus(db, id), "none");
  await db.close();
});

Deno.test("offers_status only takes the known values", async () => {
  const db = await freshDb();
  const id = await identification(db, "identified");
  for (const value of ["pending", "ok", "none", "failed"]) {
    await db.query("update public.ai_identify_requests set offers_status = $1 where id = $2", [value, id]);
  }
  await assertRejects(() =>
    db.query("update public.ai_identify_requests set offers_status = 'found' where id = $1", [id])
  );
  await db.close();
});
