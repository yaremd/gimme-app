// identify-product request handling: photo -> product details for a new wish.
// index.ts wires the real Supabase, Anthropic and DeviceCheck clients into `Deps`;
// handler_test.ts drives the same code with fakes.
//
// Two ways in:
//   - signed in: the user's access token; monthly quota (free / Pro)
//   - signed out: one free try per device, proven with an Apple DeviceCheck token
//
// An identified product also comes back with an `offersToken`. Posting it back
// ({ offersToken, country, currency }) runs that photo's one shop search: a web
// search for shops selling the product, with each price confirmed on the shop's page.

import { type DeviceCheckClient, type DeviceCheckEnvironment, InvalidDeviceToken } from "./devicecheck.ts";
import {
  buildOffersUserText,
  describeOffersSearch,
  OFFERS_TICKET_TTL_SECONDS,
  type PageCheck,
  pickOffers,
  readReportedOffers,
  reportedCount,
  signTicket,
  UnsupportedCountry,
  verifyTicket,
} from "./offers.ts";
import { buildUserText, normalizeResult, type ProductIdentification } from "./prompt.ts";

export interface Usage {
  used: number;
  limit: number;
  remaining: number;
  /** ISO timestamp when the monthly quota resets (start of next month, UTC). */
  periodEnd: string;
}

export interface ClaimResult {
  allowed: boolean;
  requestId: string | null;
  /** Requests counted so far, including the one just claimed. */
  used: number;
  /** in_flight: too many free tries are running at once (see claim_identify_trial_slot). */
  reason: "ok" | "monthly_limit" | "trial_limit" | "in_flight" | "global_limit";
}

export interface ModelCall {
  stopReason: string | null;
  text: string | null;
  model: string;
  inputTokens: number;
  outputTokens: number;
}

export type RequestOutcome = "ok" | "not_product" | "refused" | "failed";

export interface Config {
  apiKeyConfigured: boolean;
  freeMonthlyLimit: number;
  proMonthlyLimit: number;
  /** Signed-out free tries allowed across all devices per 24 hours. */
  trialDailyLimit: number;
  globalDailyLimit: number;
  /** Largest decoded image accepted, in bytes. */
  maxImageBytes: number;
}

export interface OffersModelCall {
  stopReason: string | null;
  /** The input of the model's report_offers call; null when it didn't make one. */
  report: unknown;
  model: string;
  inputTokens: number;
  outputTokens: number;
  /** Web searches the call ran; each is billed on top of tokens. */
  searches: number;
}

export type OffersOutcome = "ok" | "none" | "failed";

export interface OffersDeps {
  /** HMAC key for offers tickets (see offers.ts). */
  ticketKey: CryptoKey;
  /**
   * Starts the identification's one shop search. False when there's nothing to start:
   * the identification didn't name a specific product, or its search already ran.
   */
  claim(requestId: string): Promise<boolean>;
  /** Makes the search available again after it failed before the model answered. */
  release(requestId: string): Promise<void>;
  finish(
    requestId: string,
    outcome: OffersOutcome,
    details: {
      model?: string;
      inputTokens?: number;
      outputTokens?: number;
      searches?: number;
      found: number;
      latencyMs: number;
    },
  ): Promise<void>;
  callModel(input: { userText: string; country: string | null }): Promise<OffersModelCall>;
  /** Reads a shop page with Gimme's link reader; null when it couldn't. */
  checkPage(url: string): Promise<PageCheck | null>;
}

export interface Deps {
  /** Resolves the signed-in caller from a bearer token; null when invalid or expired. */
  getUserId(accessToken: string): Promise<string | null>;
  isPro(userId: string): Promise<boolean>;
  claimSlot(userId: string, monthlyLimit: number, globalDailyLimit: number): Promise<ClaimResult>;
  claimTrialSlot(trialDailyLimit: number, globalDailyLimit: number): Promise<ClaimResult>;
  finishRequest(
    requestId: string,
    outcome: RequestOutcome,
    details: { resultStatus?: string; model?: string; inputTokens?: number; outputTokens?: number; latencyMs: number },
  ): Promise<void>;
  callModel(input: { imageBase64: string; mediaType: string; userText: string }): Promise<ModelCall>;
  /** Present when DeviceCheck secrets are set; without it signed-out callers must sign in. */
  deviceCheck?: DeviceCheckClient;
  /** Shop search for identified products; without it results come back with no offersToken. */
  offers?: OffersDeps;
  config: Config;
  now(): Date;
}

