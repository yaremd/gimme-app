# Gimme — App Functionality Reference

**App Display Name:** Gimme  
**Bundle ID:** `com.yaremchuk.app`  
**Platform:** iOS 17.0+  
**Architecture:** SwiftUI + SwiftData + Supabase  

---

## App Overview

Gimme is a wishlist manager that lets users curate, organize, and track items they want. Lists and items sync across devices via Supabase. The app works fully offline (local-only mode) and optionally connects an account for cloud sync and sharing.

---

## Data Models

### WishList
| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `name` | String | List name |
| `emoji` | String | Emoji icon |
| `colorHex` | String | Hex color for the list card |
| `createdAt` | Date | Creation timestamp |
| `updatedAt` | Date | Last modified (used for sync conflict resolution) |
| `isPinned` | Bool | Pinned lists appear first on Home |
| `isArchived` | Bool | Archived lists are hidden by default |
| `isShared` | Bool | Whether the list has been shared publicly |
| `shareToken` | String? | Token used to generate a public share URL |
| `ownerID` | String? | Supabase user ID of the owner |
| `items` | [WishItem] | One-to-many, cascade delete |

Computed: `itemCount`, `unpurchasedCount`, `shareURL`, `shareText`

### WishItem
| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `title` | String | Item name |
| `notes` | String | Optional description or notes |
| `url` | String | Link to the product page |
| `imageURL` | String | Remote image URL |
| `imageData` | Data? | Locally stored image (external storage) |
| `price` | Decimal | Item price |
| `currency` | String | ISO currency code (e.g. "USD") |
| `priority` | Priority | `.low`, `.medium`, `.high` |
| `isPurchased` | Bool | Purchased/wanted toggle |
| `isReservedByFriend` | Bool | Whether a friend has reserved this item |
| `reservedByName` | String | Name of the person who reserved it |
| `endDate` | Date? | Optional deadline/event date |
| `notificationsEnabled` | Bool | Whether to schedule a reminder |
| `isPinned` | Bool | Pinned items appear first in a list |
| `isArchived` | Bool | Hidden from list by default |
| `createdAt` / `updatedAt` | Date | Timestamps |
| `list` | WishList | Back-reference to parent list |

Computed: `shareText`

### Priority Enum
| Value | Label | Icon |
|-------|-------|------|
| `.low` | Low | `arrow.down.circle` |
| `.medium` | Medium | `minus.circle` |
| `.high` | High | `arrow.up.circle` |

---

## Screens & Features

### Authentication (`AuthView`)
- Toggle between **Sign In** and **Sign Up** modes
- Fields: email, password, confirm password (sign-up only)
- **Forgot Password** flow via alert (sends reset email)
- **Continue without account** — skips auth, uses local-only mode
- Glassmorphism UI with gradient background

### Home Screen (`HomeView`)
- Displays all wishlists as cards
- **Pinned lists** appear at the top; rest sorted newest-first
- **Hero section** shows total remaining value across all lists in selected currency
- **Search overlay** — full-text search across list names and item titles/notes/URLs
- **FAB** (floating action button) to create a new list
- **Swipe actions** per list card: pin/unpin, edit, archive, delete
- **Context menu** per list card: share, edit, change color, pin, archive
- Tapping a card navigates to List Detail
- Handles **Share Extension hand-off** — detects URL passed via UserDefaults from the share extension and opens the Add Item sheet pre-filled

### New / Edit List (`NewListView`)
- Name input
- **Emoji picker** — 50+ emoji options
- **Color picker** — 10 preset colors for the card background
- Animated "Customize" overlay with matched geometry transitions
- Creates or updates a `WishList` in SwiftData (syncs if signed in)

