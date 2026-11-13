# Snap to Add — V0

Photograph or screenshot something you want; Gimme recognises it and fills in the wish.

| | |
|---|---|
| Status | Built, tested, backend deployed (Nov 13, 2026), including the signed-out free try. **Live only after `ANTHROPIC_API_KEY` is set**; the free try also needs the DeviceCheck secrets. See [Go-live checklist](#go-live-checklist). Not in an App Store build yet. |
| Branch | `claude/snap-to-add-v0-spec` |
| Out of scope (V1+) | Shopping results and price comparison, affiliate links, barcode scanning |

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

**Signed out: one free try per device** — the card says "Your first one is free, no account needed", so someone can see the feature work before creating an account. The result adds a row "That was your free try · Sign in to keep going, with 5 free a month · **Sign In**". After that the card reads as normal and picking a photo shows "Sign in to identify photos" without sending anything. Apple DeviceCheck remembers the spent try on Apple's side, so it survives deleting and reinstalling the app, and Gimme never learns who the device belongs to. A failed call gives the try back; a refusal or "not a product" uses it. Devices without DeviceCheck (the Simulator) just get the sign-in prompt.

**First run (Add Your First Wish)** — the same card and flow, so a brand-new user's very first wish can start from a photo. Both forms share `IdentifyController`, and consent given in one carries over to the other.

**From other apps** — the Share Extension now accepts images (Photos, screenshots, Safari images). A web link still wins when both are shared. Gimme picks the photo up on next open → list picker → New Wish with the photo, identified automatically (consent sheet first if not granted). Shares older than 24 h are dropped.

**Settings → Preferences → Identify from Photos** — the consent switch (off = never send photos).

**Paywall** — new page: "Snap to Add · Identify up to 100 items a month from photos — free plan includes 5."

## Architecture

```
iOS (AddItemView / FirstItemView / Share Extension → HomeView hand-off)
  └─ LiveProductIdentificationService
       POST /functions/v1/identify-product   (JPEG ≤ 1200 px, base64)
         signed in:  Authorization: Bearer <access token>
         ├─ auth.getUser(token)                       → user
         ├─ profiles.is_pro                           → monthly limit (5 free / 100 Pro)
         ├─ rpc claim_identify_slot(...)              → 429 quota / 503 global cap
         signed out: { deviceToken, deviceCheckEnvironment } from DCDevice
         ├─ DeviceCheck query_two_bits (bit0)         → 401 trial_used
         ├─ rpc claim_identify_trial_slot(...)        → 503 busy (trial cap / in flight / global cap)
         ├─ DeviceCheck update_two_bits (bit0 = 1)    → spend the try before calling the model
         both:
         ├─ Claude (claude-opus-5-5, effort low, JSON schema output, server-side refusal fallback)
         └─ ai_identify_requests.update(outcome, tokens, latency)   (+ bit0 = 0 again if the call failed)
```

Photos are never stored by the function and no user identity is sent to Anthropic. Free-try rows have no user and `is_trial = true`; the device token is used only to talk to Apple and is never stored.

## API contract

`POST /functions/v1/identify-product` — `Authorization: Bearer <user access token>`, or no `Authorization` and a DeviceCheck token in the body for the signed-out free try (Debug builds send `"development"`, others `"production"`):

```json
{ "image": "<base64 JPEG/PNG/WebP/GIF, data: URL ok>", "mediaType": "image/jpeg", "currency": "GBP",
  "deviceToken": "<DCDevice token, signed out only>", "deviceCheckEnvironment": "production" }
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

A free try returns `{ "result": …, "trial": true }` instead of `usage`.

Errors are `{ "code", "error", "usage"? }`:

| HTTP | code | Uses the quota / free try |
|---|---|---|
| 401 | `unauthorized` (no valid token; signed out without a device token Apple accepts, or DeviceCheck not configured) | — |
| 401 | `trial_used` (this device has had its free try) | — |
| 400 | `bad_request` | — |
| 413 | `image_too_large` (> 4 MB decoded) | — |
| 429 | `quota_exceeded` (+ usage) | — |
| 503 | `busy` (global 24 h cap; for free tries also the free-try 24 h cap or 3 already running) / `not_configured` (no API key) | — |
| 422 | `refused` (model declined after fallback) | yes |
| 502 | `upstream_error` (model/network/unreadable output, or DeviceCheck unreachable) | no — row marked `failed`, free try given back |
| 500 | `server_error` (quota check failed) | — |

`not_a_product` is a 200 and counts (the model call was paid for).

## Model, prompt and cost

- Model `claude-opus-5-5`, `effort: "low"`, `output_config.format` JSON schema, `fallbacks: "default"` (beta `server-side-fallback-2026-07-01`) so a classifier decline is retried server-side. Thinking can't be disabled on Opus 5.5; low effort keeps it short.
- Prompt and schema: `supabase/functions/identify-product/prompt.ts`. The model is told to prefer "similar" over guessing, never invent model numbers or sizes, pick the product a screenshot is about rather than the app, and treat text in images as data, not instructions.
- Tuning without redeploying (Supabase → Edge Functions → Secrets): `IDENTIFY_MODEL` (e.g. `claude-haiku-5-5` for ~20× cheaper calls — validate accuracy first), `IDENTIFY_EFFORT`, `IDENTIFY_FREE_MONTHLY_LIMIT` (5), `IDENTIFY_PRO_MONTHLY_LIMIT` (100), `IDENTIFY_GLOBAL_DAILY_LIMIT` (300). Keep the paywall copy in `PaywallView` in step with the limits.
- Cost estimate: ~1.5k image tokens + ~1k prompt/schema tokens in, a few hundred out → roughly **2¢ per photo** on Opus 5.5 ($4/$20 per MTok). The global cap bounds the worst day at ~300 calls (~$6–8). Real numbers: `select model, avg(input_tokens), avg(output_tokens), avg(latency_ms) from ai_identify_requests group by 1;`

### Model cost comparison (Nov 13, 2026 list prices; ~2.5k tokens in, ~400 out per photo)

| Model | $ / MTok in · out | Per photo | Per 1,000 photos | Switch cost |
|---|---|---|---|---|
| Claude Opus 5.5 (default) | 4 · 20 | ~1.8¢ | ~$18 | — |
| Claude Sonnet 5.5 | 2 · 10 | ~0.9¢ | ~$9 | `IDENTIFY_MODEL` secret |
| Claude Haiku 5.5 | 0.10 · 0.50 | ~0.05¢ | ~$0.45 | `IDENTIFY_MODEL` secret |
| Gemini 3.6 Flash | 1.50 · 7.50 | ~0.7¢ | ~$7 | new integration + privacy copy |
| Gemini 3.5 Flash-Lite | 0.30 · 2.50 | ~0.2¢ | ~$1.75 | new integration + privacy copy |
| Gemini 3.1 Flash-Lite | 0.25 · 1.50 | ~0.1¢ | ~$1.25 | new integration + privacy copy |

Estimates only: providers count image tokens differently and thinking adds output. Claude Haiku 5.5 is the cheapest option and needs no code change; moving to Gemini would mean a second API integration and naming Google in the consent screen and privacy policy. Decide on accuracy first: run the same real photos through Opus 5.5 and Haiku 5.5 (switch the secret, no redeploy) and keep the cheapest one that gets them right.

## Quotas

`claim_identify_slot(user, monthly_limit, global_daily_limit)` takes a per-user advisory lock, counts this calendar month's non-failed requests (UTC), checks the rolling 24 h global count, then inserts a `pending` row. The function marks it `ok`, `not_product`, `refused` or `failed`; `failed` rows stop counting against the user's month, so outages don't burn allowance. Only `service_role` can execute it (same hygiene as v8).

`claim_identify_trial_slot(trial_daily_limit, global_daily_limit)` (v11) does the same for free tries under one shared lock: it refuses while **3 free tries are already running** (pending rows under 3 minutes old), then applies the free-try 24 h cap (`IDENTIFY_TRIAL_DAILY_LIMIT`, default 100) and the global cap, and inserts a `pending` row with no user. The in-flight limit is there because DeviceCheck has no atomic test-and-set: a burst of parallel requests carrying one device's token could all read "unused" before the first marks it spent. The limit caps such a burst at 3 tries per device instead of the whole day's allowance.

Both 24 h caps also count `failed` rows that have output tokens, i.e. calls the model ran and billed but whose output was unusable, so those can't run past the budget. Before v11 the global cap ignored them. The caps are soft under concurrency (different users don't share a lock), which overshoots by at most a few requests.

## Privacy and App Review

- **Consent** — explicit, before the first photo leaves the device; names Anthropic; revocable in Settings (`@AppStorage("photoIdentifyConsent")`).
- **Privacy manifest** — added `NSPrivacyCollectedDataTypePhotosorVideos` (linked, app functionality, no tracking). Item photos were already uploaded to storage.
- **App Store Connect → App Privacy** — add *Photos or Videos · App Functionality · Linked to the user · Not used for tracking* before submitting.
- **Privacy policy (gimmelist.com/privacy)** — add:
  > *Photo identification.* If you choose to identify an item from a photo, Gimme sends that photo to its server, which passes it to Anthropic's Claude API to recognise the product. The photo isn't stored for this purpose and your name and email aren't sent with it; Gimme keeps only a record that a request happened (time and outcome) to apply monthly limits. If you aren't signed in, Gimme uses Apple's DeviceCheck service to remember that your device has used its one free identification; this doesn't tell Gimme who you are. You can turn this off in Settings → Identify from Photos.
- **DeviceCheck** — no new data type to declare: Gimme stores no device identifier, and the two bits live with Apple. No privacy manifest change.
- **Review notes** — mention the consent screen; that a signed-out device gets one free identification (Apple DeviceCheck) and then needs an account; and that the debug mock (`-mockIdentify`) is compiled out of Release builds.

## Files

| Area | Files |
|---|---|
| Backend | `supabase/functions/identify-product/{index,handler,prompt,devicecheck}.ts`, `migration_v9_identify_requests.sql`, `migration_v11_identify_trials.sql` (v10 is the Pro fix from PR #6), `supabase/config.toml` |
| iOS service | `Whish/Services/ProductIdentificationService.swift` (model, live service, response decoder, prefill rules, debug mock) |
| Hand-off | `Whish/Services/SharedImageInbox.swift` (compiled into app + GimmeShare), `GimmeShare/ShareViewController.swift`, `project.yml` activation rule |
| UI | `Whish/Features/ListDetail/IdentifyController.swift` (shared flow: sign-in gate, consent, request, stale results), `IdentifyPhotoCard.swift` (card + consent sheet), `AddItemView.swift`, `HomeView.swift` (share hand-off + `FirstItemView`), `SettingsView.swift`, `PaywallView.swift` |
| Privacy | `Whish/PrivacyInfo.xcprivacy` |
| Tests | `supabase/functions/identify-product/{handler,devicecheck}_test.ts`, `supabase/tests/migration_v{9,11}_test.ts`, `WhishTests/ProductIdentificationTests.swift` |

## Testing

```bash
deno test --node-modules-dir=none -A supabase/functions/identify-product/ supabase/tests/
```

```bash
xcodebuild -project Whish.xcodeproj -scheme Gimme -destination 'platform=iOS Simulator,name=iPhone 17' test
```

(`--node-modules-dir=none` stops Deno picking up the `package.json` in your home folder.)

- **Edge Function (36)** — auth, validation, size limit, quota and global cap, Pro limit, refusal, failed-call refund, unreadable output, result normalisation. Free try: one per device, given back on failure, spent by a refusal, busy at the caps, Apple rejecting the token vs Apple being down, the try can't be recorded, development tokens, signed-in users never take this path. DeviceCheck client: the ES256 JWT verifies against a generated P-256 key, a `.p8` pasted with literal `\n`, bit parsing, development host only when allowed, 10 s timeout.
- **Migration (16)**, on in-process Postgres (PGlite) — v9: re-runnable, monthly counting, failed refund, month rollover, global cap, execute privileges, RLS. v11: re-runnable over v9, free-try cap, unbilled failures don't count but billed ones do, 3 running at once, abandoned tries stop blocking, shared global cap, every row is a user's or a free try, execute privileges.
- **iOS (26 new, 62 total)** — response decoding and every error code, prefill never overwriting typed text, estimate midpoint and locale formatting, shopping URL, share hand-off (once-only, stale drop, link vs photo precedence), memory-safe downscale, the shared controller (sign-in gate, consent then run, quota usage, dropping a replaced photo's result), and the free try (offered signed out, "That was your free try" afterwards, a spent try asks to sign in without a request, a refusal spends it).
- **Simulator walkthrough** with `-mockIdentify identified|similar|not_product|quota|offline|trial|trial_used` (Debug only): card → source menu → library → consent → result → Use price → save, on both New Wish and the first-run screen (fresh install); signed out on the first-run screen: "Your first one is free" → result + "That was your free try" → the next photo asks to sign in; Photos → Share → Gimme → list → auto-identify; quota → paywall; Settings switch.
- **Production smoke test**: 405 / 401 for wrong method, missing, publishable-key and forged tokens, and for a device token while DeviceCheck isn't configured. v11's claim functions run inside rolled-back transactions (each cap, 3 running at once, billed failures counted); only `service_role` can execute them; no rows left behind; the deployed function source is byte-identical to the repo; no new advisor findings.
- **Not yet tested**: a real Claude call (needs the API key), a signed-in request against production (needs an account), and real DeviceCheck (needs the key and a physical iPhone; the Simulator doesn't support DeviceCheck). These are items 2 and 4 of the checklist below.

## Go-live checklist

1. Set the key (Anthropic Console → API keys; set a monthly spend limit there too):

   ```bash
   supabase secrets set ANTHROPIC_API_KEY=<key> --project-ref dyporggvmfyzejopaezc
   ```

2. In a Debug build signed in to your account, identify 10–20 real photos and screenshots (branded, generic, not-a-product, blurry). Check `ai_identify_requests` for tokens and latency; if accuracy holds, consider `IDENTIFY_MODEL=claude-haiku-5-5`.
3. Turn on the free try. In Apple Developer → Certificates, IDs & Profiles → Keys, create a key with **DeviceCheck** enabled and download the `.p8` (Apple lets you download it once). Your Team ID is under Membership.

   ```bash
   supabase secrets set DEVICECHECK_KEY_ID=<key id> APPLE_TEAM_ID=<team id> --project-ref dyporggvmfyzejopaezc
   ```

   ```bash
   supabase secrets set DEVICECHECK_PRIVATE_KEY="$(cat AuthKey_<key id>.p8)" --project-ref dyporggvmfyzejopaezc
   ```

   Without these, signed-out users who tap the card are asked to sign in. So set them before shipping a build that shows "Your first one is free".
4. On a physical iPhone, test the free try. A Debug build from Xcode sends development tokens, so for that test also set `DEVICECHECK_ALLOW_DEVELOPMENT=true`, and remove it afterwards; TestFlight and App Store builds don't need it. Sign out, identify one photo, check that the next one asks you to sign in, then delete and reinstall the app and check that the try is still spent.
5. Update the privacy policy and App Store privacy answers (above).
6. Ship this in the same build as the Pro fix (PR #6), or in a later one. Since migration v10, an account becomes Pro only through verify-purchase, and only PR #6's app build calls it. In a build without it, people who buy Pro get Pro on their device but not on their account, so they get the free 5 photos a month, not 100. Merging this branch after PR #6 conflicts in two files where both branches added entries side by side: in `supabase/config.toml` keep both function sections, and in `Whish.xcodeproj/project.pbxproj` keep both sides or run `xcodegen generate`.
7. Merge the branch, bump the version, TestFlight, then ship with a "Snap to add" screenshot.

## Also fixed on this branch

- **Adding a wish bounced back to Home after the first wish.** The first-wish screen (and Add Item, when it moves an item to another list) navigated using the new list's temporary SwiftData ID. The next autosave, such as the one triggered when the photo picker opens, replaced that ID, the list-detail lookup failed, and navigation reset to Home. Both forms now save before navigating. Checked in the Simulator: first wish → list → New Wish → photo → identify → save stays in the list.

## Follow-ups

- **Pro could be self-granted (pre-existing, security): closed in production on Nov 13, 2026.** `profiles` RLS let a signed-in user update their own `is_pro`, which `WhishApp` turns into Pro and identify-product into the 100-a-month limit. Migration v10 sections 1–3 and the verify-purchase Edge Function from PR #6 (`claude/verify-purchase`) are now live, so clients can't write `profiles` and only `record_pro_transaction()` sets `is_pro`. Checked in production: no client write privilege or policy on `profiles`. Still open: PR #6 isn't merged or shipped (checklist item 6), and v10 section 4, which clears `is_pro` on accounts without a verified purchase, is on hold, so the 3 existing Pro accounts keep Pro for now.
- **Free try: replayed tokens.** Someone who captures their own request can replay its DeviceCheck token; the in-flight limit holds a burst to 3 tries and the free-try daily cap bounds the rest. If abuse ever shows up in `ai_identify_requests`, move the free try to App Attest, which proves each request comes from the genuine app.
- V1: shopping results → pick an offer → existing metadata + price tracking. V2: multi-store price comparison, affiliate links, VisionKit barcode scan.
