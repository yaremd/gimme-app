# Reddit Posts for Gimme — Copy-Paste Drafts

Each section has a **target subreddit**, **title**, **body**, and **notes** (rules, timing, etc.). Reddit hates obvious self-promo, so each post leads with a problem, a build story, or genuine value — link/app name comes near the bottom.

General rules:
- Check each subreddit's rules and self-promo policy before posting.
- Use account in good standing (1:9 self-promo ratio is the unofficial rule).
- Don't cross-post the same exact text within 24h. Space posts out across a week.
- Reply to every comment for the first 2 hours — engagement matters more than the post.

---

## 1. r/iOSProgramming — solo dev technical post

**Title:** I shipped my first solo iOS app after a year of nights and weekends — here's the architecture breakdown

**Body:**
Just hit the "submit for review" button on Gimme, a wishlist app I've been building solo. Wanted to share the architecture choices in case anyone's working on something similar.

**Stack:**
- Swift 6, SwiftUI (no UIKit except `UIImagePickerController`)
- SwiftData for local persistence (offline-first)
- Supabase for auth, Postgres, Realtime, and Edge Functions
- WidgetKit (small, medium, lock screen)
- App Intents for 5 Siri Shortcuts
- Share Extension via App Groups
- Next.js + Vercel for the public share pages with dynamic OG images

**Things I'd do again:**
- Local-first with SwiftData. The app is instant. Sync runs in the background, last-write-wins on `updatedAt`, throttled to once per 60s. Users never see a spinner for their own data.
- Background `ModelContext` for sync — never blocks UI.
- Share Extension → App Groups `UserDefaults` → main app foreground detection. The cleanest cross-process handoff I've found.
- Multi-strategy URL metadata extraction: JSON-LD → OG tags → Microdata → HTML heuristics. Saves users from being data-entry clerks.

**Things I'd do differently:**
- Started with CoreData, migrated to SwiftData mid-project. Should've just started with SwiftData.
- Underestimated how long App Store screenshots, listing copy, and review notes would take. Plan a full week.
- Universal Links (AASA file) was more painful than I expected. Test on a real device early.

**Hardest part:**
The social sharing layer without forcing accounts. Each list gets a share token → public Next.js page → friends claim items → Supabase Realtime pushes back to the owner via Edge Function + APNs. The constraint: owner sees "someone reserved something" but not *what*, to preserve gift surprise.

Happy to answer questions about any of it.

