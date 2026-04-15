# Gimme — Full Codebase Analysis
_Generated: April 15, 2026_

---

## Architecture Overview

| Layer | Technology |
|-------|-----------|
| **iOS App** | Swift 6, SwiftUI, SwiftData, iOS 17+ |
| **Backend** | Supabase (PostgreSQL + Auth + Storage + Edge Functions + Realtime) |
| **Web** | Next.js 15, React 19, Tailwind CSS v4, Vercel |
| **Monetization** | StoreKit 2 (lifetime IAP) |
| **Extensions** | Share Extension, WidgetKit (3 sizes), Siri Shortcuts (5 intents) |

---

## Quick Stats

| Metric | Count |
|--------|-------|
| Swift source files | 67 |
| Feature screens | 10 |
| Services | 12 |
| Edge Functions | 2 |
| Web pages | 7 |
| Siri Shortcuts | 5 |
| Widget sizes | 3 (small, medium, lock screen) |
| Supported currencies | 9 |

---

## Existing Functionality (Fully Built)

### 1. Core Wishlist Management
- Create unlimited wishlists with emoji icon + 10 color presets
- Add items with title, notes, URL, images (camera / photo library / URL), price, currency, priority
- Pin / archive / delete lists and items
- Inline rename, sort (date / priority / name / status), filter (all / wanted / purchased)
- Grid + list view toggle
- Swipe actions for quick pin / archive / edit / delete

### 2. Smart Metadata Extraction
- Multi-strategy pipeline: JSON-LD → Open Graph → microdata → HTML selectors
- Extracts: title, images (scored/ranked), price, currency, brand, color, size
- Auto-fetch on URL paste, image selector when multiple found
- Desktop Safari User-Agent (avoids app-store redirects)
- Redirect guard for app-scheme URLs (`itms://` → `https://`)

### 3. Cloud Sync (Supabase)
- Bidirectional push/pull with last-write-wins conflict resolution
- Image upload to Supabase Storage with compression
- 30-second throttle between syncs
- Merge-on-sign-in: prompts to import or discard guest data
- Background ModelContext (avoids MainActor blocking)

### 4. Authentication
- Email/password + Apple Sign In (SHA256 nonce, PKCE)
- Password recovery via email reset link
- Account deletion (Supabase Edge Function with admin client)
- Guest mode: full offline functionality, no account required

### 5. Sharing & Gifting
- Generate shareable link per list (encrypted share token)
- Free: 2 shared lists; Pro: unlimited
- Web share page: friends view items + claim gifts (name + optional comment)
- Supabase Realtime for live claim updates
- Claim / unclaim via Supabase RPC functions
- No account needed for viewers / claimers

### 6. Push Notifications
- APNs integration via Supabase Edge Function
- DB trigger fires on `wish_items.is_reserved_by_friend = true`
- JWT signing (ES256) with P8 key in Edge Function
- Token management: register on sign-in, clean up expired tokens (410)
- Local reminders: UNUserNotificationCenter (on-the-day, 1 / 3 / 7 days before deadline)

### 7. Widgets (WidgetKit)
- **Small:** top item preview
- **Medium:** list overview with top 3 items
- **Lock Screen:** compact stats
- App Group data sharing, debounced 500ms snapshot updates
- Currency conversion applied in snapshot

### 8. Siri Shortcuts (5 intents)
- Open a specific list
- Add a new item
- Quick add (voice-only)
- "How much left?" (total remaining value)
- View stats

### 9. Spotlight Search
- Core Spotlight indexing of all lists and items
- `CSSearchableItem` with deep link callbacks
- Re-indexed after app launch and sync

### 10. Share Extension (GimmeShare)
- Accepts URLs and plain text from any app
- Stores in App Group UserDefaults (`pendingSharedURL`)
- Main app detects on scene-phase-active → shows list picker → AddItemView

### 11. Stats Dashboard (Pro only)
- Grouping: by priority, by list, by status
- Metrics: total spending, completion fraction, pie segments
- Insights: trending items, most-wanted lists, highest-priority items
- Currency picker + auto-detect dominant currency
- Live FX rates (open.er-api.com, 24h cache, 9 currencies)

