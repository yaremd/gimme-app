# Whish.list — iOS App: Claude Code Kickoff Prompt

## Context

I'm building a native iOS wishlist app called **Whish** (working name). The design inspiration is the app "Subscription Day Calendar" — clean, minimal, beautiful SwiftUI with smooth animations, soft card UIs, and a polished App Store-ready aesthetic. Think calm, premium, and delightful.

We've already done the planning phase. This prompt is the handoff into actual development. Please scaffold and build Phase 1 of the app as described below.

---

## App Overview

**Whish** is a personal + shareable wishlist app. Users save items they want (by pasting a URL or manually), organize them into named lists, share lists with friends, and let friends quietly mark items as "I'll gift this." Pro users get price drop notifications and home screen widgets.

---

## Tech Stack

- **Language:** Swift 6
- **UI:** SwiftUI (100% — no UIKit unless absolutely necessary)
- **Local persistence:** SwiftData
- **Backend:** Supabase (Postgres + Auth + Realtime + Edge Functions) — integrate later in Phase 2
- **IAP:** RevenueCat — integrate later in Phase 5
- **Minimum deployment target:** iOS 17
- **Xcode:** Latest stable

---

## Data Models (SwiftData — Phase 1)

```swift
@Model class WishList {
    var id: UUID
    var name: String           // e.g. "Birthday 🎂", "Tech Gear"
    var emoji: String          // list icon
    var colorHex: String       // accent color for the card
    var createdAt: Date
    var items: [WishItem]
    var isShared: Bool         // whether a share link has been generated
    var shareToken: String?    // unique token for the share URL
}

@Model class WishItem {
    var id: UUID
    var title: String
    var notes: String?
    var url: String?           // original product URL
    var imageURL: String?      // OG image
    var price: Decimal?        // current price
    var currency: String?      // "USD", "EUR", etc.
    var priority: Priority     // enum: .low .medium .high
    var isPurchased: Bool
    var isReservedByFriend: Bool  // someone said "I'll gift this"
    var reservedByName: String?
    var createdAt: Date
    var list: WishList
}

enum Priority: String, Codable {
    case low, medium, high
}
```

---

## Phase 1 Scope — Build This Now

### Goals
Get a beautiful, fully functional local app (no backend yet). Everything persists via SwiftData. This phase is about nailing the UX and visual quality.

### Screens to Build

#### 1. Home Screen — My Lists (`HomeView`)
- Tab bar item: "Lists" with a list icon
- Shows a **2-column card grid** of `WishList` objects
- Each card shows: emoji, list name, item count, accent color background, soft shadow
- Empty state: friendly illustration + "Create your first wishlist" CTA
- FAB (floating action button) or toolbar "+" to create a new list
- Long press on a card → context menu: Rename, Change Color, Delete

#### 2. New List Sheet (`NewListView`)
- Sheet modal
- Text field for list name
- Emoji picker (grid of common emojis)
- Color picker (row of 8–10 preset pastel/vibrant swatches)
- "Create" button (disabled until name is not empty)

#### 3. List Detail (`WishListDetailView`)
- Navigation title = list name + emoji
- Vertical scroll of `WishItemCard` components
- Sort/filter toolbar: All | Wanted | Purchased
- Each card shows: product image (or placeholder), title, price, priority badge, purchased checkmark
- Swipe left → Delete; Swipe right → Mark as Purchased
- FAB "+" to add a new item
- Empty state: "Nothing here yet — add your first wish ✨"

