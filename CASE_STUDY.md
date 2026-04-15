# Gimme — Wishlist & Gifting App
## UX / UI / AI Design Engineering Case Study

**Role:** UX/UI Designer · iOS Engineer · AI Systems Engineer
**Platform:** iOS 17 · Next.js Web · Supabase Backend
**Status:** Production-ready, pre-launch
**Stack:** Swift 6 · SwiftUI · SwiftData · Supabase · Next.js 15 · Vercel

---

## Quick Stats

| | |
|---|---|
| 67 Swift source files | 10 feature screens |
| 12 backend services | 3 widget sizes |
| 5 Siri Shortcuts | 9 supported currencies |
| 1 Share Extension | 7 web pages |

---

## 01 — The Problem

> *"Every time I saw something I liked — scrolling through Instagram, browsing a random store, reading a newsletter — I had no good place to put it."*

The origin story of Gimme is a personal frustration with three distinct failure modes:

**Failure Mode 1 — Discovery is lost.** Notes app graveyards. Screenshot folders with no context. Bookmarks that get forgotten. There was no frictionless, *contextual* way to capture something you wanted from inside another app.

**Failure Mode 2 — Sharing your wishes is awkward.** When someone asks "what do you want for your birthday?" — you blank out, or send a one-off Amazon link that feels transactional. There was no living, shareable place that communicated *this is what I actually want, ranked by how much I want it.*

**Failure Mode 3 — Gift coordination is broken.** Finding the perfect gift for someone, saving it in a random note, forgetting about it by December, then panic-buying something generic. And on the receiving end: duplicate gifts, missed wishes, no coordination.

**Existing tools and why they failed:**

| Tool | Where it broke |
|---|---|
| Amazon Wish List | Locked to one retailer |
| Pinterest | Inspiration boards, not purchase intent |
| iOS Reminders | Too generic, no product context |
| Giftster / Elfster | Cluttered UI, no smart capture |
| Notes app | A graveyard — nothing ever acted on |

None solved all three failure modes. None combined frictionless capture, rich product context, and a social coordination layer.

---

## 02 — Discovery & Research

Before building, I mapped the problem space across three dimensions:

**Behavioral mapping — my own usage patterns:**
- 70% of item discovery happens on mobile, inside another app
- The gap between "I want this" and opening a dedicated app is where saves die
- Context is critical — *why* I saved something matters as much as *what*

**Competitive audit — 6 tools evaluated:**
I mapped what each tool did well and where it broke down. The consistent gap: every tool made saving feel like *work*, and none had social infrastructure for gift coordination.

**Platform capability audit — what iOS uniquely enables:**
Share Extension, WidgetKit, Siri Shortcuts, Spotlight Search, Universal Links, Realtime push — capabilities that no web app could replicate at the same quality level.

**The social contract of gifting:**
The awkwardness of knowing what someone got you. The etiquette of claiming. The problem of duplicate gifts at group occasions. The desire for surprise to be preserved.

> **Key insight:** The problem wasn't a missing database. It was *capture friction* and *zero social infrastructure.* Every existing tool treated saving as the product. The real product is the moment of discovery and the moment of gifting.

---

## 03 — Problem Framing

> *Build the simplest possible path from "I want this" to "someone got it for me" — and from "I want to give them something good" to "I got the right thing without duplicating anyone else."*

This framing produced three non-negotiable design principles:

### Principle 1 — Zero-friction capture
Saving an item should never require leaving the app you're in. Under 10 seconds from discovery to saved. No context switching, no manual typing.

### Principle 2 — Rich by default, not by effort
When you save a link, the app does the work — title, image, price, currency, extracted automatically. The user is not a data entry clerk.

### Principle 3 — Invisible coordination
Gifters should see and claim gifts without creating accounts. The social layer should feel effortless, not like signing up for another platform.

---

## 04 — Information Architecture

The core hierarchy is deliberate: **Lists → Items**. But the structure decisions were not obvious.

**Why multiple lists, not one:**
"Birthday," "Home," "Tech," "For Mom" — context is everything. A flat list collapses intent.

**Why the list is the unit of sharing:**
You share occasions, not individual items. Sharing a list maps to how gifting actually works.

**Why items carry full product context:**
Title, image, price, currency, priority, end date, notes. Not just a bookmark — a product record.

**Why priority is a first-class field:**
High / Medium / Low tells a gifter what matters most. A flat list communicates nothing about intent.

**Navigation philosophy:**
Flat, sheet-based navigation. One deep push (Home → List → Item). No tab bars. Everything within two taps from home.

**The three-state item model:**

| State | Meaning |
|---|---|
| Wanted | Default — on your wishlist |
| Purchased | You bought it yourself |
| Reserved by friend | Someone is getting it for you |

This model preserves gift surprise — the owner sees *that* someone claimed something, but not specifically what.

---

## 05 — The Capture Problem

*The most important UX decision in the project.*

