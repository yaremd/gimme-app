// Run: deno test --node-modules-dir=none supabase/functions/identify-product/
import { assert, assertEquals } from "jsr:@std/assert@1";
import { type DeviceCheckClient, type DeviceCheckEnvironment, InvalidDeviceToken } from "./devicecheck.ts";
import {
  type ClaimResult,
  decodedLength,
  type Deps,
  handleIdentify,
  type ModelCall,
  type OffersDeps,
  type OffersModelCall,
  type OffersOutcome,
  type RequestOutcome,
  startOfNextMonthUTC,
} from "./handler.ts";
import {
  buildOffersUserText,
  makeTicketKey,
  type OffersTicket,
  type PageCheck,
  signTicket,
  UnsupportedCountry,
  verifyTicket,
} from "./offers.ts";
import { normalizeResult } from "./prompt.ts";

class FakeDeviceCheck implements DeviceCheckClient {
  used = new Set<string>();
  events: string[] = [];
  failQuery?: Error;
  failUpdate?: Error;

  isUsed(token: string, environment: DeviceCheckEnvironment): Promise<boolean> {
    this.events.push(`query:${token}:${environment}`);
    if (this.failQuery) return Promise.reject(this.failQuery);
    return Promise.resolve(this.used.has(token));
  }

  setUsed(token: string, environment: DeviceCheckEnvironment, used: boolean): Promise<void> {
    this.events.push(`set:${token}:${environment}:${used}`);
    if (this.failUpdate) return Promise.reject(this.failUpdate);
    if (used) this.used.add(token);
    else this.used.delete(token);
    return Promise.resolve();
  }
}

const IMAGE = "aGVsbG8gd29ybGQ="; // "hello world" — the handler never decodes it
const NOW = new Date("2026-11-13T10:00:00Z");

const goodModelOutput = {
  status: "identified",
  title: "Nike Air Max 90",
  brand: "Nike",
  model: "Air Max 90",
  color: "White/Infrared",
  category: "Sneakers",
  description: "Classic low-top running sneaker with a visible Air unit.",
  estimatedPrice: { low: 140, high: 120.4 },
  searchQuery: "Nike Air Max 90 white infrared",
  confidence: 0.91,
};

interface Recorder {
  claims: Array<{ userId: string; monthlyLimit: number; globalDailyLimit: number }>;
  trialClaims: Array<{ trialDailyLimit: number; globalDailyLimit: number }>;
  finishes: Array<{ requestId: string; outcome: RequestOutcome; resultStatus?: string }>;
  modelCalls: Array<{ mediaType: string; userText: string; imageBase64: string }>;
}

function makeDeps(overrides: {
  userId?: string | null;
  pro?: boolean;
  claim?: Partial<ClaimResult>;
  trialClaim?: Partial<ClaimResult>;
  deviceCheck?: FakeDeviceCheck;
  model?: Partial<ModelCall> | (() => Promise<ModelCall>);
  apiKeyConfigured?: boolean;
  maxImageBytes?: number;
  offers?: OffersDeps;
} = {}): { deps: Deps; rec: Recorder } {
  const rec: Recorder = { claims: [], trialClaims: [], finishes: [], modelCalls: [] };
  const deps: Deps = {
    getUserId: () => Promise.resolve(overrides.userId === undefined ? "user-1" : overrides.userId),
    isPro: () => Promise.resolve(overrides.pro ?? false),
    claimSlot: (userId, monthlyLimit, globalDailyLimit) => {
      rec.claims.push({ userId, monthlyLimit, globalDailyLimit });
      return Promise.resolve({ allowed: true, requestId: "req-1", used: 2, reason: "ok", ...overrides.claim });
    },
    claimTrialSlot: (trialDailyLimit, globalDailyLimit) => {
      rec.trialClaims.push({ trialDailyLimit, globalDailyLimit });
      return Promise.resolve({ allowed: true, requestId: "trial-1", used: 1, reason: "ok", ...overrides.trialClaim });
    },
    deviceCheck: overrides.deviceCheck,
    finishRequest: (requestId, outcome, details) => {
      rec.finishes.push({ requestId, outcome, resultStatus: details.resultStatus });
      return Promise.resolve();
    },
    callModel: (input) => {
      rec.modelCalls.push(input);
      if (typeof overrides.model === "function") return overrides.model();
      return Promise.resolve({
        stopReason: "end_turn",
        text: JSON.stringify(goodModelOutput),
        model: "claude-opus-5-5",
        inputTokens: 1800,
        outputTokens: 240,
        ...overrides.model,
      });
    },
    offers: overrides.offers,
    config: {
      apiKeyConfigured: overrides.apiKeyConfigured ?? true,
      freeMonthlyLimit: 5,
      proMonthlyLimit: 100,
      trialDailyLimit: 100,
      globalDailyLimit: 300,
      maxImageBytes: overrides.maxImageBytes ?? 4 * 1024 * 1024,
    },
    now: () => NOW,
  };
  return { deps, rec };
}