**Where to post:** [r/iOSProgramming](https://www.reddit.com/r/iOSProgramming)
**Notes:** No-promotion-Tuesday-style rules don't apply here, but no direct App Store links in the post body — drop the link only if asked in comments. Best posting time: Tue–Thu 9–11am ET.

---

## 2. r/SwiftUI — design / SwiftUI showcase

**Title:** Built a code-first design system in Theme.swift — sharing my token setup for spacing, radii, and colors

**Body:**
For my wishlist app I went code-first instead of designing in Figma. Everything lives in `Theme.swift`. Wanted to share the structure since I haven't seen many writeups on this approach.

**Spacing scale:**
```swift
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}
```

**Corner radii by surface type:**
- Card: 20pt
- Sheet: 28pt
- Button: 14pt
- Badge: 8pt

**Color rules:**
- Single accent (`#6C63FF`) — soft purple, aspirational without being aggressive
- 10 preset list colors so users can't pick a bad combo
- WCAG contrast ratios enforced in code: 3:1 for glows, 4.5:1 for text. The function returns the right foreground for any background.
- Adaptive light/dark variants via `Color(uiColor: .init { ... })`

**Motion:**
Spring physics with tuned `response`/`dampingFraction`, not arbitrary numbers. Matched geometry transitions for emoji/color picker overlays — spatial continuity, never teleporting.

**Why code-first:**
- No drift between design and code
- Tokens are typed, autocompleted, refactorable
- Changes ship in the next build, no Figma sync ceremony
- One source of truth for every spacing decision

Curious how others are handling design systems in pure SwiftUI. Anyone using `@Environment` for theming, or sticking with namespaced enums?

**Where to post:** [r/SwiftUI](https://www.reddit.com/r/SwiftUI)
**Notes:** This subreddit loves code snippets. Add a screenshot of the app showing the design system in action. Promote via comments only, not the body.

---

## 3. r/SideProject — launch story

**Title:** After a year of building, I shipped Gimme — a wishlist app that doesn't make your friends sign up

**Body:**
Today I submitted my first solo iOS app for review. It's called Gimme.

**The problem I kept hitting:**
- Notes app graveyards full of "things I want"
- Screenshot folders with no context
- Awkwardly sending people Amazon links when they ask what I want for my birthday
- Duplicate gifts at group occasions

**What I built:**
A wishlist app where you save items from any app via the iOS Share Extension (Safari, Instagram, anywhere — the URL is auto-parsed for title, image, price). You organize into named lists. You share a list via link, and your friends can claim items *without creating an account* — they just see the list on a web page.

**The constraint that drove most of the design:**
Asking people to sign up to view a wishlist kills the loop. So the gifter side is fully account-free: open link → see list → claim item → owner gets a push notification saying "someone reserved something" without specifying what (preserves surprise).

**Stack for the curious:**
SwiftUI + SwiftData + Supabase (Postgres, Realtime, Edge Functions for push) + Next.js on Vercel for the share pages.

**What I learned:**
- Scope discipline. Every feature not built is a feature that can't break.
- The most important UX decisions were technical (Share Extension, metadata pipeline, Realtime claims).
- Solo full-stack iOS + web + backend is doable but ruthless prioritization is non-negotiable.
- App Store screenshots took longer than I expected. Plan a full week for listing prep.

Free with unlimited lists/items. Pro is one-time $4.99 (no subscription) for unlimited sharing and the stats dashboard.

Happy to answer anything.

**Where to post:** [r/SideProject](https://www.reddit.com/r/SideProject)
**Notes:** Linking is allowed but launch posts do best with one inline link near the bottom. Add a 30-second screen recording if possible.

---

## 4. r/indiehackers — business angle

**Title:** Why I priced my iOS wishlist app at $4.99 lifetime instead of a subscription

**Body:**
Just shipped Gimme, a wishlist + gifting app. Wanted to talk about the pricing decision because I see a lot of indie devs default to subscriptions.

**The framework I used:**
1. Is the value continuous or one-shot? (continuous = sub, one-shot = lifetime)
2. Does the app have ongoing infrastructure costs per user? (yes = sub helps, no = sub is friction)
3. Is the user using it daily, weekly, or seasonally? (seasonal = subs feel extractive)

**For a wishlist app, all three pointed to lifetime:**
- Value is the *capability*, not ongoing content
- Backend costs are real but small per user (Supabase + Vercel free tiers cover the first thousands)
- Usage spikes around birthdays/holidays — a sub feels punishing during slow months

**Free tier:**
Unlimited lists, items, sync, widgets, Siri, Share Extension. Sharing capped at 2 lists.

**Why cap at 2 instead of 0:**
Sharing is the viral acquisition mechanic. Every shared list is a public landing page. Capping after the user has felt the value, not before, converts free users instead of frustrating them.

**Pro ($4.99 lifetime):**
- Unlimited shared lists
- Stats dashboard with currency conversion across 9 currencies
- All future features

**The tradeoff I'm accepting:**
LTV is capped. A successful subscription model would 5–10x revenue per converted user. But conversion rate on lifetime is much higher, refund rate is lower, and the trust signal ("I'm not nickel-and-diming you") matters for word-of-mouth in a category where switching cost is low.

I'll report back in 90 days with actual conversion numbers if there's interest.

**Where to post:** [r/indiehackers](https://www.reddit.com/r/indiehackers)
**Notes:** This subreddit values numbers and frameworks over launch announcements. Lead with the pricing thesis, app is the case study.

---

## 5. r/giftideas — problem-first (low promo)

**Title:** Anyone else hate the "what do you want for your birthday?" question?

**Body:**
Every year someone asks what I want and I blank. The things I actually want are scattered across:
- Screenshot folders
- Browser bookmarks
- Random Notes app entries
- Mental notes I forgot

And when I do send a list, it's a pasted Amazon link or a few text messages. Feels transactional.

The other half of the problem: when *I* try to gift well, I save ideas in random notes and forget about them by December.

How do you all handle this? Specifically:
1. Where do you keep "things I want" so it's actually useful when someone asks?
2. How do you coordinate group gifts so you don't end up duplicating with someone else?
3. Do you tell people what you got them ahead of time, or preserve the surprise?

I ended up building an app for my own version of this problem (link in comments if anyone wants), but I'm honestly more curious how non-app people solve it. Spreadsheets? Shared Notes? A group chat?

**Where to post:** [r/giftideas](https://www.reddit.com/r/giftideas), also try [r/SecretSanta](https://www.reddit.com/r/SecretSanta), [r/ChristmasGifts](https://www.reddit.com/r/ChristmasGifts)
**Notes:** Do NOT put the app link in the body — only drop it in a comment if someone asks. These subs ban or shadow self-promo aggressively. The post must work as a genuine question. Best timing: Oct–Dec for holiday subs, year-round for r/giftideas.

---

## 6. r/apple — feature-led app showcase

**Title:** I built a wishlist app that uses Share Extension, Widgets, Siri Shortcuts, and Spotlight — every iOS surface I could find

**Body:**
Wanted to share what's possible when you actually use the iOS surfaces that most apps ignore. My app is a wishlist tracker but the interesting part isn't the wishlist — it's the integration depth.

**Share Extension** — "Save to Gimme" appears in any app's share sheet (Safari, Instagram, Amazon, anywhere). Tap once, the app opens with the URL pre-filled and the product details auto-extracted (title, image, price, currency).

**Widgets** — small home screen, medium home screen with top 3 items, lock screen widget showing your highest-priority wish. No app open required.

**Siri Shortcuts** (5 of them):
- "What's on my birthday list?" — readout
- "Add AirPods to my tech list" — voice capture
- "How much is left on my wishlist?" — total spoken
- Plus open list and quick stats

**Spotlight Search** — every list and every item is indexed. Pull down on the home screen, type "headphones," your saved item shows up.

**Universal Links** — share a list link, if the recipient has the app it opens directly in Gimme. If not, they see a clean Next.js page.

**Why I cared:** A wishlist app that lives only behind an icon has weak recall. The widgets and Siri make the list ambient. Passive visibility creates the habit loop without requiring deliberate opens.

The whole thing is a love letter to iOS-as-platform.

**Where to post:** [r/apple](https://www.reddit.com/r/apple), [r/iphone](https://www.reddit.com/r/iphone), [r/ios](https://www.reddit.com/r/ios)
**Notes:** r/apple has strict self-promo rules — your post needs >90% of your account activity to NOT be self-promo. r/iphone is more permissive. Post a screenshot or short video. Don't link the App Store directly; let people search the name.

---

## 7. r/InternetIsBeautiful — public web share angle

**Title:** Wishlist sharing that doesn't require the recipient to sign up for anything

**Body:**
Built a small thing: when you share a wishlist, the recipient gets a clean public web page where they can see items and quietly mark what they're getting — no account, no download, no signup wall.

The page generates a custom Open Graph preview image so when shared in iMessage, Slack, or Twitter, it shows the actual list with item count and total value.

The technical bit I'm proud of: the owner gets a push notification saying "someone reserved something" but the app deliberately doesn't tell them *what*, to preserve gift surprise.

**Where to post:** [r/InternetIsBeautiful](https://www.reddit.com/r/InternetIsBeautiful)
**Notes:** This sub requires a *public, non-paywalled* link. Post a public share-page URL (not the App Store). Avoid promoting the iOS app directly — the *web page* is the artifact. Mods are strict about commercial content.

---

## 8. r/ClaudeAI — built with Claude Code

**Title:** Shipped a full iOS + web + backend app built with Claude Code — what worked and what didn't

**Body:**
Just submitted my first solo app to the App Store. ~67 Swift files, a Next.js web app, Supabase backend, share extension, widgets, Siri intents. Built almost entirely with Claude Code as the pair programmer.

**What worked well:**
- Architecture conversations before code. I'd describe the data model and constraints, get back a few approaches with tradeoffs, pick one. Saved me from at least three migrations.
- SwiftUI scaffolding. Claude is genuinely strong at SwiftUI layout and modifier chains.
- Supabase migrations. Walked through schema, RLS policies, RPC functions. Caught permission edge cases I would've missed.
- Multi-strategy parsing logic for URL metadata extraction (JSON-LD → OG → Microdata → heuristics). The kind of fallback chain that's tedious to write by hand.

**What needed pushback:**
- Default verbosity. Comments on every line, defensive guards everywhere. I had to keep saying "less abstraction, less commentary."
- Over-engineering. Suggested generic protocols and base classes for things that needed three concrete cases. Had to actively prune.
- Confidence on platform-specific iOS APIs that have changed recently — App Intents, WidgetKit. Verify against current Apple docs.

**My workflow:**
- Plan in plain English first, no code
- Implement one feature end-to-end
- Refactor *after* it works, not during
- Keep a `CLAUDE.md` with conventions so it doesn't regress

The metadata extraction pipeline alone would've taken me a week solo. With Claude it was an afternoon.

**Where to post:** [r/ClaudeAI](https://www.reddit.com/r/ClaudeAI), [r/ChatGPTCoding](https://www.reddit.com/r/ChatGPTCoding) (broader AI-dev audience)
**Notes:** These subs love specifics. Avoid hype. The "what didn't work" section is what gets upvotes — pure success stories read as ads.

---

## 9. r/buildinpublic — build journey

**Title:** A year of building solo, here's what I shipped (full-stack iOS + web + backend)

**Body:**
Hit "submit for App Review" today. Wanted to do a transparent write-up while it's fresh.

**Final scope:**
- 67 Swift source files, 10 feature screens
- 12 backend services
- 3 widget sizes (small, medium, lock screen)
- 5 Siri Shortcuts
- 1 Share Extension
- 7 web pages (marketing + dynamic share pages with OG images)
- 9 currencies supported with auto-conversion

**Time breakdown (rough):**
- Planning + design system: 2 weeks
- Core SwiftUI + SwiftData: 6 weeks
- Supabase backend, auth, sync: 4 weeks
- Share Extension + metadata pipeline: 2 weeks
- Widgets + Siri + Spotlight: 2 weeks
- Web app + share pages: 3 weeks
- Push notifications via Edge Functions: 1 week
- StoreKit 2 + Pro tier: 1 week
- App Store assets, listing, screenshots: 1 week
- Polish, bugs, edge cases: ongoing

**Decisions I'd make again:**
- Local-first with SwiftData. App is instant.
- Lifetime pricing instead of subscription.
- Account-free recipient flow on shared lists. The viral mechanic depends on it.
- Code-first design system in `Theme.swift`.

**Decisions I'd revisit:**
- Started with CoreData, migrated to SwiftData. Just start with SwiftData.
- Underestimated App Store listing prep. Plan a week.
- Should have written more snapshot tests for the layout-heavy SwiftUI views.

**What's next:**
Web share page polish (it's the #1 viral surface), price drop tracking for Pro, group gifting flows.

Will post conversion numbers in 90 days.

**Where to post:** [r/buildinpublic](https://www.reddit.com/r/buildinpublic), [r/IndieDev](https://www.reddit.com/r/IndieDev), [r/EntrepreneurRideAlong](https://www.reddit.com/r/EntrepreneurRideAlong)
**Notes:** Numbers and timelines do well. Avoid linking heavily — let people DM or search.

---

## 10. r/Frugal — practical angle

**Title:** I track everything I want before I buy it — here's why it cut my impulse spending

**Body:**
A habit that's saved me real money: I never buy something the moment I want it. I add it to a list and revisit a week later.

About 60% of the time, I don't actually want it anymore. The dopamine of "saving for later" replaces the dopamine of buying.

**My rules:**
1. Anything over $30, mandatory week-long cool-off
2. Anything over $100, two weeks
3. Items get a priority tag — High / Medium / Low. Anything that's been Low for a month gets archived.
4. I track total wishlist value. Watching it grow forces me to ask "is this $1,200 of stuff actually worth it?"

**Tools that work:**
- iOS Notes with a section per category
- A spreadsheet if you like spreadsheets
- I ended up building my own app because I wanted price tracking and auto-fill from URLs, but the system is what matters, not the tool

The unlock isn't *what* you use, it's the *delay*. Adding the friction of "save it first" is enough to break most impulse buys.

What tricks do you all use to avoid impulse purchases?

**Where to post:** [r/Frugal](https://www.reddit.com/r/Frugal), [r/personalfinance](https://www.reddit.com/r/personalfinance) (no app link), [r/povertyfinance](https://www.reddit.com/r/povertyfinance)
**Notes:** Strict no-promo rules. The app reference must be incidental and you should NOT link it. If a commenter asks, drop the name in a reply, no URL.

---

## Posting schedule suggestion (one week)

| Day | Subreddit | Post # |
|---|---|---|
| Mon | r/SideProject | 3 |
| Tue | r/iOSProgramming | 1 |
| Tue | r/SwiftUI (later in day) | 2 |
| Wed | r/indiehackers | 4 |
| Wed | r/buildinpublic | 9 |
| Thu | r/ClaudeAI | 8 |
| Fri | r/apple OR r/iphone | 6 |
| Sat | r/Frugal | 10 |
| Sun | r/giftideas | 5 |
| Anytime | r/InternetIsBeautiful (with public web URL) | 7 |

**Engagement playbook:**
- Reply to every comment in the first 2 hours
- Don't be defensive on critique — thank, integrate, move on
- If a post flops in 30min (under 5 upvotes), don't delete; let it ride
- Cross-posting same exact text triggers spam filters — rewrite each one
