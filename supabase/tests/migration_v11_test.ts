// Exercises migration_v11_identify_trials.sql on top of v9, on an in-process Postgres (PGlite).
// Run: deno test --node-modules-dir=none -A supabase/tests/
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { PGlite } from "npm:@electric-sql/pglite@0.5.13";

const read = (name: string) => Deno.readTextFile(new URL(`../../${name}`, import.meta.url));
const V9 = await read("migration_v9_identify_requests.sql");
const V11 = await read("migration_v11_identify_trials.sql");

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
  return db;
}

type Claim = { allowed: boolean; request_id: string | null; used: number; reason: string };

async function claimTrial(db: PGlite, trialCap: number, globalCap = 300): Promise<Claim> {
  const res = await db.query<Claim>("select * from public.claim_identify_trial_slot($1, $2)", [trialCap, globalCap]);
  return res.rows[0];
}

async function claimUser(db: PGlite, monthly: number, globalCap = 300): Promise<Claim> {
  const res = await db.query<Claim>("select * from public.claim_identify_slot($1, $2, $3)", [ALICE, monthly, globalCap]);
  return res.rows[0];
}

Deno.test("v11 is safe to re-run on top of v9", async () => {
  const db = await freshDb();
  await db.exec(V11);
  await db.exec(V11);
  assertEquals((await claimTrial(db, 5)).allowed, true);
  await db.close();
});

Deno.test("free tries count up to the daily cap", async () => {
  const db = await freshDb();
  const results = [await claimTrial(db, 2), await claimTrial(db, 2), await claimTrial(db, 2)];
  assertEquals(results.map((r) => [r.allowed, r.reason]), [[true, "ok"], [true, "ok"], [false, "trial_limit"]]);
  const rows = await db.query<{ user_id: string | null; is_trial: boolean }>(
    "select user_id, is_trial from public.ai_identify_requests",
  );
  assertEquals(rows.rows, [{ user_id: null, is_trial: true }, { user_id: null, is_trial: true }]);
  await db.close();
});

Deno.test("free tries that failed before the model answered don't count", async () => {
  const db = await freshDb();
  const first = await claimTrial(db, 1);
  assertEquals((await claimTrial(db, 1)).allowed, false);
  await db.query("update public.ai_identify_requests set status = 'failed' where id = $1", [first.request_id]);
  assertEquals((await claimTrial(db, 1)).allowed, true);
  await db.close();
});

Deno.test("failed calls the model billed for still count toward the daily caps", async () => {
  const db = await freshDb();
  const billed = "update public.ai_identify_requests set status = 'failed', output_tokens = 900 where id = $1";

  const trial = await claimTrial(db, 1);
  await db.query(billed, [trial.request_id]);
  assertEquals((await claimTrial(db, 1)).reason, "trial_limit");

  const user = await claimUser(db, 1, 3);
  await db.query(billed, [user.request_id]);
  // The user's monthly quota forgives the failure...
  const retry = await claimUser(db, 1, 3);
  assertEquals([retry.allowed, retry.used], [true, 1]);
  // ...but the global cap counts both billed failures plus the retry.
  assertEquals((await claimUser(db, 5, 3)).reason, "global_limit");
  await db.close();
});

Deno.test("no more than three free tries run at once", async () => {
  const db = await freshDb();
  const running = [await claimTrial(db, 100), await claimTrial(db, 100), await claimTrial(db, 100)];
  assertEquals(running.map((r) => r.allowed), [true, true, true]);
  const fourth = await claimTrial(db, 100);
  assertEquals([fourth.allowed, fourth.reason, fourth.request_id], [false, "in_flight", null]);
  // Once one finishes, another can start.
  await db.query("update public.ai_identify_requests set status = 'ok' where id = $1", [running[0].request_id]);
  assertEquals((await claimTrial(db, 100)).allowed, true);
  await db.close();
});

Deno.test("abandoned free tries stop blocking after three minutes but still count", async () => {
  const db = await freshDb();
  await db.exec(`
    insert into public.ai_identify_requests (user_id, is_trial, created_at)
    select null, true, now() - interval '4 minutes' from generate_series(1, 3);
  `);
  const res = await claimTrial(db, 100);
  assertEquals([res.allowed, res.used], [true, 4]);
  await db.close();
});

Deno.test("free tries and signed-in requests share the global cap", async () => {
  const db = await freshDb();
  assertEquals((await claimUser(db, 10, 2)).allowed, true);
  assertEquals((await claimTrial(db, 10, 2)).allowed, true);
  const third = await claimTrial(db, 10, 2);
  assertEquals([third.allowed, third.reason], [false, "global_limit"]);
  assertEquals((await claimUser(db, 10, 2)).reason, "global_limit");
  // A user's monthly count ignores anonymous tries.
  assertEquals((await claimUser(db, 10, 300)).used, 2);
  await db.close();
});

Deno.test("each row is either a user's request or a free try", async () => {
  const db = await freshDb();
  await assertRejects(() => db.query("insert into public.ai_identify_requests (user_id, is_trial) values (null, false)"));
  await assertRejects(() =>
    db.query("insert into public.ai_identify_requests (user_id, is_trial) values ($1, true)", [ALICE])
  );
  await db.close();
});

Deno.test("only the service role can claim, for free tries and signed-in requests alike", async () => {
  const db = await freshDb();
  for (const fn of ["claim_identify_trial_slot(integer, integer)", "claim_identify_slot(uuid, integer, integer)"]) {
    const canExecute = async (role: string) =>
      (await db.query<{ ok: boolean }>(
        "select has_function_privilege($1, $2, 'execute') as ok",
        [role, `public.${fn}`],
      )).rows[0].ok;
    assertEquals(await canExecute("anon"), false, fn);
    assertEquals(await canExecute("authenticated"), false, fn);
    assertEquals(await canExecute("service_role"), true, fn);
  }
  await db.close();
});
