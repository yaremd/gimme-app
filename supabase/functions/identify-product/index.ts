// identify-product: identifies the product in a photo so Gimme can pre-fill a wish.
//
// POST { image: <base64>, mediaType?: "image/jpeg", currency?: "USD" }
// Auth: the signed-in user's access token (Authorization: Bearer <jwt>), or, for a
// signed-out device's one free try, { deviceToken, deviceCheckEnvironment } in the body.
// Returns { result, usage } (signed in), { result, trial: true } (free try) or
// { code, error, usage? }. Photos are never stored; only a per-request usage row
// (status, model, token counts) is kept for quotas.
//
// Secrets: ANTHROPIC_API_KEY (required). Optional tuning, no redeploy needed:
// IDENTIFY_MODEL, IDENTIFY_EFFORT, IDENTIFY_FREE_MONTHLY_LIMIT,
// IDENTIFY_PRO_MONTHLY_LIMIT, IDENTIFY_TRIAL_DAILY_LIMIT, IDENTIFY_GLOBAL_DAILY_LIMIT.
//
// Signed-out free try (one per device) needs Apple DeviceCheck: DEVICECHECK_KEY_ID,
// DEVICECHECK_PRIVATE_KEY (.p8 contents), APPLE_TEAM_ID. Set
// DEVICECHECK_ALLOW_DEVELOPMENT=true while testing Debug builds from Xcode.
// Without them, signed-out users are simply asked to sign in.
//
// Shop search (POST { offersToken, country?, currency? } -> { offers }): a web search
// for shops selling an identified product, each price confirmed with the
// fetch-metadata function. Optional tuning: OFFERS_MODEL, OFFERS_EFFORT,
// OFFERS_MAX_SEARCHES. Tickets are signed with a key derived from
// OFFERS_TICKET_SECRET, or from the service role key when that isn't set.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk@1.3.0";
import { createDeviceCheckClient } from "./devicecheck.ts";
import { handleIdentify, type Deps, type OffersDeps } from "./handler.ts";
import { makeTicketKey, OFFERS_SYSTEM_PROMPT, REPORT_OFFERS_TOOL, UnsupportedCountry } from "./offers.ts";
import { IDENTIFY_SCHEMA, IDENTIFY_SYSTEM_PROMPT } from "./prompt.ts";

function intEnv(name: string, fallback: number): number {
  const value = Number.parseInt(Deno.env.get(name) ?? "", 10);
  return Number.isFinite(value) && value >= 0 ? value : fallback;
}

const apiKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const model = Deno.env.get("IDENTIFY_MODEL") || "claude-opus-5-5";
const effortSetting = Deno.env.get("IDENTIFY_EFFORT") ?? "";
const effort = (["low", "medium", "high", "xhigh", "max"].includes(effortSetting) ? effortSetting : "low") as
  "low" | "medium" | "high" | "xhigh" | "max";
// Server-side refusal fallbacks exist for the Opus 5.x, Sonnet 5.5 and Fable 5.x lines, not Haiku.
const supportsFallbacks = /^claude-(opus-5|sonnet-5-5|fable-5)/.test(model);

const admin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  { auth: { persistSession: false, autoRefreshToken: false } },
);

const anthropic = apiKey ? new Anthropic({ apiKey, timeout: 45_000, maxRetries: 1 }) : null;

const deviceCheckKeyId = Deno.env.get("DEVICECHECK_KEY_ID") ?? "";
const deviceCheckKey = Deno.env.get("DEVICECHECK_PRIVATE_KEY") ?? "";
const appleTeamId = Deno.env.get("APPLE_TEAM_ID") ?? "";
const deviceCheck = deviceCheckKeyId && deviceCheckKey && appleTeamId
  ? createDeviceCheckClient({
    keyId: deviceCheckKeyId,
    teamId: appleTeamId,
    privateKeyPem: deviceCheckKey,
    allowDevelopment: Deno.env.get("DEVICECHECK_ALLOW_DEVELOPMENT") === "true",
  })
  : undefined;

// MARK: - Shop search

const offersModel = Deno.env.get("OFFERS_MODEL") || "claude-opus-5-5";
const offersEffortSetting = Deno.env.get("OFFERS_EFFORT") ?? "";
const offersEffort = (["low", "medium", "high", "xhigh", "max"].includes(offersEffortSetting)
  ? offersEffortSetting
  : "low") as "low" | "medium" | "high" | "xhigh" | "max";
