// The service-role calls on pro_purchases (migration v10) behind
// verify-purchase and app-store-notifications. Only their index.ts files
// import this module, so the tests never load supabase-js.
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { isRecordOutcome, type RecordInput, type RecordResult } from "./pro_purchases.ts";

/** record_pro_transaction(): stores the transaction and recomputes Pro for the purchase's owner. */
export async function recordProTransaction(admin: SupabaseClient, input: RecordInput): Promise<RecordResult> {
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
}

/** The account a purchase is linked to, or null when no account has presented it. */
export async function findProPurchaseOwner(admin: SupabaseClient, originalTransactionId: string): Promise<string | null> {
  const { data, error } = await admin
    .from("pro_purchases")
    .select("user_id")
    .eq("original_transaction_id", originalTransactionId)
    .maybeSingle();
  if (error) throw error;
  const owner = (data as { user_id?: unknown } | null)?.user_id;
  return typeof owner === "string" ? owner : null;
}