### List Detail (`WishListDetailView`)
- Header: list emoji, name, color-accented
- **Filter bar**: All · Wanted · Purchased
- **Stats strip**: total items, wanted count, purchased count, total value
- **Sort options**: Date Added, Priority, Name (alphabetical)
- Toggle to **show/hide archived items**
- Item cards with thumbnail, title, price, priority badge, purchased state
- **Swipe actions** per item: pin/unpin, edit, archive, delete
- **Context menu** per item: mark purchased/wanted, pin, archive, share, delete
- **FAB** to add a new item to this list
- Navigates to Item Detail on tap

### Add / Edit Item (`AddItemView`)
- **URL field** with "Fetch" button — auto-populates title, image, price, description via metadata extraction
- **Image selection**: camera, photo library, or emoji-as-image picker
- Title, notes, URL, price, currency fields
- **Priority selector**: Low / Medium / High chips
- **Optional end date** + notification toggle (schedules a local reminder)
- Full edit support for existing items
- Pre-fills URL when opened from the Share Extension

### Item Detail (`WishItemDetailView`)
- Large hero image (remote URL or local data)
- Title, priority badge, price
- **Status button**: Mark as Purchased / Mark as Wanted (toggles `isPurchased`)
- Notes display
- List name badge (which list this item belongs to)
- **URL row** opens the link in the browser (Copy Link is in the ••• menu)
- **Share item** via system share sheet
- **Delete** with confirmation dialog
- Metadata: creation date

### Stats / Analytics (`StatsView` + `StatsViewModel`)
- **Overview strip**: total lists, total items, bought count, wanted count
- **Interactive donut chart** — tap or swipe segments to highlight
- **Group by**: Priority or List
- **Filter by list** — focus chart on a single list
- **Display currency** selector — converts all prices using FX rates
- **Value breakdown**: Total Value, Purchased Value, Remaining Value
- Legend with segment labels and percentages
- Gesture support: swipe left/right to cycle through chart segments

### Settings (`SettingsView`)
- **Account section**: shows signed-in email or sign-in prompt; sign-out button
- **Sync status**: last synced time, manual sync trigger
- **Pro banner** (placeholder for future premium tier)
- **Preferences**:
  - Main currency (ISO code selector)
  - Rounding toggle (round displayed prices)
  - Abbreviate numbers toggle (e.g. $1.2K)
  - Appearance: System / Light / Dark
- **Notifications** toggle (requests permission, enables/disables scheduling)
- Currency rates section (placeholder for live API)
- **Links**: Rate the App, Share the App, Contact
- Footer: creator credit, app version

---

## Sync & Backend

### Supabase Integration (`SupabaseManager`, `SyncService`)
- **Backend**: Supabase (PostgreSQL + Auth + Realtime)
- **Tables**: `wish_lists`, `wish_items`
- **Strategy**: last-write-wins via `updatedAt` timestamps
- Full sync triggered on sign-in and when app becomes active
- **Throttled**: max one sync per 60 seconds
- `syncAll()` — upserts local records to remote, pulls remote changes
- `deleteList()` / `deleteItem()` — removes from both local SwiftData and Supabase
- Binary image data excluded from sync (planned for Phase 4 via Supabase Storage)

### Conflict Resolution
- Both local and remote records carry `updatedAt`
- The more recent timestamp wins on merge

### Offline-First
- All data lives in SwiftData locally
- App is fully functional without a network connection or account
- Sync is additive — signs in and catches up

---

## Share Extension (`GimmeShare`)

- System share action: **"Save to Gimme"**
- Appears in any app's share sheet when sharing a URL
- Passes the URL to the main app via **App Groups** (`group.com.yaremchuk.app`) using `UserDefaults`
- Main app detects the pending URL on launch/foreground and opens the **Add Item** sheet pre-filled with the URL (metadata auto-fetched)
- User selects which wishlist to save the item to via a **list picker sheet**

---

## Notifications (`NotificationService`)

- Uses `UNUserNotificationCenter` (local notifications only)
- **Permission request** on first use
- **Schedule**: fires at **9:00 AM, 1 day before** the item's end date
- Keyed on item UUID — scheduling again replaces the prior request
- `requestPermission()`, `schedule(for item:)`, `cancel(for item:)`