function post(body: unknown, auth: string | null = "Bearer user-token"): Request {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (auth !== null) headers.Authorization = auth;
  return new Request("http://localhost/identify-product", {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

Deno.test("rejects non-POST requests", async () => {
  const { deps } = makeDeps();
  const res = await handleIdentify(new Request("http://localhost/identify-product"), deps);
  assertEquals(res.status, 405);
});

Deno.test("requires a bearer token", async () => {
  const { deps, rec } = makeDeps();
  const res = await handleIdentify(post({ image: IMAGE }, null), deps);
  assertEquals(res.status, 401);
  assertEquals((await res.json()).code, "unauthorized");
  assertEquals(rec.claims.length, 0);
});

Deno.test("rejects an invalid or expired token", async () => {
  const { deps, rec } = makeDeps({ userId: null });
  const res = await handleIdentify(post({ image: IMAGE }), deps);
  assertEquals(res.status, 401);
  assertEquals(rec.claims.length, 0);
});

Deno.test("reports not_configured without spending quota when the API key is missing", async () => {
  const { deps, rec } = makeDeps({ apiKeyConfigured: false });
  const res = await handleIdentify(post({ image: IMAGE }), deps);
  assertEquals(res.status, 503);
  assertEquals((await res.json()).code, "not_configured");
  assertEquals(rec.claims.length, 0);
});

Deno.test("validates the request body", async () => {
  const cases: unknown[] = [
    "not json",
    { image: "" },
    { image: "not base64 !!!" },
    { image: IMAGE, mediaType: "image/heic" },
  ];
  for (const body of cases) {
    const { deps, rec } = makeDeps();
    const res = await handleIdentify(post(body), deps);
    assertEquals(res.status, 400, `body: ${JSON.stringify(body)}`);
    assertEquals((await res.json()).code, "bad_request");
    assertEquals(rec.claims.length, 0);
  }
});

Deno.test("rejects oversized images before claiming quota", async () => {
  const { deps, rec } = makeDeps({ maxImageBytes: 8 });
  const res = await handleIdentify(post({ image: IMAGE }), deps);
  assertEquals(res.status, 413);
  assertEquals(rec.claims.length, 0);
});

Deno.test("returns quota_exceeded with usage when the monthly limit is reached", async () => {
  const { deps, rec } = makeDeps({ claim: { allowed: false, requestId: null, used: 5, reason: "monthly_limit" } });
  const res = await handleIdentify(post({ image: IMAGE }), deps);
  assertEquals(res.status, 429);
  const body = await res.json();
  assertEquals(body.code, "quota_exceeded");
  assertEquals(body.usage, { used: 5, limit: 5, remaining: 0, periodEnd: "2026-12-01T00:00:00.000Z" });
  assertEquals(rec.modelCalls.length, 0);
});

Deno.test("returns busy when the global daily cap is reached", async () => {
  const { deps, rec } = makeDeps({ claim: { allowed: false, requestId: null, used: 1, reason: "global_limit" } });
  const res = await handleIdentify(post({ image: IMAGE }), deps);
  assertEquals(res.status, 503);
  assertEquals((await res.json()).code, "busy");
  assertEquals(rec.modelCalls.length, 0);
});

Deno.test("identifies a product and records the outcome", async () => {
  const { deps, rec } = makeDeps();
  const res = await handleIdentify(
    post({ image: `data:image/jpeg;base64,${IMAGE}`, mediaType: "IMAGE/JPEG", currency: "gbp" }),
    deps,
  );
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.result.status, "identified");
  assertEquals(body.result.title, "Nike Air Max 90");
  assertEquals(body.result.estimatedPrice, { low: 120, high: 140, currency: "GBP" });
  assertEquals(body.usage, { used: 2, limit: 5, remaining: 3, periodEnd: "2026-12-01T00:00:00.000Z" });

  assertEquals(rec.claims, [{ userId: "user-1", monthlyLimit: 5, globalDailyLimit: 300 }]);
  assertEquals(rec.modelCalls[0].imageBase64, IMAGE);
  assertEquals(rec.modelCalls[0].mediaType, "image/jpeg");
  assert(rec.modelCalls[0].userText.includes("GBP"));
  assertEquals(rec.finishes, [{ requestId: "req-1", outcome: "ok", resultStatus: "identified" }]);
});

Deno.test("uses the Pro monthly limit for Pro users", async () => {
  const { deps, rec } = makeDeps({ pro: true, claim: { used: 40 } });
  const res = await handleIdentify(post({ image: IMAGE }), deps);
  assertEquals(res.status, 200);
  assertEquals(rec.claims[0].monthlyLimit, 100);
  assertEquals((await res.json()).usage.remaining, 60);
});

Deno.test("passes through not_a_product and counts it", async () => {
  const { deps, rec } = makeDeps({
    model: {
      text: JSON.stringify({ ...goodModelOutput, status: "not_a_product", title: "Sunset", brand: "x" }),
    },
  });
  const res = await handleIdentify(post({ image: IMAGE }), deps);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.result.status, "not_a_product");
  assertEquals(body.result.title, "");
  assertEquals(body.result.brand, null);
  assertEquals(rec.finishes[0].outcome, "not_product");
});

Deno.test("maps a refusal to 422", async () => {
  const { deps, rec } = makeDeps({ model: { stopReason: "refusal", text: null } });
  const res = await handleIdentify(post({ image: IMAGE }), deps);
  assertEquals(res.status, 422);
  assertEquals((await res.json()).code, "refused");
  assertEquals(rec.finishes[0].outcome, "refused");
});

Deno.test("does not count a failed model call against the quota", async () => {
  const { deps, rec } = makeDeps({ model: () => Promise.reject(new Error("network down")) });
  const res = await handleIdentify(post({ image: IMAGE }), deps);
  assertEquals(res.status, 502);
  const body = await res.json();
  assertEquals(body.code, "upstream_error");
  assertEquals(body.usage.used, 1);
  assertEquals(body.usage.remaining, 4);
  assertEquals(rec.finishes[0].outcome, "failed");
});

Deno.test("treats unreadable or truncated output as a failure", async () => {
  for (const model of [{ text: "not json" }, { stopReason: "max_tokens" }, { text: "[1,2]" }]) {
    const { deps, rec } = makeDeps({ model });
    const res = await handleIdentify(post({ image: IMAGE }), deps);
    assertEquals(res.status, 502, JSON.stringify(model));
    assertEquals(rec.finishes[0].outcome, "failed");
  }
});

Deno.test("a quota check error returns 500 without calling the model", async () => {
  const { deps, rec } = makeDeps();
  deps.claimSlot = () => Promise.reject(new Error("db down"));
  const res = await handleIdentify(post({ image: IMAGE }), deps);
  assertEquals(res.status, 500);
  assertEquals(rec.modelCalls.length, 0);
});

// --- Signed-out free try (one per device, via DeviceCheck) ---

Deno.test("signed-out callers without a device token must sign in", async () => {
  const deviceCheck = new FakeDeviceCheck();
  const { deps, rec } = makeDeps({ userId: null, deviceCheck });
  const res = await handleIdentify(post({ image: IMAGE }, null), deps);
  assertEquals(res.status, 401);
  assertEquals((await res.json()).code, "unauthorized");
  assertEquals(deviceCheck.events, []);
  assertEquals(rec.trialClaims.length, 0);
});

Deno.test("no free try when DeviceCheck isn't configured", async () => {
  const { deps, rec } = makeDeps({ userId: null });
  const res = await handleIdentify(post({ image: IMAGE, deviceToken: "dev-1" }, null), deps);
  assertEquals(res.status, 401);
  assertEquals((await res.json()).code, "unauthorized");
  assertEquals(rec.modelCalls.length, 0);
});

Deno.test("a device gets exactly one free try", async () => {
  const deviceCheck = new FakeDeviceCheck();
  const { deps, rec } = makeDeps({ userId: null, deviceCheck });

  const first = await handleIdentify(post({ image: IMAGE, deviceToken: "dev-1" }, null), deps);
  assertEquals(first.status, 200);
  const body = await first.json();
  assertEquals(body.trial, true);
  assertEquals(body.usage, undefined);
  assertEquals(body.result.title, "Nike Air Max 90");
  assertEquals(rec.trialClaims, [{ trialDailyLimit: 100, globalDailyLimit: 300 }]);
  assertEquals(deviceCheck.events, ["query:dev-1:production", "set:dev-1:production:true"]);
  assertEquals(rec.finishes, [{ requestId: "trial-1", outcome: "ok", resultStatus: "identified" }]);

  const second = await handleIdentify(post({ image: IMAGE, deviceToken: "dev-1" }, null), deps);
  assertEquals(second.status, 401);
  assertEquals((await second.json()).code, "trial_used");
  assertEquals(rec.modelCalls.length, 1);
});

Deno.test("a failed model call gives the free try back", async () => {
  const deviceCheck = new FakeDeviceCheck();
  const { deps, rec } = makeDeps({
    userId: null,
    deviceCheck,
    model: () => Promise.reject(new Error("network down")),
  });
  const res = await handleIdentify(post({ image: IMAGE, deviceToken: "dev-1" }, null), deps);
  assertEquals(res.status, 502);
  assertEquals((await res.json()).usage, undefined);
  assertEquals(deviceCheck.used.has("dev-1"), false);
  assertEquals(deviceCheck.events.at(-1), "set:dev-1:production:false");
  assertEquals(rec.finishes[0].outcome, "failed");
});

Deno.test("a refusal still spends the free try", async () => {
  const deviceCheck = new FakeDeviceCheck();
  const { deps } = makeDeps({ userId: null, deviceCheck, model: { stopReason: "refusal", text: null } });
  const res = await handleIdentify(post({ image: IMAGE, deviceToken: "dev-1" }, null), deps);
  assertEquals(res.status, 422);
  assertEquals(deviceCheck.used.has("dev-1"), true);
});

Deno.test("the daily cap on free tries returns busy without spending the try", async () => {
  const deviceCheck = new FakeDeviceCheck();
  const { deps, rec } = makeDeps({
    userId: null,
    deviceCheck,
    trialClaim: { allowed: false, requestId: null, used: 100, reason: "trial_limit" },
  });
  const res = await handleIdentify(post({ image: IMAGE, deviceToken: "dev-1" }, null), deps);
  assertEquals(res.status, 503);
  assertEquals((await res.json()).code, "busy");
  assertEquals(deviceCheck.used.size, 0);
  assertEquals(rec.modelCalls.length, 0);
});

Deno.test("a token Apple rejects means sign in; an Apple outage is retryable", async () => {
  const rejected = new FakeDeviceCheck();
  rejected.failQuery = new InvalidDeviceToken("Missing or incorrectly formatted device token payload");
  let res = await handleIdentify(post({ image: IMAGE, deviceToken: "bad" }, null), makeDeps({ userId: null, deviceCheck: rejected }).deps);
  assertEquals(res.status, 401);
  assertEquals((await res.json()).code, "unauthorized");

  const down = new FakeDeviceCheck();
  down.failQuery = new Error("503 from Apple");
  res = await handleIdentify(post({ image: IMAGE, deviceToken: "dev-1" }, null), makeDeps({ userId: null, deviceCheck: down }).deps);
  assertEquals(res.status, 502);
  assertEquals((await res.json()).code, "upstream_error");
});

Deno.test("if the try can't be recorded, the request is cancelled", async () => {
  const deviceCheck = new FakeDeviceCheck();
  deviceCheck.failUpdate = new Error("503 from Apple");
  const { deps, rec } = makeDeps({ userId: null, deviceCheck });
  const res = await handleIdentify(post({ image: IMAGE, deviceToken: "dev-1" }, null), deps);
  assertEquals(res.status, 502);
  assertEquals(rec.modelCalls.length, 0);
  assertEquals(rec.finishes, [{ requestId: "trial-1", outcome: "failed", resultStatus: undefined }]);
});

Deno.test("development tokens are passed through for the client to resolve", async () => {
  const deviceCheck = new FakeDeviceCheck();
  const { deps } = makeDeps({ userId: null, deviceCheck });
  await handleIdentify(post({ image: IMAGE, deviceToken: "dev-1", deviceCheckEnvironment: "development" }, null), deps);
  assertEquals(deviceCheck.events[0], "query:dev-1:development");
});

Deno.test("a signed-in user never uses the free-try path", async () => {
  const deviceCheck = new FakeDeviceCheck();
  const { deps, rec } = makeDeps({ deviceCheck });
  const res = await handleIdentify(post({ image: IMAGE, deviceToken: "dev-1" }), deps);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.trial, undefined);
  assertEquals(body.usage.remaining, 3);
  assertEquals(deviceCheck.events, []);
  assertEquals(rec.trialClaims.length, 0);
});