The fundamental insight: **the moment of discovery happens in another app.** If saving requires switching to Gimme and manually pasting a URL, most saves will never happen.

### Solution Part 1 — iOS Share Extension

"Save to Gimme" appears in any app's share sheet. One tap. URL handed off, app opens pre-filled.

This required a separate app extension target (GimmeShare) with a cross-process handoff mechanism via App Groups shared UserDefaults. The main app detects a pending URL on foreground activation and opens the Add Item sheet pre-filled.

**The UX payoff:** The user never leaves the context they're in. Safari, Instagram, Amazon — the save mechanism is identical everywhere.

### Solution Part 2 — The Metadata Extraction Pipeline

Once a URL arrives, the user shouldn't type anything. This is the **AI engineering layer** of the project — not a neural network, but an intelligent multi-strategy parsing system that makes decisions, handles fallbacks, and produces structured product data from unstructured HTML.

**The pipeline (in priority order):**

| Strategy | Why |
|---|---|
| JSON-LD structured data | Most reliable; used by major retailers (ASOS, IKEA, etc.) |
| Open Graph meta tags | Universal fallback; supported by most modern sites |
| Microdata | Schema.org product markup |
| HTML selector heuristics | Last resort; targets common class/ID patterns |

**What gets extracted:**
- Product title and description
- Images (scored and ranked — not just the first one found)
- Price and currency (ISO code)
- Product variants: color, size from URL params + structured data
- Brand name

**Edge cases handled:**
- Desktop Safari User-Agent (bypasses mobile redirects)
- Redirect chains (`itms://` → `https://`)
- App Store links (special parser)
- Multiple images → user sees a picker with ranked options
- Auto-fetch triggers on URL paste — no button press needed

> **The UX payoff:** Saving an item from ASOS, Apple, IKEA, Etsy, or any random online shop all *feel identical* to the user — instant, rich, effortless. The complexity is entirely hidden.

---

## 06 — The Social Layer

*The hardest design problem: gift coordination without accounts.*

Asking a friend to create an account to see your wishlist kills the sharing loop instantly. This was a non-negotiable constraint.

**The architecture:**

1. Each list generates an encrypted share token
2. Token produces a public URL on a Next.js / Vercel web app
3. Anyone with the link views items and claims them — name only, no account required
4. Claiming triggers Supabase Realtime update + push notification to list owner
5. Owner sees "reserved by [name]" — but not *which* item (preserves surprise)
6. Supabase RPC functions handle atomic claim / unclaim

**The UX tension resolved:**
The list owner needs to know coordination is happening — but not *what* specifically, or the surprise is ruined. The design surfaces "someone claimed something" without "someone claimed the AirPods."

**Web share page (Next.js / Vercel):**
- Fully public, no login required for viewers
- Dynamic OG image generation per list (1200×630) — rich previews in iMessage, Slack, Twitter
- Universal Links: if the user has the app, the link opens directly in Gimme
- Free tier: 2 shared lists. Pro: unlimited.

---

## 07 — Ambient Access

*The product lives beyond the app.*

A wishlist that only exists behind an app icon has weak recall. Gimme extends its presence to where the user already looks:

| Surface | What it shows |
|---|---|
| Lock Screen widget | Top-priority item, always visible without unlocking |
| Small home screen widget | Quick glance at most urgent wish |
| Medium home screen widget | List overview with top 3 items |
| Siri — "What's on my birthday list?" | Voice readout of current list |
| Siri — "Add AirPods to my tech list" | Voice capture without opening the app |
| Siri — "How much is left on my wishlist?" | Total remaining value, spoken |
| Spotlight Search | Every list and item indexed — find anything from iOS search |

> Widgets and Siri make the wishlist *ambient*. Passive visibility reinforces that the list is alive and worth maintaining — creating a habit loop without requiring deliberate app opens.

---

## 08 — Design System

Built code-first in `Theme.swift`, not designed in Figma first. Every token is intentional.

**Typography:** SF Pro Rounded — warmer than default SF Pro. Creates a more personal, less utilitarian feel for something that's about wants and wishes.

**Accent color `#6C63FF`:** Soft purple — aspirational without being aggressive. Associated with desire, creativity, premium. Consistent across iOS and web.

**Color system:**
- 10 preset list colors — personalization that's fast and foolproof. No free-form picker = no bad color choices.
- Adaptive light / dark variants for all surfaces
- WCAG contrast enforcement in code (3:1 for glows, 4.5:1 for text) — accessibility at the design-system level

**Spacing tokens:**

| Token | Value | Usage |
|---|---|---|
| xs | 4pt | Tight inline spacing |
| sm | 8pt | Component internal padding |
| md | 12pt | Section gaps |
| lg | 16pt | Card padding |
| xl | 24pt | Section separation |

**Corner radii:**

| Surface | Radius |
|---|---|
| Card | 20pt |
| Sheet | 28pt |
| Button | 14pt |
| Badge | 8pt |

