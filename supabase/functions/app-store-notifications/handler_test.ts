// Run: deno test --node-modules-dir=none -A supabase/functions/
//
// The notifications here are real JWS, signed the way the App Store signs them
// but with the test PKI from _shared/apple_test_pki.ts, whose root `verifyJws`
// trusts in place of Apple's. The database is a fake that records each call.
import { assertEquals } from "jsr:@std/assert@1";
import { appleJwsVerifier, appleRootCertificates, type VerifyResult } from "../_shared/apple_jws.ts";
import { makeTestPki, signJws, testPki } from "../_shared/apple_test_pki.ts";
import type { RecordInput, RecordResult } from "../_shared/pro_purchases.ts";
import { type Deps, handleAppStoreNotification, MAX_SIGNED_PAYLOAD_LENGTH } from "./handler.ts";

const APP_APPLE_ID = 6762543923;
const PURCHASE = "2000000123456789";
const OWNER = "user-1";
const PURCHASED = Date.parse("2026-11-01T10:00:00Z");
const REFUNDED = Date.parse("2026-11-13T09:58:00Z");
const SIGNED = Date.parse("2026-11-13T10:00:00Z");

/** Apple's JWSTransactionDecodedPayload for a Gimme Pro purchase. */
const transaction = (overrides: Record<string, unknown> = {}): Record<string, unknown> => ({
  transactionId: PURCHASE,
  originalTransactionId: PURCHASE,
  bundleId: "com.yaremchuk.app",
  productId: "com.yaremchuk.app.pro.lifetime",
  purchaseDate: PURCHASED,
  originalPurchaseDate: PURCHASED,
  quantity: 1,
  type: "Non-Consumable",
  inAppOwnershipType: "PURCHASED",
  signedDate: SIGNED,
  environment: "Production",
  transactionReason: "PURCHASE",
  storefront: "USA",
  storefrontId: "143441",
  price: 4990,
  currency: "USD",
  ...overrides,
});

const refunded = (overrides: Record<string, unknown> = {}) =>
  transaction({ revocationDate: REFUNDED, revocationReason: 0, ...overrides });

interface NotificationOptions {
  /** Signed into data.signedTransactionInfo; null leaves it out. Defaults to a refunded purchase. */
  tx?: Record<string, unknown> | null;
  /** Overrides for `data`; null sends a notification without it. */
  data?: Record<string, unknown> | null;
  /** Signs the transaction. Defaults to the test PKI. */
  signTx?: (body: unknown) => Promise<string>;
}

/** A signedPayload the way Apple POSTs it: responseBodyV2DecodedPayload, signed. */
async function notification(type: string, opts: NotificationOptions = {}): Promise<string> {
  const tx = opts.tx === undefined ? refunded() : opts.tx;
  const data = opts.data === null ? undefined : {
    appAppleId: APP_APPLE_ID,
    bundleId: "com.yaremchuk.app",
    bundleVersion: "6",
    environment: "Production",
    ...(tx ? { signedTransactionInfo: await (opts.signTx ?? signJws)(tx) } : {}),
    ...opts.data,
  };
  return signJws({
    notificationType: type,
    notificationUUID: crypto.randomUUID(),
    data,
    version: "2.0",
    signedDate: tx?.signedDate ?? SIGNED,
  });
}

interface Recorder {
  verified: string[];
  lookedUp: string[];
  recorded: RecordInput[];
}

function makeDeps(overrides: {
  owner?: string | null;
  findOwner?: () => Promise<string | null>;
  record?: () => Promise<RecordResult>;
  verify?: (jws: string) => Promise<VerifyResult>;
  allowSandbox?: boolean;
} = {}): { deps: Deps; rec: Recorder } {
  const rec: Recorder = { verified: [], lookedUp: [], recorded: [] };
  const verify = overrides.verify ?? appleJwsVerifier([testPki.root.cert]);
  const deps: Deps = {
    verifyJws: (jws) => {
      rec.verified.push(jws);
      return verify(jws);
    },
    findOwner: (originalTransactionId) => {
      rec.lookedUp.push(originalTransactionId);
      if (overrides.findOwner) return overrides.findOwner();
      return Promise.resolve(overrides.owner === undefined ? OWNER : overrides.owner);
    },
    recordTransaction: (input) => {
      rec.recorded.push(input);
      if (overrides.record) return overrides.record();
      return Promise.resolve({ outcome: input.revokedAt ? "revoked" : "active", isPro: !input.revokedAt });
    },
    config: {
      bundleId: "com.yaremchuk.app",
      appAppleId: APP_APPLE_ID,
      productId: "com.yaremchuk.app.pro.lifetime",
      allowSandbox: overrides.allowSandbox ?? false,
    },
  };
  return { deps, rec };
}