Deno.test("normalizeResult coerces odd values into range", () => {
  const r = normalizeResult({
    status: "identified",
    title: "  A   very   long   name ".repeat(10),
    brand: "",
    model: 42,
    color: null,
    category: "Toys",
    description: "x".repeat(500),
    estimatedPrice: { low: -5, high: 10 },
    searchQuery: "",
    confidence: 7,
  }, "USD")!;
  assert(r.title.length <= 80);
  assertEquals(r.brand, null);
  assertEquals(r.model, null);
  assertEquals(r.description.length, 200);
  assertEquals(r.estimatedPrice, null);
  assertEquals(r.searchQuery, r.title);
  assertEquals(r.confidence, 1);
});

Deno.test("normalizeResult downgrades an identification with no title", () => {
  const r = normalizeResult({ ...goodModelOutput, title: "   " }, "USD")!;
  assertEquals(r.status, "unclear");
  assertEquals(r.estimatedPrice, null);
  assertEquals(normalizeResult(null, "USD"), null);
  assertEquals(normalizeResult({ ...goodModelOutput, status: "bogus" }, "USD")!.status, "unclear");
});

Deno.test("startOfNextMonthUTC rolls over the year", () => {
  assertEquals(startOfNextMonthUTC(new Date("2026-12-31T23:59:59Z")).toISOString(), "2027-01-01T00:00:00.000Z");
});

