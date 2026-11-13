// app-store-notifications request handling: App Store Server Notifications V2
// -> Pro on the account that linked the purchase.
// index.ts wires the real Supabase client and Apple's root certificate into
// `Deps`; handler_test.ts drives the same code with fakes.
//
// Apple POSTs { signedPayload } without credentials, so nothing about the
// request is trusted except what Apple signed: the notification and the
// transaction inside it must both verify against the pinned Apple root, and
// both must name this app.
//
// Apple counts 200–206 as delivered and, in production, retries anything else
// at 1, 12, 24, 48 and 72 hours. So the handler answers
//   * 200 to every genuine notification for this app, whether it changed Pro
//     or was deliberately left alone;
//   * 4xx to anything that isn't one: forgeries, other apps, garbage;
//   * 500 when the database fails, so Apple tries again later.

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
  /** The app's Apple ID, the number in its App Store URL. Apple leaves it out of sandbox notifications. */
  appAppleId: number;
  productId: string;
  /** verify-purchase's rule: act on sandbox notifications only when ALLOW_SANDBOX_PURCHASES=true. */
  allowSandbox: boolean;
}

export interface Deps {
  /** Checks Apple's signature and certificate chain on a JWS. */
  verifyJws(jws: string): Promise<VerifyResult>;
  /** The account that linked the purchase (pro_purchases.user_id), or null if none has. */
  findOwner(originalTransactionId: string): Promise<string | null>;
  /** Stores the transaction and recomputes Pro (record_pro_transaction, migration v10). */
  recordTransaction(input: RecordInput): Promise<RecordResult>;
  config: Config;
}

/**
 * The notifications that change whether a purchase stands: a refund, an
 * entitlement lost from Family Sharing, and a refund Apple reversed.
 */
export const HANDLED_TYPES: readonly string[] = ["REFUND", "REVOKE", "REFUND_REVERSED"];

/** A V2 notification about a non-consumable is about 13 KB; anything far larger isn't one. */
export const MAX_SIGNED_PAYLOAD_LENGTH = 65_536;

export type ErrorCode =
  | "method_not_allowed"
  | "bad_request"
  | "invalid_signature"
  | "invalid_notification"
  | "wrong_app"
  | "server_error";

/** Why a genuine notification for this app changed nothing. */
export type IgnoreReason =
  /** Not a refund, revocation or reversal. */
  | "unhandled_type"
  /**
   * Sandbox, while ALLOW_SANDBOX_PURCHASES is off. Without a Sandbox Server
   * URL in App Store Connect, Apple sends sandbox notifications here too.
   */
  | "environment"
  /** About a product other than Gimme Pro. */
  | "other_product"
  /** No account has linked the purchase, so no account has Pro from it. */
  | "not_linked";

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function failure(status: number, code: ErrorCode, error: string): Response {
  return json(status, { code, error });
}

function ignored(reason: IgnoreReason): Response {
  return json(200, { status: "ignored", reason });
}

interface Notification {
  type: string;
  uuid: string;
  /** App metadata and the signed transaction. Summary and external-purchase notifications have none. */
  data: NotificationData | null;
}

interface NotificationData {
  bundleId: string | null;
  appAppleId: number | null;
  environment: string | null;
  signedTransactionInfo: string | null;
}

const text = (value: unknown) => typeof value === "string" && value.length > 0 ? value : null;
const isObject = (value: unknown): value is Record<string, unknown> =>
  !!value && typeof value === "object" && !Array.isArray(value);

/** Picks the fields we use out of Apple's responseBodyV2DecodedPayload. */
export function readNotification(payload: Record<string, unknown>): Notification | null {
  const type = text(payload.notificationType);
  if (!type) return null;
  const data = isObject(payload.data) ? payload.data : null;
  const appAppleId = data?.appAppleId;
  return {
    type,
    uuid: text(payload.notificationUUID) ?? "-",
    data: data && {
      bundleId: text(data.bundleId),
      appAppleId: typeof appAppleId === "number" && Number.isSafeInteger(appAppleId) ? appAppleId : null,
      environment: text(data.environment),
      signedTransactionInfo: text(data.signedTransactionInfo),
    },
  };
}