**Motion:** Spring physics with tuned response/damping. Matched geometry transitions for the emoji/color picker overlays — spatial continuity, never teleporting. All state transitions feel physical.

**Auth surface:** Glassmorphism with gradient background — depth and premium without heavy visuals.

---

## 09 — Monetization Design

The free tier is deliberately generous. This was a strategic product decision, not a constraint.

**Free:** Unlimited lists and items, cloud sync, sharing up to 2 lists, widgets.

**Why cap at 2 shared lists (not 0):**
Sharing is the viral acquisition mechanic. Every shared list is a public landing page seen by people who don't have the app. Capping after the value is felt — not before — converts users, not frustrates them.

**Pro — $4.99 lifetime:**
- Unlimited shared lists
- Stats dashboard with spending analytics
- Advanced insights and currency breakdown

**Why lifetime, not subscription:**
For a utility app, recurring charges feel disproportionate. A single lifetime purchase eliminates ongoing friction, builds trust, and removes the reason to delete the app when a subscription tier feels underused.

---

## 10 — Technical Architecture as UX

*Every major technical decision was made in service of the user experience.*

| Technical Decision | UX Outcome |
|---|---|
| SwiftData + local-first | App is instant. Works offline. No loading spinners for your own data. |
| Supabase Realtime | Friend claims appear live on share page — no refresh needed |
| App Groups (Share Extension ↔ App) | Save from any app without the user noticing a handoff |
| Supabase Edge Functions for push | Friend claims trigger instant notification — closes the feedback loop |
| Vercel OG image generation | Share links have rich previews in iMessage, Twitter, Slack |
| Universal Links (AASA) | Share links open directly in the app if installed |
| StoreKit 2 | Purchase is 2 taps, receipt-backed, auto-restored |
| Last-write-wins sync (30s throttle) | Sync is silent and automatic — user never thinks about it |
| Background ModelContext | Sync never blocks the UI thread |
| PKCE + SHA256 nonce | Apple Sign In is secure by default, not bolted on |

---

## 11 — What's Built

All of the following is production-grade and fully implemented:

- **Multi-list management** — create, rename, emoji, color, pin, archive
- **Rich item capture** — title, notes, URL, image, price, currency, priority, end date
- **Metadata extraction pipeline** — auto-fill from any URL, image scoring, variant detection
- **Cloud sync** — bidirectional, last-write-wins, offline-first, conflict resolution
- **Social sharing** — public list links, friend claiming, Realtime updates
- **Push notifications** — APNs via Supabase Edge Function, triggered by DB on claim
- **Widgets** — small, medium, lock screen (WidgetKit)
- **Siri Shortcuts** — 5 intents (open list, add item, quick add, remaining value, stats)
- **Spotlight Search** — every list and item indexed
- **Share Extension** — "Save to Gimme" in any app's share sheet
- **Stats dashboard** — donut chart, spending breakdown, currency conversion (9 currencies)
- **Auth** — email/password + Apple Sign In (PKCE), guest mode
- **Monetization** — StoreKit 2 lifetime Pro purchase
- **Onboarding** — 3-page animated tutorial
- **Web** — marketing landing page + dynamic share pages + OG images (Next.js / Vercel)
- **Design system** — full token library, dark/light, spring animations, WCAG contrast

---

## 12 — What's Next

| Priority | Feature | Strategic Reason |
|---|---|---|
| P1 | Web share page polish | #1 viral acquisition surface — every list is a public landing page |
| P2 | Smart Event Engine | Proactive birthday/occasion reminders — turns app from reactive to proactive |
| P3 | In-list sections & tags | Power user organization |
| P3 | Split-the-gift contributions | Group gifting without Venmo spreadsheets |
| P4 | Price drop tracking (Pro) | Creates daily app opens, justifies Pro upgrade |

---

## 13 — Key Learnings

**The best UX decisions in this project were technical decisions.**
The Share Extension, the metadata pipeline, the Realtime claims, the local-first sync — none of these are visible in the UI. All of them are felt in the experience. Engineering *is* design at this layer.

**On scope discipline:**
Building a full-stack iOS product solo requires ruthless prioritization. Every feature not built is a feature that couldn't break. The question was always: *does this reduce friction on the critical path from discovery to saved?*

**On the AI engineering angle:**
The metadata extraction pipeline is the most technically complex part of the product and the least visible to the user. That invisibility *is* the design success. When the intelligence works, the user just sees a perfectly-filled card. When it doesn't, they see an empty field and fill it in. Graceful degradation as a design principle.

**On social product design:**
Removing account creation from the gifter flow was the single highest-leverage decision for shareability. Every barrier to viewing a shared list is a broken gifting moment. The product only works if the social loop closes — and that required making the "receiving end" feel as polished as the "sending end."

---

*Built by Dmytro Yaremchuk · 2026*
