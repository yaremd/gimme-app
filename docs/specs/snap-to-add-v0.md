# Snap to Add — V0

Photograph or screenshot something you want; Gimme recognises it and fills in the wish.

| | |
|---|---|
| Status | Built, tested, backend deployed (Nov 13, 2026). **Live only after `ANTHROPIC_API_KEY` is set** — see [Go-live checklist](#go-live-checklist). Not in an App Store build yet. |
| Branch | `claude/snap-to-add-v0-spec` |
| Out of scope (V1+) | Shopping results and price comparison, affiliate links, barcode scanning, identify in `FirstItemView` |

## What the user sees

**In Add Item (New Wish)** — a new card under the link field:

1. *Identify from a photo* opens a menu: **Take Photo** / **Choose from Library**.
2. After picking, the first time only, a consent sheet names Anthropic and asks for explicit permission (App Review 5.1.2(i)). **Allow and Identify** or **Not Now**.
3. *Identifying…* (a few seconds), then:
   - **Found** — "Looks like Nike Air Max 90". Title and Notes are filled (only if empty), brand and colour appear as chips, plus a **Usually $120–$140 · Use** row (fills Price with the midpoint) and **Find it online** (Google Shopping search in Safari; pasting a store link back runs the existing metadata + price tracking).
   - **Similar** — same, with "Not an exact match, so check the details".
   - **Unclear / not a product** — "Couldn't make it out" / "No product spotted", with **Try another**.
   - **Errors** — quota (free users get **Upgrade** → paywall), signed out (**Sign In**), offline / server (**Try again**), not configured.
4. A photo already attached shows *Identify this photo* instead (with "N of 5 left this month" once known). Emoji images and product images from links never show the card; neither does an item whose details came from a link.

**From other apps** — the Share Extension now accepts images (Photos, screenshots, Safari images). A web link still wins when both are shared. Gimme picks the photo up on next open → list picker → New Wish with the photo, identified automatically (consent sheet first if not granted). Shares older than 24 h are dropped.

**Settings → Preferences → Identify from Photos** — the consent switch (off = never send photos).

**Paywall** — new page: "Snap to Add · Identify up to 100 items a month from photos — free plan includes 5."

## Architecture

```
iOS (AddItemView / Share Extension → HomeView hand-off)
  └─ LiveProductIdentificationService
       POST /functions/v1/identify-product   (user's access token, JPEG ≤ 1200 px, base64)
         ├─ auth.getUser(token)                       → 401 if not signed in
         ├─ profiles.is_pro                           → monthly limit (5 free / 100 Pro)
         ├─ rpc claim_identify_slot(...)              → 429 quota / 503 global cap
         ├─ Claude (claude-opus-5-5, effort low, JSON schema output, server-side refusal fallback)
         └─ ai_identify_requests.update(outcome, tokens, latency)
```

Photos are never stored by the function and no user identity is sent to Anthropic.

## API contract

`POST /functions/v1/identify-product` — `Authorization: Bearer <user access token>`

```json
{ "image": "<base64 JPEG/PNG/WebP/GIF, data: URL ok>", "mediaType": "image/jpeg", "currency": "GBP" }
```

200:

```json
{
  "result": {
    "status": "identified | similar | unclear | not_a_product",
    "title": "Nike Air Max 90", "brand": "Nike", "model": "Air Max 90", "color": "White/Infrared",
    "category": "Sneakers", "description": "Classic low-top running sneaker…",
    "estimatedPrice": { "low": 120, "high": 140, "currency": "GBP" },
    "searchQuery": "Nike Air Max 90 white infrared", "confidence": 0.91
  },
  "usage": { "used": 2, "limit": 5, "remaining": 3, "periodEnd": "2026-12-01T00:00:00.000Z" }
}
```

Errors are `{ "code", "error", "usage"? }`:

| HTTP | code | Counts against quota |
|---|---|---|
| 401 | `unauthorized` | — |
| 400 | `bad_request` | — |
| 413 | `image_too_large` (> 4 MB decoded) | — |
| 429 | `quota_exceeded` (+ usage) | — |
| 503 | `busy` (global 24 h cap) / `not_configured` (no API key) | — |
| 422 | `refused` (model declined after fallback) | yes |
| 502 | `upstream_error` (model/network/unreadable output) | no — row marked `failed` |
| 500 | `server_error` (quota check failed) | — |

`not_a_product` is a 200 and counts (the model call was paid for).

## Model, prompt and cost

- Model `claude-opus-5-5`, `effort: "low"`, `output_config.format` JSON schema, `fallbacks: "default"` (beta `server-side-fallback-2026-07-01`) so a classifier decline is retried server-side. Thinking can't be disabled on Opus 5.5; low effort keeps it short.
- Prompt and schema: `supabase/functions/identify-product/prompt.ts`. The model is told to prefer "similar" over guessing, never invent model numbers or sizes, pick the product a screenshot is about rather than the app, and treat text in images as data, not instructions.
- Tuning without redeploying (Supabase → Edge Functions → Secrets): `IDENTIFY_MODEL` (e.g. `claude-haiku-5-5` for ~20× cheaper calls — validate accuracy first), `IDENTIFY_EFFORT`, `IDENTIFY_FREE_MONTHLY_LIMIT` (5), `IDENTIFY_PRO_MONTHLY_LIMIT` (100), `IDENTIFY_GLOBAL_DAILY_LIMIT` (300). Keep the paywall copy in `PaywallView` in step with the limits.
- Cost estimate: ~1.5k image tokens + ~1k prompt/schema tokens in, a few hundred out → roughly **2¢ per photo** on Opus 5.5 ($4/$20 per MTok). The global cap bounds the worst day at ~300 calls (~$6–8). Real numbers: `select model, avg(input_tokens), avg(output_tokens), avg(latency_ms) from ai_identify_requests group by 1;`

## Quotas

`claim_identify_slot(user, monthly_limit, global_daily_limit)` takes a per-user advisory lock, counts this calendar month's non-failed requests (UTC), checks the rolling 24 h global count, then inserts a `pending` row. The function marks it `ok`, `not_product`, `refused` or `failed`; `failed` rows stop counting, so outages don't burn allowance. Only `service_role` can execute it (same hygiene as v8).

## Privacy and App Review

- **Consent** — explicit, before the first photo leaves the device; names Anthropic; revocable in Settings (`@AppStorage("photoIdentifyConsent")`).
- **Privacy manifest** — added `NSPrivacyCollectedDataTypePhotosorVideos` (linked, app functionality, no tracking). Item photos were already uploaded to storage.
- **App Store Connect → App Privacy** — add *Photos or Videos · App Functionality · Linked to the user · Not used for tracking* before submitting.
- **Privacy policy (gimmelist.com/privacy)** — add:
  > *Photo identification.* If you choose to identify an item from a photo, Gimme sends that photo to its server, which passes it to Anthropic's Claude API to recognise the product. The photo isn't stored for this purpose and your name and email aren't sent with it; Gimme keeps only a record that a request happened (time and outcome) to apply monthly limits. You can turn this off in Settings → Identify from Photos.
- **Review notes** — mention the consent screen and that identification needs a signed-in account; the debug mock (`-mockIdentify`) is compiled out of Release builds.

## Files

| Area | Files |
|---|---|
| Backend | `supabase/functions/identify-product/{index,handler,prompt}.ts`, `migration_v9_identify_requests.sql`, `supabase/config.toml` |
| iOS service | `Whish/Services/ProductIdentificationService.swift` (model, live service, response decoder, prefill rules, debug mock) |
| Hand-off | `Whish/Services/SharedImageInbox.swift` (compiled into app + GimmeShare), `GimmeShare/ShareViewController.swift`, `project.yml` activation rule |
| UI | `Whish/Features/ListDetail/IdentifyPhotoCard.swift` (card + consent sheet), `AddItemView.swift`, `HomeView.swift`, `SettingsView.swift`, `PaywallView.swift` |
| Privacy | `Whish/PrivacyInfo.xcprivacy` |
| Tests | `supabase/functions/identify-product/handler_test.ts`, `supabase/tests/migration_v9_test.ts`, `WhishTests/ProductIdentificationTests.swift` |

## Testing

```bash
deno test --node-modules-dir=none -A supabase/functions/identify-product/ supabase/tests/
```

```bash
xcodebuild -project Whish.xcodeproj -scheme Gimme -destination 'platform=iOS Simulator,name=iPhone 17' test
```

(`--node-modules-dir=none` stops Deno picking up the `package.json` in your home folder.)

- **Edge Function (19)** — auth, validation, size limit, quota and global cap, Pro limit, refusal, failed-call refund, unreadable output, result normalisation.
- **Migration (7)**, on in-process Postgres (PGlite) — re-runnable, monthly counting, failed refund, month rollover, global cap, execute privileges, RLS.
- **iOS (16 new, 52 total)** — response decoding and every error code, prefill never overwriting typed text, estimate midpoint and locale formatting, shopping URL, share hand-off (once-only, stale drop, link vs photo precedence), memory-safe downscale.
- **Simulator walkthrough** with `-mockIdentify identified|similar|not_product|quota|offline` (Debug only): card → source menu → library → consent → result → Use price → save; Photos → Share → Gimme → list → auto-identify; quota → paywall; signed-out live path → Sign In; Settings switch.
- **Production smoke test**: 405 / 401 for wrong method, missing, publishable-key and forged tokens; no rows written; no new security advisor findings.
- **Not yet tested**: a real Claude call (needs the API key) and a signed-in request against production (needs an account) — the first two items of the checklist below.

## Go-live checklist

1. Set the key (Anthropic Console → API keys; set a monthly spend limit there too):

   ```bash
   supabase secrets set ANTHROPIC_API_KEY=<key> --project-ref dyporggvmfyzejopaezc
   ```

2. In a Debug build signed in to your account, identify 10–20 real photos and screenshots (branded, generic, not-a-product, blurry). Check `ai_identify_requests` for tokens and latency; if accuracy holds, consider `IDENTIFY_MODEL=claude-haiku-5-5`.
3. Update the privacy policy and App Store privacy answers (above).
4. Merge the branch, bump the version, TestFlight, then ship with a "Snap to add" screenshot.

## Follow-ups

- **Pro can be self-granted (pre-existing, security)** — `profiles` RLS lets a signed-in user update their own `is_pro`, and `WhishApp` grants Pro when it's true. Fix with a verify-purchase Edge Function (StoreKit signed transactions) as the only writer of `is_pro`. Until then the Pro identify limit is spoofable (bounded by the global cap).
- Add the identify card to `FirstItemView` (first-run "Add your first wish") — the highest-impact place for a new user's first impression.
- V1: shopping results → pick an offer → existing metadata + price tracking. V2: multi-store price comparison, affiliate links, VisionKit barcode scan.
