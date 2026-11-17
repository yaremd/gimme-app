// App Store Server Notifications end to end on an in-process Postgres (PGlite):
// the app-store-notifications handler, fed notifications signed with the test
// PKI, over migrations v6 and v10 and their real record_pro_transaction().
// The database calls are the ones index.ts makes through supabase-js, as SQL.
// Run: deno test --node-modules-dir=none -A supabase/tests/
import { assert, assertEquals } from "jsr:@std/assert@1";
import { PGlite } from "npm:@electric-sql/pglite@0.5.13";
import { appleJwsVerifier } from "../functions/_shared/apple_jws.ts";
import { makeTestPki, signJws, testPki } from "../functions/_shared/apple_test_pki.ts";
import { isRecordOutcome } from "../functions/_shared/pro_purchases.ts";
import { type Deps, handleAppStoreNotification } from "../functions/app-store-notifications/handler.ts";
import { SUPABASE_STUB } from "./supabase_stub.ts";

const V6 = await Deno.readTextFile(new URL("../../migration_v6_profiles.sql", import.meta.url));
const V10 = await Deno.readTextFile(new URL("../../migration_v10_verified_pro_purchases.sql", import.meta.url));

const ALICE = "00000000-0000-0000-0000-00000000000a";
const BOB = "00000000-0000-0000-0000-00000000000b";

const PURCHASE = "2000000123456789"; // Alice bought Pro
const SHARED = "2000000123459999"; // Bob's Family Sharing transaction for it
const T0 = Date.parse("2026-11-13T10:00:00Z"); // purchase signed
const T1 = Date.parse("2026-11-14T10:00:00Z"); // refund signed
const T2 = Date.parse("2026-11-15T10:00:00Z"); // refund reversed

async function freshDb(): Promise<PGlite> {
  const db = new PGlite();
  await db.exec(SUPABASE_STUB);
  await db.exec(`insert into auth.users (id) values ('${ALICE}'), ('${BOB}');`);
  await db.exec(V6);
  await db.exec(V10);
  return db;
}

async function asServiceRole<T>(db: PGlite, body: () => Promise<T>): Promise<T> {
  await db.exec("set role service_role;");
  try {
    return await body();
  } finally {
    await db.exec("reset role;");
  }
}

function depsFor(db: PGlite): Deps {
  return {
    verifyJws: appleJwsVerifier([testPki.root.cert]),
    findOwner: (originalTransactionId) =>
      asServiceRole(db, async () => {
        const res = await db.query<{ user_id: string }>(
          "select user_id from public.pro_purchases where original_transaction_id = $1",
          [originalTransactionId],
        );
        return res.rows[0]?.user_id ?? null;
      }),
    recordTransaction: (input) =>
      asServiceRole(db, async () => {
        const res = await db.query<{ outcome: string; caller_is_pro: boolean }>(
          "select * from public.record_pro_transaction($1, $2, $3, $4, $5, $6, $7, $8, $9)",
          [
            input.userId,
            input.originalTransactionId,
            input.transactionId,
            input.productId,
            input.environment,
            input.purchasedAt?.toISOString() ?? null,
            input.revokedAt?.toISOString() ?? null,
            input.revocationReason,
            input.signedAt.toISOString(),
          ],
        );
        const row = res.rows[0];
        if (!isRecordOutcome(row.outcome)) throw new Error(`Unexpected outcome ${row.outcome}`);
        return { outcome: row.outcome, isPro: row.caller_is_pro };
      }),
    config: {
      bundleId: "com.yaremchuk.app",
      appAppleId: 6762543923,
      productId: "com.yaremchuk.app.pro.lifetime",
      allowSandbox: false,
    },
  };
}

/** What verify-purchase does when the app sends a purchase it has just made. */
async function link(db: PGlite, userId: string, originalTransactionId: string) {
  await asServiceRole(db, () =>
    db.query(
      `select * from public.record_pro_transaction(
         $1, $2, $2, 'com.yaremchuk.app.pro.lifetime', 'Production', $3, null, null, $3)`,
      [userId, originalTransactionId, new Date(T0).toISOString()],
    ));
}

/** The transaction as Apple signs it at `signedDate`; revoked at `revokedAt` if given. */
const transaction = (
  originalTransactionId: string,
  signedDate: number,
  revokedAt?: number,
  overrides: Record<string, unknown> = {},
): Record<string, unknown> => ({
  transactionId: originalTransactionId,
  originalTransactionId,
  bundleId: "com.yaremchuk.app",
  productId: "com.yaremchuk.app.pro.lifetime",
  purchaseDate: T0 - 60_000,
  originalPurchaseDate: T0 - 60_000,
  quantity: 1,
  type: "Non-Consumable",
  inAppOwnershipType: "PURCHASED",
  environment: "Production",
  signedDate,
  ...(revokedAt ? { revocationDate: revokedAt, revocationReason: 0 } : {}),
  ...overrides,
});