const offersMaxSearches = Math.max(1, intEnv("OFFERS_MAX_SEARCHES", 3));
const offersSupportsFallbacks = /^claude-(opus-5|sonnet-5-5|fable-5)/.test(offersModel);
/** Set once the model turns down web search from code (dynamic filtering); see callModel. */
let searchDirectly = false;
// No retries: a retried request can run (and bill) its web searches twice. Two
// requests of 45 s at most keep the whole search inside the 150 s request limit.
const offersAnthropic = apiKey ? new Anthropic({ apiKey, timeout: 45_000, maxRetries: 0 }) : null;

const supabaseURL = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const ticketSecret = Deno.env.get("OFFERS_TICKET_SECRET") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const ticketKey = ticketSecret ? await makeTicketKey(ticketSecret) : null;

const offers: OffersDeps | undefined = ticketKey && supabaseURL && anonKey
  ? {
    ticketKey,

    async claim(requestId) {
      const { data, error } = await admin
        .from("ai_identify_requests")
        .update({ offers_status: "pending" })
        .eq("id", requestId)
        .is("offers_status", null)
        .eq("status", "ok")
        .eq("result_status", "identified")
        .select("id");
      if (error) throw error;
      return (data ?? []).length > 0;
    },

    async release(requestId) {
      const { error } = await admin
        .from("ai_identify_requests")
        .update({ offers_status: null })
        .eq("id", requestId)
        .eq("offers_status", "pending");
      if (error) throw error;
    },

    async finish(requestId, outcome, details) {
      const { error } = await admin
        .from("ai_identify_requests")
        .update({
          offers_status: outcome,
          offers_model: details.model ?? null,
          offers_input_tokens: details.inputTokens ?? null,
          offers_output_tokens: details.outputTokens ?? null,
          offers_searches: details.searches ?? null,
          offers_found: details.found,
          offers_latency_ms: details.latencyMs,
        })
        .eq("id", requestId);
      if (error) throw error;
    },

    async callModel({ userText, country }) {
      if (!offersAnthropic) throw new Error("ANTHROPIC_API_KEY is not set");
      const tools = () => [
        {
          type: "web_search_20260318" as const,
          name: "web_search" as const,
          max_uses: offersMaxSearches,
          // With dynamic filtering the model reads results through code, so the raw pages
          // aren't needed in the response. Models without it call the search directly.
          ...(searchDirectly
            ? { allowed_callers: ["direct" as const] }
            : { response_inclusion: "excluded" as const }),
          ...(country ? { user_location: { type: "approximate" as const, country } } : {}),
        },
        REPORT_OFFERS_TOOL,
      ];
      const messages: Anthropic.Beta.Messages.BetaMessageParam[] = [{ role: "user", content: userText }];
      let inputTokens = 0;
      let outputTokens = 0;
      let searches = 0;
      let servedBy = offersModel;

      // A long search can pause (stop_reason "pause_turn"); continue it once, then give up.
      for (let request = 0; request < 2; request++) {
        let response;
        try {
          response = await offersAnthropic.beta.messages.create({
            model: offersModel,
            max_tokens: 8000,
            ...(offersSupportsFallbacks
              ? { betas: ["server-side-fallback-2026-07-01"], fallbacks: "default" as const }
              : {}),
            system: OFFERS_SYSTEM_PROMPT,
            output_config: { effort: offersEffort },
            tools: tools(),
            messages,
          });
        } catch (error) {
          if (error instanceof Anthropic.BadRequestError) {
            // e.g. 400 "tools.0.web_search_20260318: Country code UA is not supported."
            if (country && /country code/i.test(error.message)) throw new UnsupportedCountry(country);
            // A model that can't run web search from code (dynamic filtering) asks for
            // allowed_callers ["direct"]: remember that for this worker and send the request again.
            if (!searchDirectly && /allowed_callers/i.test(error.message)) {
              searchDirectly = true;
              request--;
              continue;
            }
          }
          throw error;
        }
        inputTokens += response.usage.input_tokens;
        outputTokens += response.usage.output_tokens;
        searches += response.usage.server_tool_use?.web_search_requests ?? 0;
        servedBy = response.model;

        for (const block of response.content) {
          if (block.type === "tool_use" && block.name === REPORT_OFFERS_TOOL.name) {
            return { stopReason: response.stop_reason, report: block.input, model: servedBy, inputTokens, outputTokens, searches };
          }
        }
        if (response.stop_reason !== "pause_turn") {
          return { stopReason: response.stop_reason, report: null, model: servedBy, inputTokens, outputTokens, searches };
        }
        messages.push({
          role: "assistant",
          content: response.content as unknown as Anthropic.Beta.Messages.BetaContentBlockParam[],
        });
      }
      return { stopReason: "pause_turn", report: null, model: servedBy, inputTokens, outputTokens, searches };
    },

    async checkPage(url) {
      // The same reader the app uses for pasted links and price tracking.
      const response = await fetch(`${supabaseURL}/functions/v1/fetch-metadata`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${anonKey}`, apikey: anonKey },
        body: JSON.stringify({ url }),
        signal: AbortSignal.timeout(15_000),
      });
      if (!response.ok) {
        await response.body?.cancel();
        return null;
      }
      const data = await response.json() as Record<string, unknown>;
      const price = typeof data.price === "string"
        ? Number.parseFloat(data.price)
        : typeof data.price === "number"
        ? data.price
        : Number.NaN;
      return {
        price: Number.isFinite(price) && price > 0 ? price : null,
        currency: typeof data.currency === "string" ? data.currency : null,
        title: typeof data.title === "string" ? data.title : null,
      };
    },
  }
  : undefined;

type ClaimRow = { allowed: boolean; request_id: string | null; used: number; reason: string };

function toClaim(row: ClaimRow) {
  const reasons = ["ok", "monthly_limit", "trial_limit", "in_flight", "global_limit"] as const;
  const reason = reasons.find((r) => r === row.reason) ?? "global_limit";
  return { allowed: row.allowed, requestId: row.request_id, used: row.used, reason };
}

const deps: Deps = {
  async getUserId(accessToken) {
    const { data, error } = await admin.auth.getUser(accessToken);
    return error || !data.user ? null : data.user.id;
  },

  async isPro(userId) {
    const { data, error } = await admin.from("profiles").select("is_pro").eq("id", userId).maybeSingle();
    if (error) throw error;
    return data?.is_pro === true;
  },

  async claimSlot(userId, monthlyLimit, globalDailyLimit) {
    const { data, error } = await admin
      .rpc("claim_identify_slot", {
        p_user_id: userId,
        p_monthly_limit: monthlyLimit,
        p_global_daily_limit: globalDailyLimit,
      })
      .single();
    if (error) throw error;
    return toClaim(data as ClaimRow);
  },

  async claimTrialSlot(trialDailyLimit, globalDailyLimit) {
    const { data, error } = await admin
      .rpc("claim_identify_trial_slot", {
        p_trial_daily_limit: trialDailyLimit,
        p_global_daily_limit: globalDailyLimit,
      })
      .single();
    if (error) throw error;
    return toClaim(data as ClaimRow);
  },

  async finishRequest(requestId, outcome, details) {
    const { error } = await admin
      .from("ai_identify_requests")
      .update({
        status: outcome,
        result_status: details.resultStatus ?? null,
        model: details.model ?? null,
        input_tokens: details.inputTokens ?? null,
        output_tokens: details.outputTokens ?? null,
        latency_ms: details.latencyMs,
      })
      .eq("id", requestId);
    if (error) throw error;
  },

  async callModel({ imageBase64, mediaType, userText }) {
    if (!anthropic) throw new Error("ANTHROPIC_API_KEY is not set");
    const response = await anthropic.beta.messages.create({
      model,
      max_tokens: 16000,
      ...(supportsFallbacks
        ? { betas: ["server-side-fallback-2026-07-01"], fallbacks: "default" as const }
        : {}),
      system: IDENTIFY_SYSTEM_PROMPT,
      output_config: {
        effort,
        format: { type: "json_schema", schema: IDENTIFY_SCHEMA as unknown as Record<string, unknown> },
      },
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: mediaType as "image/jpeg" | "image/png" | "image/webp" | "image/gif",
                data: imageBase64,
              },
            },
            { type: "text", text: userText },
          ],
        },
      ],
    });

    let text: string | null = null;
    for (const block of response.content) {
      if (block.type === "text") {
        text = block.text;
        break;
      }
    }
    return {
      stopReason: response.stop_reason,
      text,
      model: response.model,
      inputTokens: response.usage.input_tokens,
      outputTokens: response.usage.output_tokens,
    };
  },

  deviceCheck,

  offers,

  config: {
    apiKeyConfigured: apiKey.length > 0,
    freeMonthlyLimit: intEnv("IDENTIFY_FREE_MONTHLY_LIMIT", 5),
    proMonthlyLimit: intEnv("IDENTIFY_PRO_MONTHLY_LIMIT", 100),
    trialDailyLimit: intEnv("IDENTIFY_TRIAL_DAILY_LIMIT", 100),
    globalDailyLimit: intEnv("IDENTIFY_GLOBAL_DAILY_LIMIT", 300),
    maxImageBytes: 4 * 1024 * 1024,
  },

  now: () => new Date(),
};

Deno.serve((req) => handleIdentify(req, deps));