function post(body: unknown): Request {
  return new Request("http://localhost/app-store-notifications", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

/** Delivers a signedPayload as Apple would, or sends `req` as it is. */
async function deliver(deps: Deps, signedPayloadOrRequest: string | Request) {
  const req = typeof signedPayloadOrRequest === "string"
    ? post({ signedPayload: signedPayloadOrRequest })
    : signedPayloadOrRequest;
  const res = await handleAppStoreNotification(req, deps);
  return { status: res.status, body: await res.json() };
}

function assertUntouched(rec: Recorder, message?: string) {
  assertEquals(rec.lookedUp, [], message);
  assertEquals(rec.recorded, [], message);
}

// ── Request shape ────────────────────────────────────────────────────────────

Deno.test("rejects non-POST requests", async () => {
  const { deps } = makeDeps();
  const res = await deliver(deps, new Request("http://localhost/app-store-notifications", { method: "GET" }));
  assertEquals([res.status, res.body.code], [405, "method_not_allowed"]);
});

Deno.test("needs a JSON body with a signedPayload", async () => {
  // The last body is a Version 1 notification, which isn't signed.
  const bodies = ["{not json", {}, { signedPayload: "" }, { signedPayload: 42 }, [], "null", {
    notification_type: "REFUND",
    unified_receipt: {},
  }];
  for (const body of bodies) {
    const { deps, rec } = makeDeps();
    const res = await deliver(deps, post(body));
    assertEquals([res.status, res.body.code], [400, "bad_request"], JSON.stringify(body));
    assertEquals(rec.verified, []);
  }
});

Deno.test("refuses a payload far larger than Apple sends", async () => {
  const { deps, rec } = makeDeps();
  const res = await deliver(deps, "a".repeat(MAX_SIGNED_PAYLOAD_LENGTH + 1));
  assertEquals([res.status, res.body.code], [400, "bad_request"]);
  assertEquals(rec.verified, []);
});

// ── Forgeries ────────────────────────────────────────────────────────────────

Deno.test("rejects a notification Apple didn't sign", async () => {
  // Production trusts only Apple's root, so a notification signed through any
  // other chain is refused before anything is looked up.
  const { deps, rec } = makeDeps({ verify: appleJwsVerifier(appleRootCertificates()) });
  const res = await deliver(deps, await notification("REFUND"));
  assertEquals([res.status, res.body.code], [422, "invalid_signature"]);
  assertEquals(rec.verified.length, 1);
  assertUntouched(rec);
});

Deno.test("rejects a notification changed after it was signed", async () => {
  const { deps, rec } = makeDeps();
  const [header, , signature] = (await notification("REFUND")).split(".");
  const [, reversal] = (await notification("REFUND_REVERSED", { tx: transaction() })).split(".");
  const res = await deliver(deps, `${header}.${reversal}.${signature}`);
  assertEquals([res.status, res.body.code], [422, "invalid_signature"]);
  assertUntouched(rec);
});

Deno.test("rejects a genuine notification carrying a transaction Apple didn't sign", async () => {
  const stranger = await makeTestPki("CN=Someone Else, C=US");
  const { deps, rec } = makeDeps();
  const res = await deliver(
    deps,
    await notification("REFUND_REVERSED", { tx: transaction(), signTx: (body) => signJws(body, { pki: stranger }) }),
  );
  assertEquals([res.status, res.body.code], [422, "invalid_signature"]);
  assertEquals(rec.verified.length, 2);
  assertUntouched(rec);
});

Deno.test("reports a crash during verification as a server error, so Apple retries", async () => {
  const { deps, rec } = makeDeps({ verify: () => Promise.reject(new Error("boom")) });
  const res = await deliver(deps, await notification("REFUND"));
  assertEquals([res.status, res.body.code], [500, "server_error"]);
  assertUntouched(rec);
});

// ── Other apps ───────────────────────────────────────────────────────────────

Deno.test("rejects another app's notification", async () => {
  const { deps, rec } = makeDeps();
  const res = await deliver(deps, await notification("REFUND", { data: { bundleId: "com.example.other" } }));
  assertEquals([res.status, res.body.code], [422, "wrong_app"]);
  assertUntouched(rec);
});

Deno.test("rejects a production notification without this app's Apple ID", async () => {
  for (const appAppleId of [1234567890, undefined, String(APP_APPLE_ID)]) {
    const { deps, rec } = makeDeps();
    const res = await deliver(deps, await notification("REFUND", { data: { appAppleId } }));
    assertEquals([res.status, res.body.code], [422, "wrong_app"], String(appAppleId));
    assertUntouched(rec);
  }
});

Deno.test("rejects another app's transaction inside a notification", async () => {
  const { deps, rec } = makeDeps();
  const res = await deliver(deps, await notification("REFUND", { tx: refunded({ bundleId: "com.example.other" }) }));
  assertEquals([res.status, res.body.code], [422, "wrong_app"]);
  assertUntouched(rec);
});

Deno.test("rejects another app's sandbox notification even when sandbox is allowed", async () => {
  const { deps, rec } = makeDeps({ allowSandbox: true });
  const others = [
    { environment: "Sandbox", appAppleId: undefined, bundleId: "com.example.other" },
    { environment: "Sandbox", appAppleId: 1234567890 },
  ];
  for (const data of others) {
    const res = await deliver(deps, await notification("REFUND", { tx: refunded({ environment: "Sandbox" }), data }));
    assertEquals([res.status, res.body.code], [422, "wrong_app"], JSON.stringify(data));
  }
  assertUntouched(rec);
});

// ── Refunds, revocations and reversals ───────────────────────────────────────

Deno.test("a refund takes Pro from the account that owns the purchase", async () => {
  const { deps, rec } = makeDeps();
  const res = await deliver(deps, await notification("REFUND"));
  assertEquals(res, { status: 200, body: { status: "recorded", outcome: "revoked" } });
  assertEquals(rec.lookedUp, [PURCHASE]);
  assertEquals(rec.recorded, [{
    userId: OWNER,
    originalTransactionId: PURCHASE,
    transactionId: PURCHASE,
    productId: "com.yaremchuk.app.pro.lifetime",
    environment: "Production",
    purchasedAt: new Date(PURCHASED),
    revokedAt: new Date(REFUNDED),
    revocationReason: 0,
    signedAt: new Date(SIGNED),
  }]);
});

Deno.test("an entitlement lost from Family Sharing takes Pro from the family member's account", async () => {
  // A family member's transaction has its own original transaction ID.
  const shared = refunded({
    transactionId: "2000000555555555",
    originalTransactionId: "2000000555555555",
    inAppOwnershipType: "FAMILY_SHARED",
    revocationReason: undefined,
  });
  const { deps, rec } = makeDeps({ owner: "family-member" });
  const res = await deliver(deps, await notification("REVOKE", { tx: shared }));
  assertEquals(res, { status: 200, body: { status: "recorded", outcome: "revoked" } });
  assertEquals(rec.lookedUp, ["2000000555555555"]);
  assertEquals(rec.recorded[0].userId, "family-member");
  assertEquals(rec.recorded[0].revokedAt, new Date(REFUNDED));
  assertEquals(rec.recorded[0].revocationReason, null);
});

Deno.test("a reversed refund gives Pro back to the owner", async () => {
  const reversed = SIGNED + 7 * 86_400_000;
  const { deps, rec } = makeDeps();
  const res = await deliver(deps, await notification("REFUND_REVERSED", { tx: transaction({ signedDate: reversed }) }));
  assertEquals(res, { status: 200, body: { status: "recorded", outcome: "active" } });
  // Stated as the owner: record_pro_transaction() applies only the owner's newer active statements.
  assertEquals(rec.recorded[0].userId, OWNER);
  assertEquals(rec.recorded[0].revokedAt, null);
  assertEquals(rec.recorded[0].signedAt, new Date(reversed));
});

Deno.test("records the transaction as Apple signed it, whatever the notification type", async () => {
  // Apple can send REVOKE for an entitlement the user got back before the
  // notification was built; its transaction then has no revocationDate.
  const { deps, rec } = makeDeps();
  const res = await deliver(deps, await notification("REVOKE", { tx: transaction() }));
  assertEquals(res, { status: 200, body: { status: "recorded", outcome: "active" } });
  assertEquals(rec.recorded[0].revokedAt, null);
});

Deno.test("skips a purchase that no account has linked", async () => {
  const { deps, rec } = makeDeps({ owner: null });
  const res = await deliver(deps, await notification("REFUND"));
  assertEquals(res, { status: 200, body: { status: "ignored", reason: "not_linked" } });
  assertEquals(rec.lookedUp, [PURCHASE]);
  assertEquals(rec.recorded, []);
});

Deno.test("reports a database failure as a server error, so Apple retries", async () => {
  const lookup = makeDeps({ findOwner: () => Promise.reject(new Error("db down")) });
  const looked = await deliver(lookup.deps, await notification("REFUND"));
  assertEquals([looked.status, looked.body.code], [500, "server_error"]);
  assertEquals(lookup.rec.recorded, []);

  const record = makeDeps({ record: () => Promise.reject(new Error("db down")) });
  const recorded = await deliver(record.deps, await notification("REFUND"));
  assertEquals([recorded.status, recorded.body.code], [500, "server_error"]);
});

// ── Everything else gets a 200, so Apple stops retrying ──────────────────────

Deno.test("acknowledges other notification types without touching the database", async () => {
  const types = ["TEST", "ONE_TIME_CHARGE", "CONSUMPTION_REQUEST", "REFUND_DECLINED", "SOMETHING_NEW"];
  for (const type of types) {
    const { deps, rec } = makeDeps();
    // A TEST notification carries app data but no transaction.
    const res = await deliver(deps, await notification(type, { tx: type === "TEST" ? null : transaction() }));
    assertEquals(res, { status: 200, body: { status: "ignored", reason: "unhandled_type" } }, type);
    assertEquals(rec.verified.length, 1, `${type}: only the notification is verified`);
    assertUntouched(rec, type);
  }
});

Deno.test("acknowledges a notification without app data", async () => {
  // e.g. RENEWAL_EXTENSION with the SUMMARY subtype carries `summary` instead.
  const { deps, rec } = makeDeps();
  const res = await deliver(deps, await notification("RENEWAL_EXTENSION", { data: null }));
  assertEquals(res, { status: 200, body: { status: "ignored", reason: "unhandled_type" } });
  assertUntouched(rec);
});

Deno.test("acknowledges a refund for another product", async () => {
  const { deps, rec } = makeDeps();
  const res = await deliver(deps, await notification("REFUND", { tx: refunded({ productId: "com.yaremchuk.app.tip" }) }));
  assertEquals(res, { status: 200, body: { status: "ignored", reason: "other_product" } });
  assertUntouched(rec);
});

Deno.test("acts on sandbox notifications only when sandbox purchases are allowed", async () => {
  // Apple leaves appAppleId out of sandbox notifications.
  const sandbox = () =>
    notification("REFUND", {
      tx: refunded({ environment: "Sandbox" }),
      data: { environment: "Sandbox", appAppleId: undefined },
    });

  const refused = makeDeps();
  assertEquals(await deliver(refused.deps, await sandbox()), {
    status: 200,
    body: { status: "ignored", reason: "environment" },
  });
  assertUntouched(refused.rec);

  const allowed = makeDeps({ allowSandbox: true });
  assertEquals(await deliver(allowed.deps, await sandbox()), {
    status: 200,
    body: { status: "recorded", outcome: "revoked" },
  });
  assertEquals(allowed.rec.recorded[0].environment, "Sandbox");
});

// ── Signed, but not a notification Pro can act on ────────────────────────────

Deno.test("refuses a refund without a signed transaction", async () => {
  for (const opts of [{ tx: null }, { data: null }]) {
    const { deps, rec } = makeDeps();
    const res = await deliver(deps, await notification("REFUND", opts));
    assertEquals([res.status, res.body.code], [422, "invalid_notification"], JSON.stringify(opts));
    assertUntouched(rec);
  }
});

Deno.test("refuses a notification without a type", async () => {
  const { deps, rec } = makeDeps();
  const untyped = await signJws({
    notificationUUID: crypto.randomUUID(),
    data: { appAppleId: APP_APPLE_ID, bundleId: "com.yaremchuk.app", environment: "Production" },
    version: "2.0",
    signedDate: SIGNED,
  });
  const res = await deliver(deps, untyped);
  assertEquals([res.status, res.body.code], [422, "invalid_notification"]);
  assertUntouched(rec);
});

Deno.test("refuses a transaction missing the fields Pro needs", async () => {
  for (const field of ["originalTransactionId", "transactionId", "bundleId", "productId", "environment"]) {
    const { deps, rec } = makeDeps();
    const res = await deliver(deps, await notification("REFUND", { tx: refunded({ [field]: undefined }) }));
    assertEquals([res.status, res.body.code], [422, "invalid_notification"], field);
    assertUntouched(rec, field);
  }
});

Deno.test("refuses a transaction from another environment than its notification", async () => {
  const { deps, rec } = makeDeps({ allowSandbox: true });
  const res = await deliver(deps, await notification("REFUND", { tx: refunded({ environment: "Sandbox" }) }));
  assertEquals([res.status, res.body.code], [422, "invalid_notification"]);
  assertUntouched(rec);
});

// ── Trust ────────────────────────────────────────────────────────────────────

Deno.test("acts only on what Apple signed", async () => {
  // Fields beside signedPayload are ignored, and the account comes from pro_purchases.
  const { deps, rec } = makeDeps();
  const signedPayload = await notification("REFUND");
  const res = await deliver(deps, post({ signedPayload, userId: "attacker", data: { bundleId: "x" } }));
  assertEquals(res.status, 200);
  assertEquals(rec.recorded.map((r) => [r.userId, r.originalTransactionId]), [[OWNER, PURCHASE]]);
});