Deno.test("decodedLength matches the decoded byte count", () => {
  for (const s of ["", "a", "ab", "abc", "hello world"]) {
    assertEquals(decodedLength(btoa(s)), s.length);
  }
});

// MARK: - Shop search

const NIKE_URL = "https://www.nike.com/gb/t/air-max-90-shoes";
const JD_URL = "https://www.jdsports.co.uk/product/air-max-90/123";

const defaultReport = {
  offers: [
    { store: "Nike", url: NIKE_URL, price: 129.99, currency: "GBP" },
    { store: "JD Sports", url: JD_URL, price: 119.99, currency: "GBP" },
    { store: "Google Shopping", url: "https://www.google.com/shopping/product/1", price: 99, currency: "GBP" },
  ],
};

const defaultPages: Record<string, PageCheck | null | Error> = {
  [NIKE_URL]: { price: 129.99, currency: "GBP", title: "Nike Air Max 90 Shoes" },
  [JD_URL]: { price: 114.99, currency: "GBP", title: "Nike Air Max 90 | JD Sports" },
};

interface OffersRecorder {
  claims: string[];
  releases: string[];
  finishes: Array<{ requestId: string; outcome: OffersOutcome; found: number; searches?: number }>;
  modelCalls: Array<{ userText: string; country: string | null }>;
  pageChecks: string[];
}