export type ErrorCode =
  | "method_not_allowed"
  | "unauthorized"
  | "trial_used"
  | "bad_request"
  | "image_too_large"
  | "quota_exceeded"
  | "busy"
  | "not_configured"
  | "refused"
  | "already_searched"
  | "upstream_error"
  | "server_error";

const MEDIA_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;
const SIGN_IN = "Sign in to identify photos.";

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function failure(status: number, code: ErrorCode, error: string, usage?: Usage): Response {
  return json(status, usage ? { code, error, usage } : { code, error });
}

export function startOfNextMonthUTC(now: Date): Date {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
}

function usageFor(used: number, limit: number, now: Date): Usage {
  return {
    used,
    limit,
    remaining: Math.max(0, limit - used),
    periodEnd: startOfNextMonthUTC(now).toISOString(),
  };
}

/** Decoded byte length of a base64 string without allocating the bytes. */
export function decodedLength(base64: string): number {
  const padding = base64.endsWith("==") ? 2 : base64.endsWith("=") ? 1 : 0;
  return Math.floor((base64.length * 3) / 4) - padding;
}

interface ParsedBody {
  imageBase64: string;
  mediaType: string;
  currency: string;
}

function parseBody(raw: unknown): ParsedBody | string {
  if (!raw || typeof raw !== "object") return "Body must be a JSON object.";
  const body = raw as Record<string, unknown>;

  if (typeof body.image !== "string" || body.image.length === 0) return "Missing image.";
  // Accept a data URL as well as bare base64; drop whitespace from wrapped encoders.
  const imageBase64 = body.image.replace(/^data:[^;,]+;base64,/, "").replace(/\s+/g, "");
  if (!BASE64.test(imageBase64)) return "Image must be base64-encoded.";

  const mediaType = typeof body.mediaType === "string" ? body.mediaType.toLowerCase() : "image/jpeg";
  if (!MEDIA_TYPES.has(mediaType)) return "Unsupported image type.";

  const currency = typeof body.currency === "string" && /^[A-Za-z]{3}$/.test(body.currency)
    ? body.currency.toUpperCase()
    : "USD";

  return { imageBase64, mediaType, currency };
}

interface DeviceProof {
  token: string;
  environment: DeviceCheckEnvironment;
}

function readDeviceProof(raw: unknown): DeviceProof | null {
  if (!raw || typeof raw !== "object") return null;
  const body = raw as Record<string, unknown>;
  if (typeof body.deviceToken !== "string" || body.deviceToken.length === 0) return null;
  return {
    token: body.deviceToken,
    environment: body.deviceCheckEnvironment === "development" ? "development" : "production",
  };
}

/** Who is asking: a signed-in user with a quota, or a device using its one free try. */
type Caller =
  | { kind: "user"; userId: string }
  | { kind: "trial"; device: DeviceProof; deviceCheck: DeviceCheckClient };

