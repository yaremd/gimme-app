# Gimme — App Store Listing

## App Name (30 chars max)
Gimme — Wishlist & Gift Ideas

## Subtitle (30 chars max)
Save, Track & Share Wishes

## Promotional Text (170 chars, changeable without review)
NEW: Price drop alerts — Gimme watches the price of anything you save and tells you the moment it falls. Plus price history, smart verdicts, and your own target price.

## Keywords (100 chars max)
wishlist,gift ideas,registry,birthday,christmas,wedding,baby shower,price drop,price alert,holiday

## Description

Your wishes, all in one beautiful place.

Gimme is the wishlist app that makes it effortless to save what you want, organize your ideas, and share your lists with anyone — no account needed for the people you share with. Built exclusively for iPhone with deep iOS integration that no other wishlist app offers.

SHARE WITHOUT FRICTION
Send a wishlist link to friends and family. They can see your wishes and quietly mark what they're getting — all from a simple web page. No downloads, no sign-ups, no spoiled surprises.

SAVE FROM ANYWHERE
Use the Share Extension to save items from Safari, Amazon, or any app. Gimme automatically extracts the product name, image, and price so you don't have to type a thing.

NEVER PAY FULL PRICE
Save something with a link and Gimme keeps an eye on what it costs. When the price drops, you get a notification — tap it to jump straight to the item and buy at the lower price. Every tracked item shows its price history, where today's price sits between the highest and lowest seen, and a one-glance verdict: Lowest price yet, Good price, Typical, or Higher than usual. Set your own target and Gimme tells you the moment it's reached.

ORGANIZED YOUR WAY
- Create unlimited wishlists with custom emoji and colors
- Set priorities to highlight what matters most
- Pin favorite lists and items to the top
- Archive old items without deleting them
- Filter by Wanted or Purchased status

DEEP iOS INTEGRATION
- Home Screen & Lock Screen widgets
- Siri Shortcuts: "Add wish in Gimme", "Wishlist total"
- Spotlight search: find any item instantly
- Share Extension: save from any app

TRACK YOUR SPENDING
The Stats dashboard shows total wishlist value, purchased vs. remaining, and a visual breakdown by list or priority. Supports 9 currencies including USD, EUR, GBP, JPY, CAD, AUD, CHF, CNY, and UAH — prices convert automatically.

SYNC ACROSS DEVICES
Create a free account to sync all your wishlists. Sign in with Apple or email — your choice.

PRIVACY FIRST
No ads. No tracking SDKs. No spam. Works fully offline in local-only mode. Your data stays on your device unless you choose to sync.

GIMME PRO — UNLOCK EVERYTHING
Free: unlimited lists, items, sync across devices, Share Extension, widgets, price tracking on 3 items, and share up to 2 lists with friends. Pro unlocks price tracking on everything, unlimited sharing, the full Stats dashboard with charts and currency conversion, all widget sizes, and every future feature we ship. A single lifetime purchase — no subscriptions, no recurring charges. Pay once, own it forever.

Download Gimme and start saving what you want.

## What's New (Version 1.1.1)

Deleting now sticks.

- Fixed lists and items reappearing after you deleted them, especially after pulling to refresh
- Deletions now sync reliably to all your devices and to lists you've shared
- Deleting works offline too — Gimme finishes the job the next time you're online

## What's New (Version 1.1.0)

Price drop alerts are here.

- Gimme now watches the price of any item you saved with a link
- Get a notification the moment the price falls — tap it to go straight to the item
- Price history chart on every tracked item, with a low-to-high range
- At-a-glance verdict: Lowest price yet, Good price, Typical, or Higher than usual
- Set a target price and get alerted when it's reached
- "Buy at ..." button appears while a drop is live
- Paste button in the URL field when adding an item
- Track 3 items free; Gimme Pro tracks everything

## What's New (Version 1.0.0)

Welcome to Gimme! Your new favorite wishlist app.

- Create and organize wishlists with emoji and colors
- Save items from any app with the Share Extension
- Auto-extract product details from URLs
- Share wishlists via link — no account needed for friends
- Home Screen and Lock Screen widgets
- Siri Shortcuts for hands-free control
- Stats dashboard with spending breakdown
- Cloud sync with free account
- Sign in with Apple
- Gimme Pro lifetime upgrade available

## App Review Notes

Sign-in required: yes (to test sync and sharing).
User name: reviewer@gimmelist.com
Password: kept in App Store Connect, not in the repo. Reset it in Supabase
(Authentication → Users) if it is lost.

Paste into App Store Connect → App Review Information → Notes:

```
WHAT'S NEW IN 1.1.1
Bug fix: deleted lists and items could reappear after a refresh or come back from another device. To verify: sign in, delete an item, then pull to refresh on the list — it stays deleted.

DEMO ACCOUNT
The app works fully without an account (local-only mode). Sign in with the credentials above to test sync and sharing; the account has sample wishlists.

SHARING
Open any list -> tap the share icon -> copy the link. The link opens a web page where anyone can view the list and reserve items without an account.

SHARE EXTENSION
In Safari, open any product page, tap Share, choose "Save to Gimme". Title, image and price are extracted automatically.

WIDGETS AND SIRI
Home Screen and Lock Screen widgets: long-press the Home Screen -> "+" -> search "Gimme". Siri: "Hey Siri, add wish in Gimme".

PRICE TRACKING
Open an item saved with a product URL and switch on "Price tracking". "Check now" re-fetches the price from the page the user saved, via the app's own Supabase function; no third-party price API. Price history stays on-device.

BACKGROUND REFRESH
The "fetch" background mode and BGAppRefreshTask (com.yaremchuk.app.price-refresh) are used only to re-check prices of tracked items: at most once per 4 hours, and per item at most once per 20 hours.

NOTIFICATIONS
Price drop alerts are local notifications. Permission is requested when price tracking is turned on.

IN-APP PURCHASE
"Gimme Pro" one-time lifetime purchase ($4.99), non-consumable, StoreKit 2. Free users can track 3 items; Pro removes the limit.
```

## App Store Connect Configuration

| Field | Value |
|-------|-------|
| Bundle ID | com.yaremchuk.app |
| SKU | gimme-wishlist-2026 |
| Primary Language | English (U.S.) |
| Price | Free |
| IAP | Gimme Pro ($4.99, Non-Consumable, Lifetime) |
| Privacy Policy URL | https://gimmelist.com/privacy |
| Support URL | https://gimmelist.com/support |
| Marketing URL | https://gimmelist.com |
| Copyright | 2026 Dmytro Yaremchuk |
| Primary Category | Lifestyle |
| Secondary Category | Shopping |
| Age Rating | 4+ |
| Uses IDFA | No |
| Encryption | Yes (standard HTTPS only — BIS exemption Note 4) |

## Screenshot Plan

Carousel order is the `#` column; filenames keep their original numbering so
existing exports don't have to be renamed.

| # | Screen | Caption | File |
|---|--------|---------|------|
| 1 | Home with colorful list cards | All your wishes, one beautiful place | `01-home.html` |
| 2 | Item detail with the price tracking card | Never pay full price | `09-price-tracking.html` |
| 3 | Share Extension in Safari | Save from any app in one tap | `02-share-extension.html` |
| 4 | Shared list web view + claiming | Share with anyone. No app needed. | `03-shared-list.html` |
| 5 | List detail with items/filters | Filter, sort & organize your way | `04-list-detail.html` |
| 6 | Widget collection | Widgets for your wishes | `05-widgets.html` |
| 7 | Stats dashboard with donut chart | See where your money goes | `06-stats.html` |
| 8 | Siri Shortcuts in action | "Hey Siri, add a wish" | `07-siri.html` |
| 9 | Pro features/paywall | One price. Everything. Forever. | `08-pro.html` |

Price tracking sits at #2 because only the first three are visible without
scrolling, and it's the headline feature of 1.1.0. Screenshot 4's caption
moved off "Track prices" so the two don't claim the same thing.

Sizes: 6.7" (1290x2796) and 6.1" (1179x2556)

Screenshot files: `AppStore/screenshots/*.html`
Open in Safari at 1290x2796 viewport, export as PNG.

## App Privacy Labels

Nothing is collected in local-only mode. Once the user creates an account,
wishlists sync to Supabase, so the labels cover what sync stores. Earlier
versions of this file listed User Content and Purchases as "not collected",
which was wrong once sync shipped: synced item titles, notes, links and
photos, and the Pro status (`syncProToSupabase`), are all stored server-side
against the user's account.

**Data Used to Track You:** None

**Data Linked to You** (all for App Functionality only):

| Category | Data Type | What it is |
|----------|-----------|------------|
| Contact Info | Email Address | Account sign-in |
| Identifiers | User ID | Cloud sync |
| User Content | Photos or Videos | Item photos the user adds, uploaded when syncing |
| User Content | Other User Content | Synced lists and items: names, notes, links, prices |
| Purchases | Purchase History | Gimme Pro status, so it follows the account |

**Data Not Linked to You:** None

**Data Not Collected:** Location, Health & Fitness, Financial Info, Sensitive Info, Contacts, Browsing History, Search History, Diagnostics, Usage Data

Notes:
- No IDFA usage, no third-party analytics, tracking or advertising SDKs
- Works fully offline without collecting anything
- Data is collected only when the user chooses to create an account
- Not used for tracking, third-party advertising or analytics