#### 4. Add/Edit Item Sheet (`AddItemView`)
- **URL field at the top** — when user pastes a URL and taps "Fetch", call a placeholder async function `MetadataService.fetch(url:)` that for now returns mock data (we'll wire it to a real Edge Function in Phase 2)
- Fields: Title (required), Notes (optional), Price, Currency picker, Priority picker (Low / Medium / High), URL (pre-filled)
- Image preview if imageURL is set
- "Save" button

#### 5. Item Detail (`WishItemDetailView`)
- Full-screen modal or pushed view
- Large image at top (AsyncImage with shimmer placeholder)
- Title, notes, price
- Priority badge
- "Open in Browser" button (if URL set)
- "Mark as Purchased" toggle
- Edit button → opens `AddItemView` pre-filled
- Delete button

#### 6. Settings Screen (`SettingsView`)
- Tab bar item: "Settings" with gear icon
- Sections: Appearance (Light/Dark/System), About, Rate the App (placeholder), Upgrade to Pro (placeholder banner)

---

## Navigation Structure

```
TabView
├── Tab 1: HomeView (My Lists)
│   └── NavigationStack
│       └── WishListDetailView
│           └── WishItemDetailView
└── Tab 2: SettingsView
```

Sheets:
- `NewListView` — presented from HomeView
- `AddItemView` — presented from WishListDetailView

---

## Design System

Please define these as constants/tokens in a `DesignSystem.swift` or `Theme.swift` file:

**Typography**
- Large title: SF Pro Rounded, Bold, 34pt
- Title: SF Pro Rounded, Semibold, 22pt
- Body: SF Pro, Regular, 17pt
- Caption: SF Pro, Regular, 13pt, secondary color

**Colors** (support both light and dark mode)
- Background: system background
- Card background: secondary system background
- Accent: `#6C63FF` (soft purple — can be overridden per list)
- Destructive: system red
- Text primary: label
- Text secondary: secondary label

**Shape**
- Card corner radius: 20pt
- Sheet corner radius: 24pt
- Button corner radius: 14pt

**Spacing**
- Grid padding: 16pt
- Card inner padding: 16pt
- Card gap: 12pt

**Animations**
- Use `.spring(response: 0.4, dampingFraction: 0.75)` for all transitions
- Smooth appear/disappear for sheets

---

## Code Quality Requirements

- Use `@Observable` macro (Swift 5.9+) for view models
- Each screen gets its own ViewModel: `HomeViewModel`, `ListDetailViewModel`, etc.
- Use `async/await` throughout — no callbacks
- `MetadataService` should be a protocol with a mock implementation for Phase 1 and a real Supabase implementation in Phase 2
- All SwiftData queries go through the ViewModel, not directly in Views
- Avoid massive View files — extract subviews aggressively into separate files
- Support both light and dark mode from day one
- Fully support Dynamic Type

---

## File Structure

```
Whish/
├── App/
│   ├── WhishApp.swift
│   └── ContentView.swift (TabView root)
├── Models/
│   ├── WishList.swift
│   ├── WishItem.swift
│   └── Priority.swift
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   ├── WishListCard.swift
│   │   └── NewListView.swift
│   ├── ListDetail/
│   │   ├── WishListDetailView.swift
│   │   ├── ListDetailViewModel.swift
│   │   ├── WishItemCard.swift
│   │   └── AddItemView.swift
│   ├── ItemDetail/
│   │   ├── WishItemDetailView.swift
│   │   └── ItemDetailViewModel.swift
│   └── Settings/
│       └── SettingsView.swift
├── Services/
│   ├── MetadataService.swift       (protocol)
│   └── MockMetadataService.swift   (Phase 1 mock)
├── Design/
│   ├── Theme.swift
│   ├── Typography.swift
│   └── Components/
│       ├── PriorityBadge.swift
│       ├── AsyncImageView.swift    (with shimmer)
│       └── EmptyStateView.swift
└── Utilities/
    └── Extensions.swift
```

---

## Mock Data for Development

Please include a `PreviewData.swift` with rich sample data:
- 4 wishlists with different emojis and colors: "Birthday 🎂", "Tech Gear 💻", "Home 🏠", "Books 📚"
- 3–5 items per list with varying priorities, some marked purchased, with placeholder imageURLs using `picsum.photos`

---

## What I Need You to Do

1. Create the Xcode project structure with the file layout above
2. Implement all 6 screens with real, polished SwiftUI code
3. Wire up SwiftData so all changes persist across app launches
4. Use the design tokens from `Theme.swift` consistently everywhere
5. Add `#Preview` macros to every View using `PreviewData`
6. Make sure the app builds and runs cleanly with no warnings

Start by creating the project scaffold and `Models/`, then work screen by screen starting with `HomeView`.

---

## Future Phases (for context — don't build yet)

- **Phase 2:** Supabase Auth (Sign in with Apple), cloud sync, real `MetadataService` using a Supabase Edge Function that fetches OpenGraph data from product URLs
- **Phase 3:** Sharing via Universal Links, gifting/reservation system, Realtime updates
- **Phase 4:** Price tracking via pg_cron + APNs push notifications, price history chart
- **Phase 5:** RevenueCat paywall, WidgetKit home screen widget, App Store submission

---

*Design reference: "Subscription Day Calendar" on the App Store — minimal, card-based, smooth, iOS-native feel. That's the bar.*