export async function handleIdentify(req: Request, deps: Deps): Promise<Response> {
  if (req.method !== "POST") return failure(405, "method_not_allowed", "Use POST.");

  let raw: unknown = undefined;
  try {
    raw = await req.json();
  } catch {
    raw = undefined;
  }

  // A shop search for an earlier identification: the ticket is the credential.
  if (raw && typeof raw === "object" && "offersToken" in raw) {
    return handleOffers(raw as Record<string, unknown>, deps);
  }

  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  let userId: string | null = null;
  if (token) {
    try {
      userId = await deps.getUserId(token);
    } catch {
      userId = null;
    }
  }

  let caller: Caller;
  if (userId) {
    caller = { kind: "user", userId };
  } else {
    const device = readDeviceProof(raw);
    if (!device || !deps.deviceCheck) return failure(401, "unauthorized", SIGN_IN);
    caller = { kind: "trial", device, deviceCheck: deps.deviceCheck };
  }

  if (!deps.config.apiKeyConfigured) {
    return failure(503, "not_configured", "Photo identification isn't set up yet.");
  }

  if (raw === undefined) return failure(400, "bad_request", "Body must be JSON.");
  const parsed = parseBody(raw);
  if (typeof parsed === "string") return failure(400, "bad_request", parsed);

  if (decodedLength(parsed.imageBase64) > deps.config.maxImageBytes) {
    return failure(413, "image_too_large", "That photo is too large. Try a smaller one.");
  }

  const now = deps.now();
  let limit = 0;
  let claim: ClaimResult;

  if (caller.kind === "user") {
    try {
      const pro = await deps.isPro(caller.userId);
      limit = pro ? deps.config.proMonthlyLimit : deps.config.freeMonthlyLimit;
      claim = await deps.claimSlot(caller.userId, limit, deps.config.globalDailyLimit);
    } catch (error) {
      console.error("identify-product: quota check failed", error);
      return failure(500, "server_error", "Something went wrong. Try again.");
    }
    if (!claim.allowed || !claim.requestId) {
      const usage = usageFor(claim.used, limit, now);
      if (claim.reason === "global_limit") {
        return failure(503, "busy", "Photo identification is busy right now. Try again later.", usage);
      }
      return failure(429, "quota_exceeded", "You've used all your photo identifications for this month.", usage);
    }
  } else {
    const { device, deviceCheck } = caller;
    try {
      if (await deviceCheck.isUsed(device.token, device.environment)) {
        return failure(401, "trial_used", "You've used your free try. Sign in to keep identifying photos.");
      }
    } catch (error) {
      if (error instanceof InvalidDeviceToken) return failure(401, "unauthorized", SIGN_IN);
      console.error("identify-product: DeviceCheck query failed", error);
      return failure(502, "upstream_error", "Couldn't check this device. Try again.");
    }
    try {
      claim = await deps.claimTrialSlot(deps.config.trialDailyLimit, deps.config.globalDailyLimit);
    } catch (error) {
      console.error("identify-product: trial check failed", error);
      return failure(500, "server_error", "Something went wrong. Try again.");
    }
    if (!claim.allowed || !claim.requestId) {
      return failure(503, "busy", "Photo identification is busy right now. Try again later.");
    }
    // Spend the try before the model call. DeviceCheck has no compare-and-set, so a
    // burst of parallel requests from one device could all pass isUsed above; the
    // trial claim caps how many free tries run at once, which bounds that burst.
    try {
      await deviceCheck.setUsed(device.token, device.environment, true);
    } catch (error) {
      console.error("identify-product: DeviceCheck update failed", error);
      await deps.finishRequest(claim.requestId, "failed", { latencyMs: 0 }).catch(() => {});
      return failure(502, "upstream_error", "Couldn't check this device. Try again.");
    }
  }

  const requestId = claim.requestId!;
  const finish = async (outcome: RequestOutcome, details: Parameters<Deps["finishRequest"]>[2]) => {
    try {
      await deps.finishRequest(requestId, outcome, details);
    } catch (error) {
      console.error("identify-product: could not record outcome", error);
    }
  };
  // Failed calls don't use up the caller's allowance: users get their slot back,
  // devices their free try. The daily caps still count calls the model billed for.
  const refund = async () => {
    if (caller.kind !== "trial") return;
    try {
      await caller.deviceCheck.setUsed(caller.device.token, caller.device.environment, false);
    } catch (error) {
      console.error("identify-product: could not restore the free try", error);
    }
  };
  const usageBefore = caller.kind === "user" ? usageFor(claim.used - 1, limit, now) : undefined;
  const usageAfter = caller.kind === "user" ? usageFor(claim.used, limit, now) : undefined;

  const started = Date.now();
  let call: ModelCall;
  try {
    call = await deps.callModel({
      imageBase64: parsed.imageBase64,
      mediaType: parsed.mediaType,
      userText: buildUserText(parsed.currency),
    });
  } catch (error) {
    console.error("identify-product: model call failed", error);
    await finish("failed", { latencyMs: Date.now() - started });
    await refund();
    return failure(502, "upstream_error", "Couldn't reach the identification service. Try again.", usageBefore);
  }

  const details = {
    model: call.model,
    inputTokens: call.inputTokens,
    outputTokens: call.outputTokens,
    latencyMs: Date.now() - started,
  };

  if (call.stopReason === "refusal") {
    await finish("refused", details);
    return failure(422, "refused", "Couldn't identify this photo. Try another one.", usageAfter);
  }

  let result: ProductIdentification | null = null;
  if (call.text && call.stopReason !== "max_tokens") {
    try {
      result = normalizeResult(JSON.parse(call.text), parsed.currency);
    } catch {
      result = null;
    }
  }
  if (!result) {
    console.error("identify-product: unusable model output", call.stopReason);
    await finish("failed", details);
    await refund();
    return failure(502, "upstream_error", "Couldn't read the result. Try again.", usageBefore);
  }

  await finish(result.status === "not_a_product" ? "not_product" : "ok", {
    ...details,
    resultStatus: result.status,
  });

  // Only a specific product is worth a shop search; "similar" keeps the plain search link.
  let offersToken: string | undefined;
  if (result.status === "identified" && deps.offers) {
    try {
      offersToken = await signTicket(deps.offers.ticketKey, {
        requestId,
        title: result.title,
        brand: result.brand,
        model: result.model,
        searchQuery: result.searchQuery || result.title,
        estimate: result.estimatedPrice,
        expiresAt: Math.floor(now.getTime() / 1000) + OFFERS_TICKET_TTL_SECONDS,
      });
    } catch (error) {
      console.error("identify-product: could not sign the offers ticket", error);
    }
  }

  const body = caller.kind === "user" ? { result, usage: usageAfter } : { result, trial: true };
  return json(200, offersToken ? { ...body, offersToken } : body);
}