async function makeOffers(overrides: {
  claim?: boolean | Error;
  model?: Partial<OffersModelCall> | Error;
  pages?: Record<string, PageCheck | null | Error>;
  /** Countries the web search refuses to localise to, like Anthropic does for UA. */
  unsupportedCountries?: string[];
} = {}): Promise<{ offers: OffersDeps; rec: OffersRecorder }> {
  const rec: OffersRecorder = { claims: [], releases: [], finishes: [], modelCalls: [], pageChecks: [] };
  const offers: OffersDeps = {
    ticketKey: await makeTicketKey("test-secret"),
    claim: (requestId) => {
      rec.claims.push(requestId);
      if (overrides.claim instanceof Error) return Promise.reject(overrides.claim);
      return Promise.resolve(overrides.claim ?? true);
    },
    release: (requestId) => {
      rec.releases.push(requestId);
      return Promise.resolve();
    },
    finish: (requestId, outcome, details) => {
      rec.finishes.push({ requestId, outcome, found: details.found, searches: details.searches });
      return Promise.resolve();
    },
    callModel: (input) => {
      rec.modelCalls.push(input);
      if (input.country && overrides.unsupportedCountries?.includes(input.country)) {
        return Promise.reject(new UnsupportedCountry(input.country));
      }
      if (overrides.model instanceof Error) return Promise.reject(overrides.model);
      return Promise.resolve({
        stopReason: "tool_use",
        report: defaultReport,
        model: "claude-opus-5-5",
        inputTokens: 9000,
        outputTokens: 1200,
        searches: 2,
        ...overrides.model,
      });
    },
    checkPage: (url) => {
      rec.pageChecks.push(url);
      const page = (overrides.pages ?? defaultPages)[url];
      if (page instanceof Error) return Promise.reject(page);
      return Promise.resolve(page ?? null);
    },
  };
  return { offers, rec };
}

