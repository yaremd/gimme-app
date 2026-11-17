// verify-purchase request handling: StoreKit 2 transaction JWS -> Pro on the account.
// index.ts wires the real Supabase client and Apple's root certificate into `Deps`;
// handler_test.ts drives the same code with fakes.

import type { VerifyResult } from "../_shared/apple_jws.ts";
import {
  isAcceptedEnvironment,
  readTransaction,
  type RecordInput,
  recordInputFor,
  type RecordResult,
} from "../_shared/pro_purchases.ts";

export interface Config {
  bundleId: string;
  productId: string;
  /** Sandbox purchases (TestFlight, sandbox testers) are free, so production refuses them. */
  allowSandbox: boolean;
}

export interface Deps {
  /** Resolves the signed-in caller from a bearer token; null when invalid or expired. */
  getUserId(accessToken: string): Promise<string | null>;
  /** Checks Apple's signature and certificate chain on a JWS. */
  verifyTransaction(jws: string): Promise<VerifyResult>;
  /** Stores the transaction and recomputes Pro (record_pro_transaction, migration v10). */
  recordTransaction(input: RecordInput): Promise<RecordResult>;
  config: Config;
}

export type ErrorCode =
  | "method_not_allowed"
  | "unauthorized"
  | "bad_request"
  | "invalid_signature"
  | "invalid_transaction"
  | "wrong_app"
  | "wrong_product"
  | "wrong_environment"
  | "claimed_by_other_account"
  | "server_error";

/** Real StoreKit JWS are about 5 KB; anything far larger isn't one. */
export const MAX_JWS_LENGTH = 16_384;

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function failure(status: number, code: ErrorCode, error: string, extra: Record<string, unknown> = {}): Response {
  return json(status, { code, error, ...extra });
}

export async function handleVerifyPurchase(req: Request, deps: Deps): Promise<Response> {
  if (req.method !== "POST") return failure(405, "method_not_allowed", "Use POST.");

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) return failure(401, "unauthorized", "Sign in to link your purchase.");

  let userId: string | null;
  try {
    userId = await deps.getUserId(token);
  } catch {
    userId = null;
  }
  if (!userId) return failure(401, "unauthorized", "Sign in to link your purchase.");

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return failure(400, "bad_request", "Body must be JSON.");
  }
  const jws = body && typeof body === "object" ? (body as Record<string, unknown>).jws : undefined;
  if (typeof jws !== "string" || jws.length === 0) {
    return failure(400, "bad_request", "Missing jws: the transaction's jwsRepresentation.");
  }
  if (jws.length > MAX_JWS_LENGTH) return failure(400, "bad_request", "That isn't a StoreKit transaction.");

  let verified: VerifyResult;
  try {
    verified = await deps.verifyTransaction(jws);
  } catch (error) {
    console.error("verify-purchase: verification crashed", error);
    return failure(500, "server_error", "Something went wrong. Try again.");
  }
  if (!verified.ok) {
    console.warn("verify-purchase: rejected JWS", verified.reason, verified.detail);
    return failure(422, "invalid_signature", "This transaction isn't signed by the App Store.");
  }

  const tx = readTransaction(verified.payload);
  if (!tx) return failure(422, "invalid_transaction", "The transaction is missing required fields.");
  if (tx.bundleId !== deps.config.bundleId) {
    return failure(422, "wrong_app", "This transaction belongs to another app.");
  }
  if (tx.productId !== deps.config.productId) {
    return failure(422, "wrong_product", "This transaction isn't for Gimme Pro.");
  }
  if (!isAcceptedEnvironment(tx.environment, deps.config.allowSandbox)) {
    console.warn("verify-purchase: refused environment", tx.environment);
    return failure(422, "wrong_environment", `${tx.environment} purchases aren't accepted here.`);
  }

  let result: RecordResult;
  try {
    result = await deps.recordTransaction(recordInputFor(userId, tx));
  } catch (error) {
    console.error("verify-purchase: could not record the transaction", error);
    return failure(500, "server_error", "Something went wrong. Try again.");
  }

  console.log("verify-purchase:", result.outcome, tx.environment);
  if (result.outcome === "claimed_by_other_account") {
    return failure(409, "claimed_by_other_account", "This purchase is linked to another Gimme account.", {
      isPro: result.isPro,
    });
  }
  return json(200, { isPro: result.isPro, status: result.outcome });
}
