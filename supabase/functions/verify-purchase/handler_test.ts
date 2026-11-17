// Run: deno test --node-modules-dir=none -A supabase/functions/
import { assert, assertEquals } from "jsr:@std/assert@1";
import type { VerifyResult } from "../_shared/apple_jws.ts";
import type { RecordInput, RecordResult } from "../_shared/pro_purchases.ts";
import { type Deps, handleVerifyPurchase, MAX_JWS_LENGTH } from "./handler.ts";

const SIGNED = Date.parse("2026-11-13T10:00:00Z");
const JWS = "header.payload.signature"; // the fake verifier never parses it

const activePayload = {
  transactionId: "2000000123456789",
  originalTransactionId: "2000000123456789",
  bundleId: "com.yaremchuk.app",
  productId: "com.yaremchuk.app.pro.lifetime",
  purchaseDate: SIGNED - 60_000,
  originalPurchaseDate: SIGNED - 60_000,
  quantity: 1,
  type: "Non-Consumable",
  inAppOwnershipType: "PURCHASED",
  signedDate: SIGNED,
  environment: "Production",
  transactionReason: "PURCHASE",
  storefront: "USA",
};

interface Recorder {
  tokens: string[];
  verified: string[];
  recorded: RecordInput[];
}

function makeDeps(overrides: {
  userId?: string | null;
  getUserId?: () => Promise<string | null>;
  verify?: VerifyResult | (() => Promise<VerifyResult>);
  payload?: Record<string, unknown>;
  record?: RecordResult | (() => Promise<RecordResult>);
  allowSandbox?: boolean;
} = {}): { deps: Deps; rec: Recorder } {
  const rec: Recorder = { tokens: [], verified: [], recorded: [] };
  const deps: Deps = {
    getUserId: (token) => {
      rec.tokens.push(token);
      if (overrides.getUserId) return overrides.getUserId();
      return Promise.resolve(overrides.userId === undefined ? "user-1" : overrides.userId);
    },
    verifyTransaction: (jws) => {
      rec.verified.push(jws);
      if (typeof overrides.verify === "function") return overrides.verify();
      return Promise.resolve(overrides.verify ?? { ok: true, payload: overrides.payload ?? activePayload });
    },
    recordTransaction: (input) => {
      rec.recorded.push(input);
      if (typeof overrides.record === "function") return overrides.record();
      return Promise.resolve(
        overrides.record ?? { outcome: input.revokedAt ? "revoked" : "active", isPro: !input.revokedAt },
      );
    },
    config: {
      bundleId: "com.yaremchuk.app",
      productId: "com.yaremchuk.app.pro.lifetime",
      allowSandbox: overrides.allowSandbox ?? false,
    },
  };
  return { deps, rec };
}