function ticketFor(overrides: Partial<OffersTicket> = {}): OffersTicket {
  return {
    requestId: "req-1",
    title: "Nike Air Max 90",
    brand: "Nike",
    model: "Air Max 90",
    searchQuery: "Nike Air Max 90 white infrared",
    estimate: { low: 110, high: 140, currency: "GBP" },
    expiresAt: Math.floor(NOW.getTime() / 1000) + 600,
    ...overrides,
  };
}

Deno.test("an identified product comes back with a ticket for its shop search", async () => {
  const { offers } = await makeOffers();
  const { deps } = makeDeps({ offers });
  const res = await handleIdentify(post({ image: IMAGE, currency: "GBP" }), deps);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(typeof body.offersToken, "string");

  const ticket = await verifyTicket(offers.ticketKey, body.offersToken, Math.floor(NOW.getTime() / 1000));
  assert(ticket, "the ticket verifies");
  assertEquals(ticket.requestId, "req-1");
  assertEquals(ticket.title, "Nike Air Max 90");
  assertEquals(ticket.searchQuery, "Nike Air Max 90 white infrared");
  assertEquals(ticket.estimate, { low: 120, high: 140, currency: "GBP" });
  assertEquals(ticket.expiresAt, Math.floor(NOW.getTime() / 1000) + 15 * 60);
});

Deno.test("a free try's identified product gets a ticket too", async () => {
  const { offers } = await makeOffers();
  const { deps } = makeDeps({ userId: null, deviceCheck: new FakeDeviceCheck(), offers });
  const res = await handleIdentify(post({ image: IMAGE, deviceToken: "device-a" }, null), deps);
  const body = await res.json();
  assertEquals(body.trial, true);
  const ticket = await verifyTicket(offers.ticketKey, body.offersToken, Math.floor(NOW.getTime() / 1000));
  assertEquals(ticket?.requestId, "trial-1");
});

Deno.test("a close match gets a ticket that asks for the closest item", async () => {
  const { offers } = await makeOffers();
  const similar = makeDeps({
    offers,
    model: { text: JSON.stringify({ ...goodModelOutput, status: "similar" }) },
  });
  const similarBody = await (await handleIdentify(post({ image: IMAGE }), similar.deps)).json();
  assertEquals(similarBody.result.status, "similar");
  const ticket = await verifyTicket(offers.ticketKey, similarBody.offersToken, Math.floor(NOW.getTime() / 1000));
  assertEquals(ticket?.similar, true);
  assert(buildOffersUserText(ticket!, "GB", "GBP").includes("Exact product: unknown"));

  const exact = makeDeps({ offers });
  const exactBody = await (await handleIdentify(post({ image: IMAGE }), exact.deps)).json();
  const exactTicket = await verifyTicket(offers.ticketKey, exactBody.offersToken, Math.floor(NOW.getTime() / 1000));
  assertEquals(exactTicket?.similar, false);
});

