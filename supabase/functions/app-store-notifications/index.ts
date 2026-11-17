// app-store-notifications: App Store Server Notifications V2 for Gimme, so a
// refund takes account-level Pro away even when the user's app never reports it.
//
// Apple calls it at the Production Server URL set in App Store Connect
// (Apps → Gimme → App Information → App Store Server Notifications, Version 2):
//   https://dyporggvmfyzejopaezc.supabase.co/functions/v1/app-store-notifications
//
// POST { signedPayload: <JWS> }, with no credentials. The notification and the
// transaction inside it are checked here against Apple's pinned root
// certificate, as verify-purchase checks a transaction; nothing is sent to
// Apple. REFUND, REVOKE and REFUND_REVERSED for Gimme Pro are then recorded with
// record_pro_transaction() (migration v10) for the account that linked the
// purchase. Every other genuine notification gets a 200 and changes nothing.
//
// verify_jwt = false in supabase/config.toml: Apple sends no Supabase JWT.
// Optional secret, shared with verify-purchase: ALLOW_SANDBOX_PURCHASES=true
// also acts on sandbox notifications. Leave it unset in production.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { appleJwsVerifier, appleRootCertificates } from "../_shared/apple_jws.ts";
import { findProPurchaseOwner, recordProTransaction } from "../_shared/pro_purchases_db.ts";
import { type Deps, handleAppStoreNotification } from "./handler.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const deps: Deps = {
  verifyJws: appleJwsVerifier(appleRootCertificates()),
  findOwner: (originalTransactionId) => findProPurchaseOwner(admin, originalTransactionId),
  recordTransaction: (input) => recordProTransaction(admin, input),
  config: {
    bundleId: "com.yaremchuk.app",
    // As in https://apps.apple.com/app/gimme-wishlist-gift-ideas/id6762543923
    appAppleId: 6762543923,
    productId: "com.yaremchuk.app.pro.lifetime",
    allowSandbox: Deno.env.get("ALLOW_SANDBOX_PURCHASES") === "true",
  },
};

Deno.serve((req) => handleAppStoreNotification(req, deps));