function post(body: unknown, auth: string | null = "Bearer user-token"): Request {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (auth !== null) headers.Authorization = auth;
  return new Request("http://localhost/verify-purchase", {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

async function call(deps: Deps, req: Request = post({ jws: JWS })) {
  const res = await handleVerifyPurchase(req, deps);
  return { status: res.status, body: await res.json() };
}

// ── Request shape and auth ───────────────────────────────────────────────────

Deno.test("rejects non-POST requests", async () => {
  const { deps } = makeDeps();
  const res = await call(deps, new Request("http://localhost/verify-purchase", { method: "GET" }));
  assertEquals([res.status, res.body.code], [405, "method_not_allowed"]);
});

Deno.test("requires a bearer token", async () => {
  const { deps, rec } = makeDeps();
  const res = await call(deps, post({ jws: JWS }, null));
  assertEquals([res.status, res.body.code], [401, "unauthorized"]);
  assertEquals(rec.verified, []);
});

Deno.test("rejects an invalid or expired token", async () => {
  const { deps, rec } = makeDeps({ userId: null });
  const res = await call(deps);
  assertEquals([res.status, res.body.code], [401, "unauthorized"]);
  assertEquals(rec.tokens, ["user-token"]);
  assertEquals(rec.recorded, []);
});

Deno.test("treats a failed token lookup as signed out", async () => {
  const { deps, rec } = makeDeps({ getUserId: () => Promise.reject(new Error("auth down")) });
  const res = await call(deps);
  assertEquals([res.status, res.body.code], [401, "unauthorized"]);
  assertEquals(rec.recorded, []);
});

Deno.test("rejects a body that isn't JSON", async () => {
  const { deps } = makeDeps();
  const res = await call(deps, post("{not json"));
  assertEquals([res.status, res.body.code], [400, "bad_request"]);
});

Deno.test("requires the JWS as a non-empty string", async () => {
  for (const body of [{}, { jws: "" }, { jws: 42 }, { jws: null }, [JWS], "null"]) {
    const { deps, rec } = makeDeps();
    const res = await call(deps, post(body));
    assertEquals([res.status, res.body.code], [400, "bad_request"], JSON.stringify(body));
    assertEquals(rec.verified, []);
  }
});

Deno.test("refuses a JWS far larger than StoreKit produces", async () => {
  const { deps, rec } = makeDeps();
  const res = await call(deps, post({ jws: "a".repeat(MAX_JWS_LENGTH + 1) }));
  assertEquals([res.status, res.body.code], [400, "bad_request"]);
  assertEquals(rec.verified, []);
});

// ── Verification ─────────────────────────────────────────────────────────────

Deno.test("refuses a JWS that Apple didn't sign", async () => {
  const { deps, rec } = makeDeps({ verify: { ok: false, reason: "untrusted_chain", detail: "nope" } });
  const res = await call(deps);
  assertEquals([res.status, res.body.code], [422, "invalid_signature"]);
  assertEquals(rec.verified, [JWS]);
  assertEquals(rec.recorded, []);
});

Deno.test("reports a crash during verification as a server error", async () => {
  const { deps, rec } = makeDeps({ verify: () => Promise.reject(new Error("boom")) });
  const res = await call(deps);
  assertEquals([res.status, res.body.code], [500, "server_error"]);
  assertEquals(rec.recorded, []);
});

Deno.test("refuses another app's transaction", async () => {
  const { deps, rec } = makeDeps({ payload: { ...activePayload, bundleId: "com.example.other" } });
  const res = await call(deps);
  assertEquals([res.status, res.body.code], [422, "wrong_app"]);
  assertEquals(rec.recorded, []);
});

Deno.test("refuses a transaction for another product", async () => {
  const { deps, rec } = makeDeps({ payload: { ...activePayload, productId: "com.yaremchuk.app.tip" } });
  const res = await call(deps);
  assertEquals([res.status, res.body.code], [422, "wrong_product"]);
  assertEquals(rec.recorded, []);
});

Deno.test("refuses a payload missing the fields Pro needs", async () => {
  for (const field of ["originalTransactionId", "transactionId", "bundleId", "productId", "environment", "signedDate"]) {
    const payload: Record<string, unknown> = { ...activePayload };
    delete payload[field];
    const { deps, rec } = makeDeps({ payload });
    const res = await call(deps);
    assertEquals([res.status, res.body.code], [422, "invalid_transaction"], field);
    assertEquals(rec.recorded, []);
  }
});

Deno.test("refuses sandbox purchases unless they're allowed", async () => {
  const sandbox = { ...activePayload, environment: "Sandbox" };
  const refused = makeDeps({ payload: sandbox });
  const res = await call(refused.deps);
  assertEquals([res.status, res.body.code], [422, "wrong_environment"]);
  assertEquals(refused.rec.recorded, []);

  const allowed = makeDeps({ payload: sandbox, allowSandbox: true });
  assertEquals((await call(allowed.deps)).status, 200);
  assertEquals(allowed.rec.recorded[0].environment, "Sandbox");
});

Deno.test("refuses Xcode and local-testing transactions even when sandbox is allowed", async () => {
  for (const environment of ["Xcode", "LocalTesting"]) {
    const { deps, rec } = makeDeps({ payload: { ...activePayload, environment }, allowSandbox: true });
    const res = await call(deps);
    assertEquals([res.status, res.body.code], [422, "wrong_environment"], environment);
    assertEquals(rec.recorded, []);
  }
});

// ── Recording ────────────────────────────────────────────────────────────────

Deno.test("records a verified purchase for the signed-in caller", async () => {
  const { deps, rec } = makeDeps();
  const res = await call(deps);
  assertEquals(res, { status: 200, body: { isPro: true, status: "active" } });
  assertEquals(rec.recorded, [{
    userId: "user-1",
    originalTransactionId: "2000000123456789",
    transactionId: "2000000123456789",
    productId: "com.yaremchuk.app.pro.lifetime",
    environment: "Production",
    purchasedAt: new Date(SIGNED - 60_000),
    revokedAt: null,
    revocationReason: null,
    signedAt: new Date(SIGNED),
  }]);
});

Deno.test("records a refund so it takes Pro away", async () => {
  const refunded = {
    ...activePayload,
    signedDate: SIGNED + 86_400_000,
    revocationDate: SIGNED + 86_000_000,
    revocationReason: 0,
  };
  const { deps, rec } = makeDeps({ payload: refunded });
  const res = await call(deps);
  assertEquals(res, { status: 200, body: { isPro: false, status: "revoked" } });
  assertEquals(rec.recorded[0].revokedAt, new Date(SIGNED + 86_000_000));
  assertEquals(rec.recorded[0].revocationReason, 0);
  assertEquals(rec.recorded[0].signedAt, new Date(SIGNED + 86_400_000));
});

Deno.test("reports a purchase that belongs to another account", async () => {
  const { deps } = makeDeps({ record: { outcome: "claimed_by_other_account", isPro: false } });
  const res = await call(deps);
  assertEquals(res.status, 409);
  assertEquals(res.body.code, "claimed_by_other_account");
  assertEquals(res.body.isPro, false);
});

Deno.test("passes on the account's Pro after a revocation it didn't cause", async () => {
  // e.g. one of two purchases refunded: still Pro through the other.
  const { deps } = makeDeps({ record: { outcome: "revoked", isPro: true } });
  assertEquals(await call(deps), { status: 200, body: { isPro: true, status: "revoked" } });
});

Deno.test("reports a database failure as a server error", async () => {
  const { deps } = makeDeps({ record: () => Promise.reject(new Error("db down")) });
  const res = await call(deps);
  assertEquals([res.status, res.body.code], [500, "server_error"]);
  assert(typeof res.body.error === "string");
});

Deno.test("never trusts a user id from the body", async () => {
  const { deps, rec } = makeDeps();
  await call(deps, post({ jws: JWS, userId: "someone-else", user_id: "someone-else" }));
  assertEquals(rec.recorded[0].userId, "user-1");
});