Deno.test("not a product, and setups without shop search, get no ticket", async () => {
  const { offers } = await makeOffers();
  const notProduct = makeDeps({
    offers,
    model: { text: JSON.stringify({ ...goodModelOutput, status: "not_a_product" }) },
  });
  const notProductBody = await (await handleIdentify(post({ image: IMAGE }), notProduct.deps)).json();
  assertEquals(notProductBody.result.status, "not_a_product");
  assertEquals(notProductBody.offersToken, undefined);

  const noOffers = makeDeps();
  const noOffersBody = await (await handleIdentify(post({ image: IMAGE }), noOffers.deps)).json();
  assertEquals(noOffersBody.result.status, "identified");
  assertEquals(noOffersBody.offersToken, undefined);
});

Deno.test("a shop search returns offers confirmed on the shop's page, cheapest first", async () => {
  const { offers, rec } = await makeOffers();
  const { deps, rec: identifyRec } = makeDeps({ offers });
  const token = await signTicket(offers.ticketKey, ticketFor());

  const res = await handleIdentify(post({ offersToken: token, country: "gb", currency: "gbp" }, null), deps);
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.offers, [
    {
      store: "JD Sports",
      url: JD_URL,
      title: "Nike Air Max 90 | JD Sports",
      price: 114.99, // the page's price, not the search result's 119.99
      currency: "GBP",
      checked: true,
      best: true,
    },
    {
      store: "Nike",
      url: NIKE_URL,
      title: "Nike Air Max 90 Shoes",
      price: 129.99,
      currency: "GBP",
      checked: true,
      best: false,
    },
  ]);

  assertEquals(rec.claims, ["req-1"]);
  assertEquals(rec.modelCalls.length, 1);
  assertEquals(rec.modelCalls[0].country, "GB");
  assert(rec.modelCalls[0].userText.includes("User's country: GB"));
  assert(rec.modelCalls[0].userText.includes("Prices in: GBP"));
  // Google isn't a shop, so its page is never fetched.
  assertEquals(rec.pageChecks.sort(), [JD_URL, NIKE_URL].sort());
  assertEquals(rec.finishes, [{ requestId: "req-1", outcome: "ok", found: 2, searches: 2 }]);
  // No identification or quota is involved.
  assertEquals(identifyRec.claims.length, 0);
  assertEquals(identifyRec.modelCalls.length, 0);
});

Deno.test("a country the web search can't localise to is searched without a location", async () => {
  const { offers, rec } = await makeOffers({ unsupportedCountries: ["UA"] });
  const { deps } = makeDeps({ offers });
  const res = await handleIdentify(
    post({ offersToken: await signTicket(offers.ticketKey, ticketFor()), country: "UA", currency: "GBP" }, null),
    deps,
  );
  assertEquals(res.status, 200);
  assertEquals((await res.json()).offers.length, 2);
  assertEquals(rec.modelCalls.map((call) => call.country), ["UA", null]);
  // The prompt still tells the model where the user is.
  assert(rec.modelCalls[1].userText.includes("User's country: UA"));
  assertEquals(rec.releases.length, 0);
  assertEquals(rec.finishes[0].outcome, "ok");
});

Deno.test("a shop search needs a valid ticket that hasn't expired", async () => {
  const { offers, rec } = await makeOffers();
  const { deps } = makeDeps({ offers });
  const good = await signTicket(offers.ticketKey, ticketFor());
  const [payload, mac] = good.split(".");
  const forged = await signTicket(await makeTicketKey("another-secret"), ticketFor());
  const expired = await signTicket(offers.ticketKey, ticketFor({ expiresAt: Math.floor(NOW.getTime() / 1000) - 1 }));
  const otherPayload = (await signTicket(offers.ticketKey, ticketFor({ requestId: "req-2" }))).split(".")[0];

  for (const offersToken of ["", "nonsense", `${otherPayload}.${mac}`, `${payload}.${mac}x`, forged, expired, 42]) {
    const res = await handleIdentify(post({ offersToken }, null), deps);
    assertEquals(res.status, 401, `token: ${offersToken}`);
    assertEquals((await res.json()).code, "unauthorized");
  }
  assertEquals(rec.claims.length, 0);
  assertEquals(rec.modelCalls.length, 0);
});

