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
import { appleJwsVerifier, appleRootCertificates } from "../_shared/apple_jws.ts";
import { recordProTransaction } from "../_shared/pro_purchases_db.ts";
import { type Deps, handleVerifyPurchase } from "./handler.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const deps: Deps = {
  async getUserId(accessToken) {
    const { data, error } = await admin.auth.getUser(accessToken);
    return error || !data.user ? null : data.user.id;
  },

  verifyTransaction: appleJwsVerifier(appleRootCertificates()),

  recordTransaction: (input) => recordProTransaction(admin, input),

  config: {
    bundleId: "com.yaremchuk.app",
    productId: "com.yaremchuk.app.pro.lifetime",
    allowSandbox: Deno.env.get("ALLOW_SANDBOX_PURCHASES") === "true",
  },
};

Deno.serve((req) => handleVerifyPurchase(req, deps));
