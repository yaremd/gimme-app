# Snap to Add — V0

Photograph or screenshot something you want; Gimme recognises it and fills in the wish.

| | |
|---|---|
| Status | Built, tested, backend deployed (Nov 13, 2026), including the signed-out free try. `ANTHROPIC_API_KEY` was set on Nov 18, 2026; the free try still needs the DeviceCheck secrets. Shop search with a confirmed best price added Nov 18, 2026 (see [Shop search](#shop-search-best-price)). See [Go-live checklist](#go-live-checklist). Not in an App Store build yet. |
| Branch | `claude/snap-to-add-v0-spec` |
| Out of scope | Comparing every shop, affiliate links, barcode scanning |

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
- Tuning without redeploying (Supabase → Edge Functions → Secrets): `IDENTIFY_MODEL` (e.g. `claude-haiku-5-5` for ~40× cheaper calls — validate accuracy first), `IDENTIFY_EFFORT`, `IDENTIFY_FREE_MONTHLY_LIMIT` (5), `IDENTIFY_PRO_MONTHLY_LIMIT` (100), `IDENTIFY_GLOBAL_DAILY_LIMIT` (300). Keep the paywall copy in `PaywallView` in step with the limits.
- Measured cost (Nov 18, 2026, first 3 real photos): 6,052 tokens in and 173–184 out per photo, 3.3–4.2 s on the server, which comes to about **2.8¢ per photo** on Opus 5.5 ($4/$20 per MTok). The photo itself is only about 1.4k of the input tokens (1200 px on the long edge); the rest is the instructions and answer format sent with every call. The global cap bounds the worst day at ~300 calls (~$8.30). Current numbers: `select model, avg(input_tokens), avg(output_tokens), avg(latency_ms) from ai_identify_requests group by 1;`

### Model cost comparison (Nov 13, 2026 list prices; 6,052 tokens in, ~180 out per photo, as measured on Opus 5.5)

| Model | $ / MTok in · out | Per photo | Per 1,000 photos | Switch cost |
|---|---|---|---|---|
| Claude Opus 5.5 (default) | 4 · 20 | ~2.8¢ (measured) | ~$28 | — |
| Claude Sonnet 5.5 | 2 · 10 | ~1.4¢ | ~$14 | `IDENTIFY_MODEL` secret |
| Claude Haiku 5.5 | 0.10 · 0.50 | ~0.07¢ | ~$0.70 | `IDENTIFY_MODEL` secret |
| Gemini 3.6 Flash | 1.50 · 7.50 | ~1.0¢ | ~$10 | new integration + privacy copy |
| Gemini 3.5 Flash-Lite | 0.30 · 2.50 | ~0.23¢ | ~$2.30 | new integration + privacy copy |
| Gemini 3.1 Flash-Lite | 0.25 · 1.50 | ~0.18¢ | ~$1.80 | new integration + privacy copy |

Only the Opus row is measured. The others apply the same token counts to each price list, but every model counts tokens a little differently (Gemini more so), and thinking adds output. Claude Haiku 5.5 is the cheapest option and needs no code change; moving to Gemini would mean a second API integration and naming Google in the consent screen and privacy policy. Decide on accuracy first: run the same real photos through Opus 5.5 and Haiku 5.5 (switch the secret, no redeploy) and keep the cheapest one that gets them right.

## Shop search (best price)

Added Nov 18, 2026. When a photo is identified as a specific product, Gimme looks for shops selling it and puts the cheapest one in the wish.

**What the user sees.** Under the result, the card shows "Finding the best price… · Checking shops for this item". About 10–30 seconds later it becomes "£114.99 at JD Sports · Best price found, link added", with **Change** (the other offers, cheapest first) and an arrow that opens the shop. The form's link and price now hold that shop's link and the price read from its page, and saving the wish starts the existing price tracking on that link. If no shop's price could be confirmed, or the search fails, the card shows **Find it online** as before. "Similar" results don't search.

The form never overwrites a link the user added or a price they typed; the offer price replaces only an empty price, the "Use" estimate or an earlier offer. The link is set without fetching the page, so the user's photo stays. A new photo removes the link and price the old one filled in.

```
identify-product, identified result → { result, usage, offersToken }
  offersToken: HMAC-signed { requestId, title, brand, model, searchQuery, estimate, expiresAt (15 min) }
POST identify-product { offersToken, country: "GB", currency: "GBP" }     the ticket is the credential (free try too)
  ├─ verify the ticket (key derived from OFFERS_TICKET_SECRET, else the service role key)
  ├─ ai_identify_requests.offers_status null → pending        one search per identification, else 409
  ├─ Claude (OFFERS_MODEL, default claude-opus-5-5, effort low) with web_search_20260318
  │    (at most 3 searches, user_location = country, dynamic filtering) and a strict report_offers tool
  ├─ drop non-shops (search engines, comparison sites, social, video), search-result pages, a second link to a shop
  ├─ fetch-metadata on each page (in parallel, 15 s): keep offers whose page shows a price in the requested
  │    currency and within 0.4×–2.5× of the identification's typical range (drops accessories and bundles)
  └─ cheapest 3 back, cheapest first; offers_* columns record model, tokens, searches, offers found, latency
```

Response: `{ "offers": [{ "store", "url", "title", "price", "currency", "best" }] }`, empty when nothing was confirmed. Errors: 401 `unauthorized` (ticket missing, forged or expired), 409 `already_searched`, 503 `not_configured`, 502 `upstream_error` (the search goes back to unstarted and can be retried), 500 `server_error`.

The app sends the device's region and currency (`Locale.current`), so prices come from local shops in local money, and the chosen offer sets the item's currency.

**Cost and speed.**
- **Measured on Opus 5.5.** The first two real searches (Nov 18, 2026, from Ukraine) each ran 2 web searches and took 16–20 s. They read 23k–31k input tokens and wrote about 650. That is about 12.5–16¢ per search, on top of about 3¢ for identification.
- **Now on Haiku 5.5.** Reading the search results is most of that cost, so since Nov 18 production runs the shop search on Haiku 5.5 (`OFFERS_MODEL=claude-haiku-5-5`, a Supabase secret). The estimate is about 2–3¢ per search, mostly the $10-per-1,000 search fee. Identification stays on Opus 5.5.
- **Why a cheaper model is safe here.** The page check still drops wrong pages and unconfirmed prices, so a weaker model mostly risks finding fewer shops.
- **Bounded.** There's one search per identified photo, so the 300-a-day global cap bounds searches too.
- **Tuning.** Change these without redeploying: `OFFERS_MODEL`, `OFFERS_EFFORT`, `OFFERS_MAX_SEARCHES`.
- **Search setup.** If a model can't run web search from code (dynamic filtering), the function switches to calling the search directly. Anthropic's web search also refuses some countries as a location: UA is rejected. The search then runs without a location, and the prompt still names the country.

Real numbers:

```sql
select count(*) filter (where offers_status = 'ok') as with_offers, count(*) as searches,
       avg(offers_input_tokens), avg(offers_output_tokens), avg(offers_searches), avg(offers_latency_ms)
from ai_identify_requests where offers_status is not null;
```

**Privacy.** The web search gets the product's name and details from the identification, never the photo. Shops, links and prices aren't stored. The consent sheet now says "Shops are searched by the item's name, never the photo".

## Quotas

`claim_identify_slot(user, monthly_limit, global_daily_limit)` takes a per-user advisory lock, counts this calendar month's non-failed requests (UTC), checks the rolling 24 h global count, then inserts a `pending` row. The function marks it `ok`, `not_product`, `refused` or `failed`; `failed` rows stop counting against the user's month, so outages don't burn allowance. Only `service_role` can execute it (same hygiene as v8).

`claim_identify_trial_slot(trial_daily_limit, global_daily_limit)` (v11) does the same for free tries under one shared lock: it refuses while **3 free tries are already running** (pending rows under 3 minutes old), then applies the free-try 24 h cap (`IDENTIFY_TRIAL_DAILY_LIMIT`, default 100) and the global cap, and inserts a `pending` row with no user. The in-flight limit is there because DeviceCheck has no atomic test-and-set: a burst of parallel requests carrying one device's token could all read "unused" before the first marks it spent. The limit caps such a burst at 3 tries per device instead of the whole day's allowance.

Both 24 h caps also count `failed` rows that have output tokens, i.e. calls the model ran and billed but whose output was unusable, so those can't run past the budget. Before v11 the global cap ignored them. The caps are soft under concurrency (different users don't share a lock), which overshoots by at most a few requests.

## Privacy and App Review

- **Consent** — explicit, before the first photo leaves the device; names Anthropic; revocable in Settings (`@AppStorage("photoIdentifyConsent")`).
- **Privacy manifest** — added `NSPrivacyCollectedDataTypePhotosorVideos` (linked, app functionality, no tracking). Item photos were already uploaded to storage.
- **App Store Connect → App Privacy** — add *Photos or Videos · App Functionality · Linked to the user · Not used for tracking* before submitting.
- **Privacy policy (gimmelist.com/privacy)** — add:
  > *Photo identification.* If you choose to identify an item from a photo, Gimme sends that photo to its server, which passes it to Anthropic's Claude API to recognise the product. To find shops that sell it, Gimme then runs a web search through Anthropic using the product's name, never the photo. The photo isn't stored for this purpose and your name and email aren't sent with it; Gimme keeps only a record that a request happened (time and outcome) to apply monthly limits. If you aren't signed in, Gimme uses Apple's DeviceCheck service to remember that your device has used its one free identification; this doesn't tell Gimme who you are. You can turn this off in Settings → Identify from Photos.
- **DeviceCheck** — no new data type to declare: Gimme stores no device identifier, and the two bits live with Apple. No privacy manifest change.
- **Review notes** — mention the consent screen; that a signed-out device gets one free identification (Apple DeviceCheck) and then needs an account; and that the debug mock (`-mockIdentify`) is compiled out of Release builds.

## Files

| Area | Files |
|---|---|
| Backend | `supabase/functions/identify-product/{index,handler,prompt,devicecheck,offers}.ts`, `migration_v9_identify_requests.sql`, `migration_v11_identify_trials.sql`, `migration_v12_identify_offers.sql` (v10 is the Pro fix from PR #6), `supabase/config.toml`; shop pages are read by the existing `fetch-metadata` function |
| iOS service | `Whish/Services/ProductIdentificationService.swift` (model, live service, response decoder, prefill rules, debug mock) |
| Hand-off | `Whish/Services/SharedImageInbox.swift` (compiled into app + GimmeShare), `GimmeShare/ShareViewController.swift`, `project.yml` activation rule |
| UI | `Whish/Features/ListDetail/IdentifyController.swift` (shared flow: sign-in gate, consent, request, stale results), `IdentifyPhotoCard.swift` (card + consent sheet), `AddItemView.swift`, `HomeView.swift` (share hand-off + `FirstItemView`), `SettingsView.swift`, `PaywallView.swift` |
| Privacy | `Whish/PrivacyInfo.xcprivacy` |
| Tests | `supabase/functions/identify-product/{handler,devicecheck,offers}_test.ts`, `supabase/tests/migration_v{9,11,12}_test.ts`, `WhishTests/ProductIdentificationTests.swift` |

## Testing

```bash
deno test --node-modules-dir=none -A supabase/functions/identify-product/ supabase/tests/
```

```bash
xcodebuild -project Whish.xcodeproj -scheme Gimme -destination 'platform=iOS Simulator,name=iPhone 17' test
```

(`--node-modules-dir=none` stops Deno picking up the `package.json` in your home folder.)

- **Shop search (22 Edge Function, 5 migration, 9 iOS)** — tickets: signed for identified products only (free try included), rejected when forged, tampered, expired or incomplete; one search per identification; a search that failed before the model answered can be retried; refusals and missing reports give no offers; non-shops, search pages and duplicate shops dropped; prices taken from the page, in the requested currency, within the typical range; a page that can't be read drops only its offer. v12's claim and release updates on PGlite. iOS: the cheapest offer reaches the form with the device's country and currency, picking another, no ticket means no search, no shops or a failed search falls back to Find it online, a replaced photo's offers are dropped, offer decoding and price text.
- **Edge Function (36 before shop search)** — auth, validation, size limit, quota and global cap, Pro limit, refusal, failed-call refund, unreadable output, result normalisation. Free try: one per device, given back on failure, spent by a refusal, busy at the caps, Apple rejecting the token vs Apple being down, the try can't be recorded, development tokens, signed-in users never take this path. DeviceCheck client: the ES256 JWT verifies against a generated P-256 key, a `.p8` pasted with literal `\n`, bit parsing, development host only when allowed, 10 s timeout.
- **Migration (16)**, on in-process Postgres (PGlite) — v9: re-runnable, monthly counting, failed refund, month rollover, global cap, execute privileges, RLS. v11: re-runnable over v9, free-try cap, unbilled failures don't count but billed ones do, 3 running at once, abandoned tries stop blocking, shared global cap, every row is a user's or a free try, execute privileges.
- **iOS (26 new, 62 total)** — response decoding and every error code, prefill never overwriting typed text, estimate midpoint and locale formatting, shopping URL, share hand-off (once-only, stale drop, link vs photo precedence), memory-safe downscale, the shared controller (sign-in gate, consent then run, quota usage, dropping a replaced photo's result), and the free try (offered signed out, "That was your free try" afterwards, a spent try asks to sign in without a request, a refusal spends it).
- **Simulator walkthrough** with `-mockIdentify identified|similar|not_product|quota|offline|trial|trial_used` (Debug only): card → source menu → library → consent → result → Use price → save, on both New Wish and the first-run screen (fresh install); signed out on the first-run screen: "Your first one is free" → result + "That was your free try" → the next photo asks to sign in; Photos → Share → Gimme → list → auto-identify; quota → paywall; Settings switch.
- **Production smoke test**: 405 / 401 for wrong method, missing, publishable-key and forged tokens, and for a device token while DeviceCheck isn't configured. v11's claim functions run inside rolled-back transactions (each cap, 3 running at once, billed failures counted); only `service_role` can execute them; no rows left behind; the deployed function source is byte-identical to the repo; no new advisor findings.
- **First real calls** (Nov 18, 2026): a Debug build on an iPhone, signed in, identified 3 real photos against production. All 3 returned 200 (2 identified, 1 similar) in 3.3–4.2 s each; cost is under [Model, prompt and cost](#model-prompt-and-cost). Accuracy across 10–20 photos (checklist item 2) is still to do.
- **Not yet tested**: real DeviceCheck (needs the key and a physical iPhone; the Simulator doesn't support DeviceCheck). That's item 4 of the checklist below.

## Go-live checklist

1. Set the key (done on Nov 18, 2026). In the Claude Console:
   - Create a `Gimme` workspace (Settings → Workspaces) and give it a monthly spend limit under Settings → Spend limits → Workspace limits. The Default Workspace can't have one.
   - Under Settings → API keys, click **Create key** and choose **Somewhere else** (an API key). Link it to yourself, scope it to the **Gimme** workspace, and set the expiration to **Never**. The function sends no workspace ID, so a key that isn't scoped to one workspace fails on every request.
   - Copy the key and store it in Supabase. Running the command below reads the key from the clipboard, which keeps it out of your shell history; Dashboard → Edge Functions → Secrets works too. No redeploy is needed.

   ```bash
   supabase secrets set ANTHROPIC_API_KEY="$(pbpaste)" --project-ref dyporggvmfyzejopaezc
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
6. This branch now includes the Pro fix (PR #6, merged into main on Nov 16, 2026), and it needs it. Since migration v10, an account becomes Pro only through verify-purchase, and only builds with PR #6 call it. Without it, people who buy Pro would get Pro on their device but not on their account, so they'd get only the free 5 photos a month.
7. Merge the branch, bump the version, TestFlight, then ship with a "Snap to add" screenshot.

## Also fixed on this branch

- **Adding a wish bounced back to Home after the first wish.** The first-wish screen (and Add Item, when it moves an item to another list) navigated using the new list's temporary SwiftData ID. The next autosave, such as the one triggered when the photo picker opens, replaced that ID, the list-detail lookup failed, and navigation reset to Home. Both forms now save before navigating. Checked in the Simulator: first wish → list → New Wish → photo → identify → save stays in the list.

## Follow-ups

- **Pro could be self-granted (pre-existing, security): closed in production on Nov 13, 2026.** `profiles` RLS let a signed-in user update their own `is_pro`, which `WhishApp` turns into Pro and identify-product into the 100-a-month limit. Migration v10 and the verify-purchase Edge Function from PR #6 are live, so clients can't write `profiles` and only `record_pro_transaction()` sets `is_pro`. Checked in production: no client write privilege or policy on `profiles`. PR #6 is merged (checklist item 6); what's left is shipping an app build with it. The 3 accounts that were already Pro keep it: v10's draft section 4, which would have cleared them, was dropped.
- **Free try: replayed tokens.** Someone who captures their own request can replay its DeviceCheck token; the in-flight limit holds a burst to 3 tries and the free-try daily cap bounds the rest. If abuse ever shows up in `ai_identify_requests`, move the free try to App Attest, which proves each request comes from the genuine app.
- **Shop search, next steps.** Measure real searches (cost, speed, how often a price is confirmed) and try `OFFERS_MODEL=claude-haiku-5-5`. Then: affiliate tags on offer links (where the feature could pay for itself), offers for "similar" items, and VisionKit barcode scanning for exact matches.