Deno.test("each identification gets one shop search", async () => {
  const { offers, rec } = await makeOffers({ claim: false });
  const { deps } = makeDeps({ offers });
  const res = await handleIdentify(post({ offersToken: await signTicket(offers.ticketKey, ticketFor()) }, null), deps);
  assertEquals(res.status, 409);
  assertEquals((await res.json()).code, "already_searched");
  assertEquals(rec.modelCalls.length, 0);
});

Deno.test("a search that failed before the model answered can be retried", async () => {
  const { offers, rec } = await makeOffers({ model: new Error("timeout") });
  const { deps } = makeDeps({ offers });
  const res = await handleIdentify(post({ offersToken: await signTicket(offers.ticketKey, ticketFor()) }, null), deps);
  assertEquals(res.status, 502);
  assertEquals((await res.json()).code, "upstream_error");
  assertEquals(rec.releases, ["req-1"]);
  assertEquals(rec.finishes.length, 0);
});

Deno.test("a refusal or a missing report means no offers", async () => {
  for (const model of [{ stopReason: "refusal" }, { stopReason: "end_turn", report: null }, { report: { offers: "x" } }]) {
    const { offers, rec } = await makeOffers({ model });
    const { deps } = makeDeps({ offers });
    const res = await handleIdentify(post({ offersToken: await signTicket(offers.ticketKey, ticketFor()) }, null), deps);
    assertEquals(res.status, 200);
    assertEquals((await res.json()).offers, []);
    assertEquals(rec.finishes, [{ requestId: "req-1", outcome: "failed", found: 0, searches: 2 }]);
    assertEquals(rec.pageChecks.length, 0);
  }
});

Deno.test("offers with no price in the right currency, on the page or in the search, are dropped", async () => {
  const { offers, rec } = await makeOffers({
    model: {
      report: {
        offers: [
          { store: "Nike", url: NIKE_URL, price: 159.99, currency: "USD" },
          { store: "JD Sports", url: JD_URL, price: 119.99, currency: "GBP" },
        ],
      },
    },
    pages: {
      // No price on the page, and the search only saw dollars.
      [NIKE_URL]: { price: null, currency: "GBP", title: "Nike" },
      // The page shows dollars, so the search's pounds aren't used instead.
      [JD_URL]: { price: 114.99, currency: "USD", title: "JD" },
    },
  });
  const { deps } = makeDeps({ offers });
  const res = await handleIdentify(
    post({ offersToken: await signTicket(offers.ticketKey, ticketFor()), currency: "GBP" }, null),
    deps,
  );
  assertEquals((await res.json()).offers, []);
  assertEquals(rec.finishes[0].outcome, "none");
});

Deno.test("a page that can't be read keeps the search's price, after the checked ones", async () => {
  const { offers, rec } = await makeOffers({
    pages: { ...defaultPages, [JD_URL]: new Error("blocked") },
  });
  const { deps } = makeDeps({ offers });
  const res = await handleIdentify(
    post({ offersToken: await signTicket(offers.ticketKey, ticketFor()), currency: "GBP" }, null),
    deps,
  );
  const body = await res.json();
  assertEquals(body.offers, [
    {
      store: "Nike",
      url: NIKE_URL,
      title: "Nike Air Max 90 Shoes",
      price: 129.99,
      currency: "GBP",
      checked: true,
      best: true,
    },
    // Lower, but only the search saw it, so Nike's checked price is the one to start with.
    { store: "JD Sports", url: JD_URL, title: null, price: 119.99, currency: "GBP", checked: false, best: false },
  ]);
  assertEquals(rec.finishes[0].found, 2);
});

Deno.test("shop search reports not_configured when it isn't set up", async () => {
  const { offers } = await makeOffers();
  const token = await signTicket(offers.ticketKey, ticketFor());
  for (const { deps } of [makeDeps(), makeDeps({ offers, apiKeyConfigured: false })]) {
    const res = await handleIdentify(post({ offersToken: token }, null), deps);
    assertEquals(res.status, 503);
    assertEquals((await res.json()).code, "not_configured");
  }
});