/** True when Apple signed `data` for some other app. */
function isForAnotherApp(data: NotificationData, config: Config): boolean {
  if (data.bundleId !== config.bundleId) return true;
  // Sandbox notifications carry no appAppleId; every other one must carry ours.
  if (data.appAppleId === null) return data.environment !== "Sandbox";
  return data.appAppleId !== config.appAppleId;
}

export async function handleAppStoreNotification(req: Request, deps: Deps): Promise<Response> {
  if (req.method !== "POST") return failure(405, "method_not_allowed", "Use POST.");

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return failure(400, "bad_request", "Body must be JSON.");
  }
  const signedPayload = isObject(body) ? body.signedPayload : undefined;
  if (typeof signedPayload !== "string" || signedPayload.length === 0) {
    return failure(400, "bad_request", "Missing signedPayload (App Store Server Notifications V2).");
  }
  if (signedPayload.length > MAX_SIGNED_PAYLOAD_LENGTH) {
    return failure(400, "bad_request", "That isn't an App Store notification.");
  }

  const outer = await verify(deps, signedPayload, "notification");
  if (outer instanceof Response) return outer;
  const notification = readNotification(outer);
  if (!notification) return failure(422, "invalid_notification", "The notification has no type.");
  const { type, uuid, data } = notification;

  if (data) {
    if (isForAnotherApp(data, deps.config)) {
      console.warn("app-store-notifications: refused another app's", type, uuid);
      return failure(422, "wrong_app", "This notification is for another app.");
    }
    if (!isAcceptedEnvironment(data.environment, deps.config.allowSandbox)) {
      console.log("app-store-notifications: ignored", type, uuid, data.environment);
      return ignored("environment");
    }
  }
  if (!HANDLED_TYPES.includes(type)) {
    console.log("app-store-notifications: ignored", type, uuid);
    return ignored("unhandled_type");
  }
  if (!data?.signedTransactionInfo) {
    return failure(422, "invalid_notification", `${type} without a signed transaction.`);
  }

  const inner = await verify(deps, data.signedTransactionInfo, "transaction");
  if (inner instanceof Response) return inner;
  const tx = readTransaction(inner);
  if (!tx) return failure(422, "invalid_notification", "The transaction is missing required fields.");
  if (tx.bundleId !== deps.config.bundleId) {
    return failure(422, "wrong_app", "This transaction belongs to another app.");
  }
  if (tx.environment !== data.environment) {
    return failure(422, "invalid_notification", "The transaction and the notification name different environments.");
  }
  if (tx.productId !== deps.config.productId) {
    console.log("app-store-notifications: ignored", type, uuid, "for another product");
    return ignored("other_product");
  }

  let owner: string | null;
  try {
    owner = await deps.findOwner(tx.originalTransactionId);
  } catch (error) {
    console.error("app-store-notifications: could not look up the purchase", error);
    return failure(500, "server_error", "Something went wrong.");
  }
  if (!owner) {
    // Nothing to take away or give back. The notification isn't stored either:
    // a pro_purchases row needs an owner.
    console.log("app-store-notifications: ignored", type, uuid, "for a purchase no account has linked");
    return ignored("not_linked");
  }

  // Recorded as the owner's own statement, as if their app had sent the
  // transaction to verify-purchase: record_pro_transaction() applies it when
  // Apple signed it after everything already on file. So whichever of a refund
  // and its reversal Apple signed last wins, in whatever order they arrive.
  let result: RecordResult;
  try {
    result = await deps.recordTransaction(recordInputFor(owner, tx));
  } catch (error) {
    console.error("app-store-notifications: could not record the transaction", error);
    return failure(500, "server_error", "Something went wrong.");
  }
  console.log("app-store-notifications:", type, uuid, result.outcome, tx.environment);
  return json(200, { status: "recorded", outcome: result.outcome });
}

/** The payload of a JWS the App Store signed, or the response refusing it. */
async function verify(
  deps: Deps,
  jws: string,
  what: "notification" | "transaction",
): Promise<Record<string, unknown> | Response> {
  let result: VerifyResult;
  try {
    result = await deps.verifyJws(jws);
  } catch (error) {
    console.error("app-store-notifications: verification crashed", error);
    return failure(500, "server_error", "Something went wrong.");
  }
  if (!result.ok) {
    console.warn("app-store-notifications: rejected", what, result.reason, result.detail);
    return failure(422, "invalid_signature", `This ${what} isn't signed by the App Store.`);
  }
  return result.payload;
}
