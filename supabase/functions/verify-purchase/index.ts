// verify-purchase: links a StoreKit 2 purchase of Gimme Pro to the signed-in account.
//
// POST { jws: <VerificationResult.jwsRepresentation> }
// Auth: the signed-in user's access token (Authorization: Bearer <jwt>).
// Returns { isPro, status: "active" | "revoked" } or { code, error }.
//
// The JWS is checked here against Apple's pinned root certificate; nothing is
// sent to Apple. The service role then records it with record_pro_transaction()
// (migration v10), which is the only writer of profiles.is_pro. A refunded or
// revoked transaction takes Pro away.
//
// Optional secret: ALLOW_SANDBOX_PURCHASES=true accepts sandbox and TestFlight
// purchases. They cost testers nothing, so leave it unset in production.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { appleRootCertificates, JwsVerificationError, verifyAppleJws } from "./apple_jws.ts";
import { type Deps, handleVerifyPurchase, isRecordOutcome } from "./handler.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const appleRoots = appleRootCertificates();

const deps: Deps = {
  async getUserId(accessToken) {
    const { data, error } = await admin.auth.getUser(accessToken);
    return error || !data.user ? null : data.user.id;
  },

  async verifyTransaction(jws) {
    try {
      return { ok: true, payload: await verifyAppleJws(jws, appleRoots) };
    } catch (error) {
      if (error instanceof JwsVerificationError) {
        return { ok: false, reason: error.failure, detail: error.message };
      }
      throw error;
    }
  },

  async recordTransaction(input) {
    const { data, error } = await admin
      .rpc("record_pro_transaction", {
        p_user_id: input.userId,
        p_original_transaction_id: input.originalTransactionId,
        p_transaction_id: input.transactionId,
        p_product_id: input.productId,
        p_environment: input.environment,
        p_purchased_at: input.purchasedAt?.toISOString() ?? null,
        p_revoked_at: input.revokedAt?.toISOString() ?? null,
        p_revocation_reason: input.revocationReason,
        p_signed_at: input.signedAt.toISOString(),
      })
      .single();
    if (error) throw error;
    const row = data as { outcome: unknown; caller_is_pro: unknown };
    if (!isRecordOutcome(row.outcome)) throw new Error(`Unexpected outcome ${String(row.outcome)}`);
    return { outcome: row.outcome, isPro: row.caller_is_pro === true };
  },

  config: {
    bundleId: "com.yaremchuk.app",
    productId: "com.yaremchuk.app.pro.lifetime",
    allowSandbox: Deno.env.get("ALLOW_SANDBOX_PURCHASES") === "true",
  },
};

Deno.serve((req) => handleVerifyPurchase(req, deps));