### 12. Design System
- Full theme: dark/light colors, spacing grid, corner radii, shadows, spring animations
- Components: PriorityBadge, AsyncImageView, EmptyStateView, FlowLayout, ScaleButtonStyle, SyncToast
- Typography: SF Pro Rounded via `UIFontDescriptor.withDesign(.rounded)`
- WCAG contrast checking (3:1 for glows, 4.5:1 for text)

### 13. Web (Next.js / Vercel)
- Marketing landing page (editorial bento-grid design)
- Dynamic share pages (`/share/[token]`)
- OG image generation per list (Vercel OG, 1200×630)
- Legal pages: privacy, terms, support, contact
- Apple App Site Association header for Universal Links

### 14. Supabase Edge Functions
- `delete-account`: JWT-verified user deletion via admin client
- `send-reservation-notification`: APNs push on item claim, triggered by DB

### 15. Onboarding
- 3-page tutorial (welcome, sharing, sync)
- Animated floating orbs, skip button
- Sign-in flow at completion

---

## Planned Functionality

| Priority | Feature | Status | Evidence |
|----------|---------|--------|----------|
| P1 | Web share page polish | Partially done | Built, but App Store URL placeholders (`0000000000`) need real ID |
| P2 | Smart Event Engine | Not started | Proactive birthday / event reminders |
| P2 | Participant management | Scaffolded | "Add Participants" card in NewListView, marked Phase 3 |
| P2 | Collaborative lists | Not started | Friends editing the same list (Phase 3) |
| P3 | In-list sections & tags | Not started | Competitive analysis priority |
| P3 | Split-the-gift contributions | Not started | Competitive analysis priority |
| P3 | Price drop tracking | Not started | Planned Pro feature |
| P4 | Binary image blob sync | Partial | External storage in SwiftData; upload exists, full sync deferred |
| P4 | Advanced permission controls | Not started | Phase 3 concept |
| P4 | Sync conflict UI | Not started | Currently silent last-write-wins |

---

## Immediately After Getting Apple Dev Account

### Day 1 — Account Setup & Certificates

| # | Action | Why |
|---|--------|-----|
| 1 | Create App ID (`com.yaremchuk.app`) | Required for everything else |
| 2 | Enable capabilities: Push Notifications, App Groups, Associated Domains, Sign in with Apple | Must match entitlements file |
| 3 | Create APNs Key (P8 file) | Edge Function needs `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY` (base64-encoded P8) |
| 4 | Create Provisioning Profiles for all 3 targets: main app, Share Extension, Widget | All targets need signed profiles |
| 5 | Register Associated Domains (`applinks:gimmelist.com`, `webcredentials:gimmelist.com`) | Universal Links for share URLs |

### Day 2 — App Store Connect

| # | Action | Why |
|---|--------|-----|
| 6 | Create app in App Store Connect with Bundle ID `com.yaremchuk.app` | Gets the real Apple App ID |
| 7 | Replace all `0000000000` placeholders in web: `web/app/layout.tsx` (meta tag), `web/app/page.tsx` (CTA link), `web/app/share/[token]/page.tsx` (download CTA), `web/components/WishItemCard.tsx` (post-claim prompt) | Smart App Banner + all download buttons currently broken |
| 8 | Create IAP `com.yaremchuk.app.pro.lifetime` in App Store Connect | StoreKit 2 needs the real product registered |
| 9 | Upload screenshots (HTML templates ready in `AppStore/screenshots/`) | Required for submission |
| 10 | Fill App Store listing from `AppStore/listing.md` | Description, keywords, privacy labels already written |

### Day 3 — Push Notifications Go Live