/** POSTs a notification the way Apple does, signed with `sign` (the test PKI by default). */
async function deliver(
  db: PGlite,
  type: string,
  tx: Record<string, unknown>,
  sign: (body: unknown) => Promise<string> = signJws,
) {
  const signedPayload = await sign({
    notificationType: type,
    notificationUUID: crypto.randomUUID(),
    data: {
      appAppleId: 6762543923,
      bundleId: "com.yaremchuk.app",
      bundleVersion: "6",
      environment: "Production",
      signedTransactionInfo: await sign(tx),
    },
    version: "2.0",
    signedDate: tx.signedDate,
  });
  const res = await handleAppStoreNotification(
    new Request("http://localhost/app-store-notifications", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ signedPayload }),
    }),
    depsFor(db),
  );
  return { status: res.status, body: await res.json() };
}

async function isPro(db: PGlite, userId: string): Promise<boolean | null> {
  const res = await db.query<{ is_pro: boolean }>("select is_pro from public.profiles where id = $1", [userId]);
  return res.rows[0]?.is_pro ?? null;
}

Deno.test("a REFUND notification takes Pro away from the purchase's owner", async () => {
  const db = await freshDb();
  await link(db, ALICE, PURCHASE);
  assertEquals(await isPro(db, ALICE), true);

  const res = await deliver(db, "REFUND", transaction(PURCHASE, T1, T1));
  assertEquals(res, { status: 200, body: { status: "recorded", outcome: "revoked" } });
  assertEquals(await isPro(db, ALICE), false);

  const row = await db.query<{ user_id: string; revoked_at: Date | null; signed_at: Date }>(
    "select user_id, revoked_at, signed_at from public.pro_purchases",
  );
  assertEquals(row.rows.length, 1);
  assertEquals(row.rows[0].user_id, ALICE);
  assert(row.rows[0].revoked_at !== null);
  assertEquals(row.rows[0].signed_at.toISOString(), new Date(T1).toISOString());
  await db.close();
});

Deno.test("a REFUND_REVERSED notification gives the owner Pro back", async () => {
  const db = await freshDb();
  await link(db, ALICE, PURCHASE);
  await deliver(db, "REFUND", transaction(PURCHASE, T1, T1));
  assertEquals(await isPro(db, ALICE), false);

  const res = await deliver(db, "REFUND_REVERSED", transaction(PURCHASE, T2));
  assertEquals(res, { status: 200, body: { status: "recorded", outcome: "active" } });
  assertEquals(await isPro(db, ALICE), true);
  await db.close();
});

Deno.test("a refund redelivered after its reversal doesn't take Pro away again", async () => {
  // Apple retries a notification until it gets a 2xx, so they can arrive out of order.
  const db = await freshDb();
  await link(db, ALICE, PURCHASE);
  await deliver(db, "REFUND", transaction(PURCHASE, T1, T1));
  await deliver(db, "REFUND_REVERSED", transaction(PURCHASE, T2));

  const res = await deliver(db, "REFUND", transaction(PURCHASE, T1, T1));
  assertEquals(res, { status: 200, body: { status: "recorded", outcome: "active" } });
  assertEquals(await isPro(db, ALICE), true);
  await db.close();
});

Deno.test("a refund for a purchase no account has linked changes nothing", async () => {
  const db = await freshDb();
  const res = await deliver(db, "REFUND", transaction(PURCHASE, T1, T1));
  assertEquals(res, { status: 200, body: { status: "ignored", reason: "not_linked" } });
  assertEquals((await db.query("select 1 from public.pro_purchases")).rows.length, 0);
  assertEquals(await isPro(db, ALICE), null);
  await db.close();
});

Deno.test("a forged refund leaves the owner's Pro alone", async () => {
  const db = await freshDb();
  await link(db, ALICE, PURCHASE);
  const forger = await makeTestPki("CN=Apple Root CA - G3, OU=Apple Certification Authority, O=Apple Inc., C=US");
  const res = await deliver(db, "REFUND", transaction(PURCHASE, T1, T1), (body) => signJws(body, { pki: forger }));
  assertEquals([res.status, res.body.code], [422, "invalid_signature"]);
  assertEquals(await isPro(db, ALICE), true);
  await db.close();
});

Deno.test("revoking a family member's shared access leaves the purchaser's Pro alone", async () => {
  const db = await freshDb();
  await link(db, ALICE, PURCHASE);
  // Bob, in Alice's family, linked his FAMILY_SHARED transaction, which has its own ID.
  await link(db, BOB, SHARED);

  const res = await deliver(db, "REVOKE", transaction(SHARED, T1, T1, { inAppOwnershipType: "FAMILY_SHARED" }));
  assertEquals(res, { status: 200, body: { status: "recorded", outcome: "revoked" } });
  assertEquals(await isPro(db, BOB), false);
  assertEquals(await isPro(db, ALICE), true);
  await db.close();
});