---

## URL Metadata Extraction (`MetadataService`)

- Fetches a product URL and parses:
  - **Title** (Open Graph `og:title` → `<title>`)
  - **Image** (`og:image`)
  - **Price** (JSON-LD, meta tags, `og:price:amount`)
  - **Currency** (`og:price:currency`)
  - **Description** (`og:description`)
- Uses Desktop Safari User-Agent to avoid mobile redirects
- Handles URL encoding and redirect chains
- Special handling for App Store links
- Returns `ItemMetadata` struct

---

## Image Handling

| Source | How |
|--------|-----|
| Remote URL | Loaded via `AsyncImage` with shimmer placeholder |
| Photo Library | `PhotosPicker` (PhotosUI) |
| Camera | `UIImagePickerController` (AVFoundation) |
| Emoji | Emoji rendered to `UIImage`, stored as `Data` |

- Local images stored via SwiftData `@Attribute(.externalStorage)`
- Remote image URLs stored as strings and loaded on demand

---

## Currency & Pricing

- Each item stores a `price` (Decimal) and `currency` (ISO code)
- **Static FX rate table** used for conversion (placeholder — live API planned)
- `convertCurrency(amount:from:to:)` utility in `Extensions.swift`
- `Decimal.formatted(currency:)` respects:
  - Rounding preference
  - Abbreviation preference (K/M suffixes)
- Stats view converts all items to a selected display currency for totals

---

## Design System (`Theme.swift`)

### Colors
| Name | Value | Usage |
|------|-------|-------|
| Accent | `#6C63FF` | Primary interactive elements |
| Purchased | Green | Purchased state indicators |
| Destructive | Red | Delete actions |
| 10 preset list colors | Various | Wishlist card backgrounds |

Adaptive light/dark mode variants for backgrounds and labels.

### Spacing Scale
| Token | Value |
|-------|-------|
| `xs` | 4 pt |
| `sm` | 8 pt |
| `md` | 12 pt |
| `lg` | 16 pt |
| `xl` | 24 pt |

### Corner Radii
| Usage | Value |
|-------|-------|
| Card | 20 pt |
| Sheet | 28 pt |
| Button | 14 pt |
| Badge | 8 pt |

### Animations
- Spring physics with tuned response/damping values
- Matched geometry transitions (emoji/color picker overlays)

### Key Components
- `WishListCard` — list preview card (emoji, name, color, progress)
- `WishItemCard` — item row (thumbnail, title, price, priority badge)
- `PriorityBadge` — icon + label chip for priority level
- `AsyncImageView` — remote image loader with shimmer
- `EmptyStateView` — reusable empty state with icon and message
- `ShareSheetView` — `UIActivityViewController` SwiftUI wrapper
- `primaryGlassBackground()` — frosted glass view modifier

---

## Navigation Flow

```
WhishApp
└── ContentView (applies color scheme preference)
    └── HomeView
        ├── NewListView (sheet) — create list
        ├── ColorPickerSheet (sheet) — change list color
        ├── ShareListPickerView (sheet) — Share Extension hand-off
        ├── StatsView (sheet, medium/large detent)
        ├── SettingsView (sheet, large detent)
        │   └── AuthView (sheet) — sign in / sign up
        └── WishListDetailView (NavigationStack push)
            ├── AddItemView (sheet) — add/edit item
            ├── NewListView (sheet) — edit list
            └── WishItemDetailView (NavigationStack push)
```

Deep link scheme: `gimme://`

---

## Planned Future Features

| Phase | Feature |
|-------|---------|
| Phase 3 | Participants — tag who items are for; shared gifting flows |
| Phase 4 | Binary image sync via Supabase Storage |
| Future | Live currency rate API (replace static FX table) |
| Future | iCloud backup option |
| Future | Pro / premium tier |
| Future | Public list sharing via share token |