| # | Action | Why |
|---|--------|-----|
| 11 | Upload APNs P8 key to Supabase secrets (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`) | Edge Function fully coded but needs real credentials |
| 12 | Set `APNS_USE_SANDBOX=true` initially | Switch to `false` before production release |
| 13 | Deploy Edge Functions (`send-reservation-notification`, `delete-account`) | Verify deployed and accessible |
| 14 | Run `migration_v3_push_notifications.sql` on production Supabase | Creates `device_tokens` table + DB trigger |

### Day 4 — Universal Links & Vercel

| # | Action | Why |
|---|--------|-----|
| 15 | Verify `apple-app-site-association` at `gimmelist.com/.well-known/` returns correct JSON with real Team ID + Bundle ID | `next.config.js` already sets the header — just needs real IDs |
| 16 | Deploy web to Vercel with env vars: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Share pages need live Supabase |
| 17 | Test Universal Links end-to-end (share link → Safari → app opens SharedListView) | Critical sharing flow |

### Day 5 — TestFlight & Submission

| # | Action | Why |
|---|--------|-----|
| 18 | Archive & upload build: Xcode → Product → Archive | Submits to App Store Connect |
| 19 | Submit to TestFlight for internal testing | Validate IAP, push, sync, sharing on real devices |
| 20 | Test all critical flows: sign up, purchase Pro, share list, claim item (verify push received), widget, Share Extension, Siri | Full regression before App Review |
| 21 | Set encryption exemption (standard HTTPS, BIS Note 4) | Already documented in `listing.md` |
| 22 | Submit for App Review | v1.0.0 |

---

## Pro Price

**$4.99 lifetime** — consistent across all three locations:
- `Whish/Gimme.storekit` ✓
- `AppStore/listing.md` ✓
- `web/app/page.tsx` ✓

---

## File Map

```
/
├── Whish/                          iOS main target
│   ├── App/                        WhishApp.swift, ContentView.swift
│   ├── Auth/                       AuthView.swift
│   ├── Models/                     WishList, WishItem, Priority, ReminderOption
│   ├── Features/
│   │   ├── Home/                   HomeView, HomeViewModel, WishListCard, NewListView
│   │   ├── ListDetail/             WishListDetailView, ListDetailViewModel, WishItemCard, AddItemView
│   │   ├── ItemDetail/             WishItemDetailView, ItemDetailViewModel
│   │   ├── Stats/                  StatsView, StatsViewModel
│   │   ├── Settings/               SettingsView, PaywallView, DeleteAccountView
│   │   ├── Onboarding/             OnboardingView, OnboardingViewModel
│   │   ├── SharedList/             SharedListView, SharedListViewModel
│   │   └── Intents/                GimmeShortcuts, OpenListIntent, AddItemIntent, ViewStatsIntent
│   ├── Services/
│   │   ├── AuthService.swift
│   │   ├── PurchaseService.swift
│   │   ├── PushNotificationService.swift
│   │   ├── NotificationService.swift
│   │   ├── CurrencyRateService.swift
│   │   ├── LiveMetadataService.swift
│   │   ├── WidgetDataService.swift
│   │   ├── SpotlightIndexService.swift
│   │   ├── DeepLinkRouter.swift
│   │   └── SupabaseManager.swift
│   ├── Sync/                       SyncService.swift, SyncRecords.swift
│   ├── Design/                     Theme, Typography, Haptics, Components
│   └── Utilities/                  Extensions.swift, ImageCompressor.swift
├── GimmeShare/                     Share Extension target
├── GimmeWidget/                    WidgetKit target (small, medium, lock screen)
├── supabase/
│   └── functions/
│       ├── delete-account/         index.ts
│       └── send-reservation-notification/  index.ts
├── web/                            Next.js app (Vercel)
│   └── app/
│       ├── page.tsx                Landing page
│       ├── share/[token]/          Public share view + OG image
│       ├── privacy/                Privacy policy
│       ├── terms/                  Terms of use
│       ├── support/                FAQ
│       └── contact/                Contact
├── AppStore/                       Listing copy, screenshots
├── migration_v3_push_notifications.sql
└── CLAUDE_CODE_PROMPT.md
```

---

## Key Third-Party Dependencies

| Dependency | Purpose |
|-----------|---------|
| Supabase (Swift) | Auth, database, storage, realtime, edge functions |
| StoreKit 2 | In-app purchases |
| AppIntents | Siri Shortcuts |
| UserNotifications | Local reminders |
| CoreSpotlight | Spotlight indexing |
| WidgetKit | Home/Lock Screen widgets |
| CryptoKit | SHA256 nonce for Apple Sign In |
| @supabase/supabase-js | Web: database queries, RPC, realtime |
| @vercel/og | Web: dynamic OG image generation |
| Next.js 15 | Web: routing, server components, API |
| Tailwind CSS v4 | Web: styling |
