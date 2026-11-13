// What verify-purchase and app-store-notifications share about App Store
// transactions and the pro_purchases ledger (migration v10). verify-purchase
// hears about a purchase from the signed-in user's app; app-store-notifications
// hears about it from Apple. Both record it through record_pro_transaction().

/** What the database made of a verified transaction, for the caller. */
export type RecordOutcome = "active" | "revoked" | "claimed_by_other_account";

export interface RecordInput {
  userId: string;
  originalTransactionId: string;
  transactionId: string;
  productId: string;
  environment: string;
  purchasedAt: Date | null;
  revokedAt: Date | null;
  revocationReason: number | null;
  signedAt: Date;
}

export interface RecordResult {
  outcome: RecordOutcome;
  /** The caller's profiles.is_pro after recording. */
  isPro: boolean;
}

const RECORD_OUTCOMES: readonly string[] = ["active", "revoked", "claimed_by_other_account"];

export function isRecordOutcome(value: unknown): value is RecordOutcome {
  return typeof value === "string" && RECORD_OUTCOMES.includes(value);
}

/**
 * Production purchases always count. Sandbox ones (TestFlight, sandbox
 * testers) are free, so they count only where ALLOW_SANDBOX_PURCHASES=true.
 */
export function isAcceptedEnvironment(environment: string | null, allowSandbox: boolean): boolean {
  return environment === "Production" || (environment === "Sandbox" && allowSandbox);
}

export interface Transaction {
  bundleId: string;
  productId: string;
  environment: string;
  transactionId: string;
  originalTransactionId: string;
  purchaseDate: Date | null;
  revocationDate: Date | null;
  revocationReason: number | null;
  signedDate: Date;
}

const id = (value: unknown) => typeof value === "string" && value.length > 0 && value.length <= 128 ? value : null;
const time = (value: unknown) => typeof value === "number" && Number.isFinite(value) ? new Date(value) : null;

/** Picks the fields we use out of Apple's JWSTransactionDecodedPayload. */
export function readTransaction(payload: Record<string, unknown>): Transaction | null {
  const bundleId = id(payload.bundleId);
  const productId = id(payload.productId);
  const environment = id(payload.environment);
  const transactionId = id(payload.transactionId);
  const originalTransactionId = id(payload.originalTransactionId);
  const signedDate = time(payload.signedDate);
  if (!bundleId || !productId || !environment || !transactionId || !originalTransactionId || !signedDate) {
    return null;
  }
  const reason = payload.revocationReason;
  return {
    bundleId,
    productId,
    environment,
    transactionId,
    originalTransactionId,
    purchaseDate: time(payload.purchaseDate),
    revocationDate: time(payload.revocationDate),
    revocationReason: typeof reason === "number" && Number.isInteger(reason) ? reason : null,
    signedDate,
  };
}

/** The record_pro_transaction() call that states `tx` on behalf of `userId`. */
export function recordInputFor(userId: string, tx: Transaction): RecordInput {
  return {
    userId,
    originalTransactionId: tx.originalTransactionId,
    transactionId: tx.transactionId,
    productId: tx.productId,
    environment: tx.environment,
    purchasedAt: tx.purchaseDate,
    revokedAt: tx.revocationDate,
    revocationReason: tx.revocationReason,
    signedAt: tx.signedDate,
  };
}