/**
 * How many offers the app gets back: checked prices first, then search prices, each
 * cheapest first. Five, the most the model reports, so search prices aren't crowded out.
 */
const OFFERS_RETURNED = 5;

async function handleOffers(body: Record<string, unknown>, deps: Deps): Promise<Response> {
  const offers = deps.offers;
  if (!deps.config.apiKeyConfigured || !offers) {
    return failure(503, "not_configured", "Shop search isn't set up yet.");
  }

  const nowSeconds = Math.floor(deps.now().getTime() / 1000);
  const ticket = typeof body.offersToken === "string"
    ? await verifyTicket(offers.ticketKey, body.offersToken, nowSeconds)
    : null;
  if (!ticket) return failure(401, "unauthorized", "This search has expired. Identify the photo again.");

  const country = typeof body.country === "string" && /^[A-Za-z]{2}$/.test(body.country)
    ? body.country.toUpperCase()
    : null;
  const currency = typeof body.currency === "string" && /^[A-Za-z]{3}$/.test(body.currency)
    ? body.currency.toUpperCase()
    : ticket.estimate?.currency ?? "USD";

  let claimed: boolean;
  try {
    claimed = await offers.claim(ticket.requestId);
  } catch (error) {
    console.error("identify-product: offers claim failed", error);
    return failure(500, "server_error", "Something went wrong. Try again.");
  }
  if (!claimed) return failure(409, "already_searched", "Shops were already searched for this photo.");

  const started = Date.now();
  const finish = async (outcome: Parameters<OffersDeps["finish"]>[1], details: Parameters<OffersDeps["finish"]>[2]) => {
    try {
      await offers.finish(ticket.requestId, outcome, details);
    } catch (error) {
      console.error("identify-product: could not record the offers outcome", error);
    }
  };

  const userText = buildOffersUserText(ticket, country, currency);
  let call: OffersModelCall;
  try {
    try {
      call = await offers.callModel({ userText, country });
    } catch (error) {
      if (!(error instanceof UnsupportedCountry)) throw error;
      // The search can't be pinned to this country; the prompt still names it.
      console.log(`identify-product: web search can't be localised to ${error.country}; searching without a location`);
      call = await offers.callModel({ userText, country: null });
    }
  } catch (error) {
    console.error("identify-product: offers search failed", error);
    try {
      await offers.release(ticket.requestId);
    } catch (releaseError) {
      console.error("identify-product: could not release the offers search", releaseError);
    }
    return failure(502, "upstream_error", "Couldn't search shops. Try again.");
  }

  const details = {
    model: call.model,
    inputTokens: call.inputTokens,
    outputTokens: call.outputTokens,
    searches: call.searches,
  };
  const reported = call.stopReason === "refusal" ? null : readReportedOffers(call.report);
  if (!reported) {
    console.error("identify-product: no usable offers report", call.stopReason);
    await finish("failed", { ...details, found: 0, latencyMs: Date.now() - started });
    return json(200, { offers: [] });
  }

  // Check each price on the shop's own page, since search results can be stale. A page
  // that can't be checked keeps the search's price, marked as such (see pickOffers).
  const checked = await Promise.all(reported.map(async (offer) => {
    let page: PageCheck | null = null;
    try {
      page = await offers.checkPage(offer.url);
    } catch {
      page = null;
    }
    return { reported: offer, page };
  }));
  const { offers: picked, drops } = pickOffers(checked, {
    currency,
    estimate: ticket.estimate,
    max: OFFERS_RETURNED,
  });
  const latencyMs = Date.now() - started;
  console.log(describeOffersSearch({
    model: call.model,
    searches: call.searches,
    suggested: reportedCount(call.report),
    shopPages: reported.length,
    drops,
    found: picked.length,
    fromSearch: picked.filter((offer) => !offer.checked).length,
    latencyMs,
  }));

  await finish(picked.length > 0 ? "ok" : "none", { ...details, found: picked.length, latencyMs });
  return json(200, { offers: picked });
}
