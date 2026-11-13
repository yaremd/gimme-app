// identify-product: identifies the product in a photo so Gimme can pre-fill a wish.
//
// POST { image: <base64>, mediaType?: "image/jpeg", currency?: "USD" }
// Auth: the signed-in user's access token (Authorization: Bearer <jwt>).
// Returns { result, usage } or { code, error, usage? }. Photos are never stored;
// only a per-request usage row (status, model, token counts) is kept for quotas.
//
// Secrets: ANTHROPIC_API_KEY (required). Optional tuning, no redeploy needed:
// IDENTIFY_MODEL, IDENTIFY_EFFORT, IDENTIFY_FREE_MONTHLY_LIMIT,
// IDENTIFY_PRO_MONTHLY_LIMIT, IDENTIFY_GLOBAL_DAILY_LIMIT.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk@1.3.0";
import { handleIdentify, type Deps } from "./handler.ts";
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
    const row = data as { allowed: boolean; request_id: string | null; used: number; reason: string };
    return {
      allowed: row.allowed,
      requestId: row.request_id,
      used: row.used,
      reason: row.reason === "global_limit" ? "global_limit" : row.reason === "monthly_limit" ? "monthly_limit" : "ok",
    };
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

  config: {
    apiKeyConfigured: apiKey.length > 0,
    freeMonthlyLimit: intEnv("IDENTIFY_FREE_MONTHLY_LIMIT", 5),
    proMonthlyLimit: intEnv("IDENTIFY_PRO_MONTHLY_LIMIT", 100),
    globalDailyLimit: intEnv("IDENTIFY_GLOBAL_DAILY_LIMIT", 300),
    maxImageBytes: 4 * 1024 * 1024,
  },

  now: () => new Date(),
};

Deno.serve((req) => handleIdentify(req, deps));
