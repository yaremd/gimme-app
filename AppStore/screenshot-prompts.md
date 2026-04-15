# Gimme App Store Screenshots — Image Generation Prompts

## General Style Guide (apply to ALL screenshots)

**Device:** iPhone 15 Pro Max, Natural Titanium finish, portrait orientation, slightly angled (2-3 degrees tilt for depth), floating with soft shadow beneath
**Frame style:** Realistic device render with thin titanium bezels, Dynamic Island visible, screen-on with full brightness
**Background:** Full-bleed gradient filling entire 1290x2796 canvas, subtle grain/noise texture overlay (2-3% opacity) for premium feel
**Caption font:** San Francisco Pro Rounded (or similar geometric rounded sans-serif), Extra Bold (800 weight), pure white, large size (~1/6 of canvas width per character), tight line-height (1.05), centered above device
**Sub-caption:** Same font family, Medium weight (500), white at 70% opacity, positioned directly below caption with 24px gap
**Composition:** Caption in top 30% of canvas, device centered in lower 70%, device cropped at bottom showing ~80% of the phone (bottom edge hidden), no other decorative elements — clean and minimal
**Lighting:** Soft studio lighting from upper-left, subtle screen glow reflecting on device bezels
**Quality:** Ultra-sharp 4K render, no artifacts, App Store ready at 1290x2796px

---

## Screenshot 1 — Home Screen

**Caption:** "All your wishes, one beautiful place"
**Sub-caption:** "Save, organize & share wishlists"
**Background gradient:** Rich indigo to deep purple (#8B7FFF top → #6C63FF middle → #4A3FD4 bottom), 170-degree angle

**On-screen UI:**
Warm cream background (#F5F0E8 to #EDE6D8 vertical gradient). Status bar showing "9:41" on left, signal/wifi/battery on right. Dynamic Island centered at top.

Navigation area: Large bold "Gimme" title in dark text (#2C2C2E) on the left, small indigo (#6C63FF) search icon on the right.

Five wishlist cards stacked vertically with 10px gaps. Each card is a white rounded rectangle (#FFFDF6, 20px corner radius, subtle shadow: 12px blur, 4px Y offset, 8% opacity). Each card has:
- Left: circular emoji badge (emoji on a tinted background matching the list color at 15% opacity, 28px corner radius)
- Middle: bold list name + lighter "X of Y remaining" subtitle
- Right: price in the list's color + "N items" count below

Card 1: Birthday cake emoji, "Birthday Wishes", "5 of 8 remaining", "$245" in rose (#E8586D), "8 items"
Card 2: Laptop emoji, "Tech Gear", "5 of 5 remaining", "$1,299" in ocean blue (#3B8DD4), "5 items"
Card 3: Books emoji, "Books to Read", "All purchased!" in green (#30D158), "$89" in honey (#D4A017), "3 items"
Card 4: Christmas tree emoji, "Holiday Ideas", "12 of 15 remaining", "$430" in emerald (#2EAA5F), "15 items"
Card 5: House emoji, "Home Decor", "2 of 4 remaining", "$175" in violet (#8B5CF6), "4 items"

Bottom-right corner: floating action button — indigo (#6C63FF) rounded square (34px radius) with white "+" icon, soft indigo glow shadow beneath.

---

## Screenshot 2 — Share Extension

**Caption:** "Save from any app in one tap"
**Sub-caption:** "Auto-detects name, image & price"
**Background gradient:** Rose red to deep crimson (#F07080 top → #E8586D middle → #C4384E bottom), 170-degree angle

**On-screen UI:**
Safari browser view on light gray background (#F2F2F7). Safari URL bar at top showing "amazon.com/dp/B0CS5P1..." in a rounded gray pill.

Product page visible behind: large product image area showing premium wireless headphones (Sony WH-1000XM5 style — over-ear, matte black/silver, sleek). Product title "Sony WH-1000XM5 Wireless Noise Cancelling Headphones" in dark text. Price "$278.00" in large bold text with "$399.99" struck through next to it in gray.

iOS Share Sheet overlay covering bottom 55% of screen:
- Frosted glass white background with slight transparency, top rounded corners (28px radius)
- Small gray drag handle pill centered at top
- Header: "amazon.com" in gray text, truncated product title below
- Horizontal row of share app icons: Messages (green), Mail (blue), Notes (orange), Reminders (purple) — each as rounded square icons with labels below
- Below: vertical action list with icon + label rows
- "Add to Reading List" with blue icon — normal styling
- **"Save to Gimme" — HIGHLIGHTED ROW**: slightly indigo-tinted background, indigo (#6C63FF) square icon with white star, "Save to Gimme" text in bold indigo — this row stands out clearly as the focal point
- "Copy Link" with gray icon below

---

## Screenshot 3 — Shared List (Web View)

**Caption:** "Share with anyone. No app needed."
**Sub-caption:** "Friends claim gifts. No spoiled surprises."
**Background gradient:** Ocean blue to deep blue (#5DA8E8 top → #3B8DD4 middle → #2A6FB5 bottom), 170-degree angle

**On-screen UI:**
Dark mode interface (deep navy gradient #17162C to #0C0C11). This represents the web sharing page that friends see in their browser — no Gimme app needed.

Header section centered: large birthday cake emoji (64pt), "Birthday Wishes" in white bold text (40px), "Shared by Dmytro · 8 items" in dim white below.

Four item cards stacked vertically. Each card is a dark glass-morphism rectangle (rgba white 6% background, 1px white 8% border, 40px radius, 28px padding). Each has:
- Left: square thumbnail area (100x100, rounded 24px, dark tinted background) with an emoji representing the product
- Right: product name in white, price in indigo (#6C63FF), and a button below

Card 1: Headphones emoji, "Sony WH-1000XM5", "$278.00", indigo pill button "I'll get this" with gift emoji
Card 2: Book emoji, "Atomic Habits", "$16.99", GREEN tinted pill button "Someone's getting this" with checkmark — this card has a subtle green border glow indicating it's been claimed
Card 3: Coffee cup emoji, "Fellow Stagg Kettle", "$89.00", indigo pill button "I'll get this"
Card 4: Game controller emoji, "Nintendo eShop Card", "$50.00", indigo pill button "I'll get this"

---

## Screenshot 4 — List Detail

**Caption:** "Track prices, priority & status"
**Sub-caption:** "Filter, sort, and organize your way"
**Background gradient:** Emerald green to deep forest (#45C87A top → #2EAA5F middle → #1E8A4A bottom), 170-degree angle

**On-screen UI:**
Warm cream background. Back arrow in indigo on the left, "Tech Gear" with laptop emoji as the title (bold, 40px), share icon on the right.

Filter chips row: three horizontal pills — "All" (filled indigo with white text, active), "Wanted" (light indigo tint, indigo text), "Purchased" (same inactive style). Below: "5 items · $1,299 total" in gray with a sort icon.

Five item rows, each a white card (same styling as home cards). Each has:
- Left: square product thumbnail (100x100, rounded, cream background) with product emoji
- Middle: product name (bold), price in ocean blue (#3B8DD4), priority badge
- Right: status circle (empty = outline, purchased = green filled with white checkmark)

Row 1: Headphones emoji, "AirPods Max", "$549.00", red "High" priority badge (red tinted background, red text with up arrow), empty circle
Row 2: Monitor stand emoji, "MacBook Stand", "$89.99" — ENTIRE ROW at 55% opacity with strikethrough text, yellow "Medium" priority badge, GREEN filled circle with white checkmark (purchased)
Row 3: USB plug emoji, "USB-C Hub 7-in-1", "$45.00", green "Low" priority badge (green tinted, down arrow), empty circle
Row 4: Keyboard emoji, "Keychron K2 Pro", "$199.00", purple "Reserved" badge with gift emoji (indigo tinted background), empty circle
Row 5: Mouse emoji, "Logitech MX Master", "$99.99", red "High" priority badge, empty circle

---

## Screenshot 5 — Widgets

**Caption:** "Widgets for your wishes"
**Sub-caption:** "Home Screen & Lock Screen"
**Background gradient:** Rich indigo to deep purple (#8B7FFF top → #6C63FF middle → #4A3FD4 bottom), 170-degree angle

**On-screen UI:**
Dark wallpaper (deep purple/navy gradient #2A1B5E to #0D0820) simulating an iPhone home screen.

**Top section — "HOME SCREEN" label in dim uppercase:**
Left side: Small widget (2x2 grid size, ~240px square). Frosted glass dark background with subtle white border. Contains:
- Top-left: tiny Gimme app icon (indigo square with star) + "GIMME" label in dim uppercase
- Center: "$245" in large white bold text
- Below: "3 of 8 remaining" in dim white
- Bottom: thin progress bar (indigo fill at 62% on dark track)

Right side: 4 blurred/faded app icon placeholders (2x2 grid) in muted colors (red, green, blue, orange) at 25% opacity — suggesting other apps on the home screen

**Middle: Medium widget (full width, 4x2 grid size).** Same frosted glass style. Contains:
- Top: tiny Gimme icon + "GIMME" label
- Three list rows:
  - Birthday cake emoji on rose-tinted circle → "Birthday" → "5/8" → "$245"
  - Laptop emoji on blue-tinted circle → "Tech Gear" → "5/5" → "$1,299"
  - Tree emoji on green-tinted circle → "Holiday" → "12/15" → "$430"

**Bottom section — "LOCK SCREEN" label in dim uppercase:**
Single inline widget: frosted glass pill (rounded, full width). Left: small indigo circle with white star icon. Middle: "Birthday Wishes" in white. Right: "5 left" in dim white.

---

## Screenshot 6 — Stats Dashboard

**Caption:** "See where your money goes"
**Sub-caption:** "Stats & insights across all wishlists"
**Background gradient:** Rose red to deep crimson (#F07080 top → #E8586D middle → #C4384E bottom), 170-degree angle

**On-screen UI:**
Warm cream background. "Stats" as the large bold nav title.

Filter chips: "By List" (active, filled indigo) and "By Priority" (inactive).

**Donut chart (280px diameter, centered):**
- Thick ring (32px stroke width) with 4 colored segments: rose (#E8586D ~30%), ocean blue (#3B8DD4 ~40%), honey (#D4A017 ~10%), emerald (#2EAA5F ~15%), remaining gray track
- Center: "$2,238" in large bold dark text, "Total value" in gray below
- Segments have slight gaps between them with rounded endpoints

**Overview strip (white card, full width):**
Four columns: "5 Lists", "35 Items", "12 Bought" (green number), "23 Wanted" (indigo number)

**Two stat cards side by side:**
Left: "Purchased" label in gray, "$846" in green (#30D158) bold
Right: "Remaining" label in gray, "$1,392" in indigo (#6C63FF) bold

**Breakdown section:**
"By List" title. Three horizontal bar rows:
- Laptop emoji → "Tech Gear" → "$1,299" → blue bar at 58%
- Tree emoji → "Holiday Ideas" → "$430" → green bar at 19%
- Cake emoji → "Birthday" → "$245" → rose bar at 11%
Each bar has a light gray track behind and a colored fill with rounded caps.

---

## Screenshot 7 — Siri Shortcuts

**Caption:** "Hey Siri, add a wish"
**Sub-caption:** "5 Siri Shortcuts built in"
**Background gradient:** Emerald green to deep forest (#45C87A top → #2EAA5F middle → #1E8A4A bottom), 170-degree angle

**On-screen UI:**
Warm cream background. "Shortcuts" as the large bold nav title.

**Siri suggestion bubble (top):**
Rounded card with very subtle indigo tint (rgba indigo 8% background, 1.5px indigo 15% border, 32px radius). Contains:
- Left: circular Siri gradient orb (rainbow gradient: indigo → purple → pink → orange, with soft glow shadow)
- Right: italic text "Add wish in Gimme" in dark color

**Section header:** "GIMME SHORTCUTS" in gray uppercase.

**Five shortcut cards stacked vertically.** Each is a white card (same card styling) with:
- Left: square icon (88px, rounded 24px, tinted background matching the icon color at 10% opacity) containing an SF Symbols-style line icon
- Middle: bold shortcut name + gray description below
- Right: small gray chevron (>)

Card 1: Indigo tint, house icon → "Open Wishlist" → "Jump to any list instantly"
Card 2: Green tint, plus icon → "Add Wish" → "Create a new wish with details"
Card 3: Orange tint, lightning bolt icon → "Quick Add" → "Save a wish in seconds"
Card 4: Blue tint, dollar sign icon → "Wishlist Total" → "How much is on your list?"
Card 5: Rose tint, bar chart icon → "View Stats" → "See spending insights"

---

## Screenshot 8 — Gimme Pro

**Caption:** "One price. Everything. Forever."
**Sub-caption:** "No subscriptions. No recurring fees."
**Background gradient:** Ocean blue transitioning to indigo (#3B8DD4 top → #5570D4 middle → #6C63FF → #4A3FD4 bottom), 170-degree angle

**On-screen UI:**
Dark mode (#1A1A1E to #0E0E12 gradient). Three large blurred color orbs floating in the background: purple orb top-left, orange orb middle-right, teal orb bottom-left — each at ~15% opacity with heavy gaussian blur (60px) creating an ambient glow effect.

**Header centered:** sparkle emoji (72pt), "Gimme Pro" in large white bold text (44px), "Unlock everything, forever" in dim white below.

**Four feature rows.** Each is a dark glass card (rgba white 5% bg, 1px rgba white 8% border, 28px radius). Contains:
- Left: square icon (64px, rounded 18px, color-tinted at 15% opacity) with a line-style icon in the feature's color
- Middle: feature name in white bold, short description in dim white below
- Right: green checkmark icon (#30D158)

Row 1: Purple tint (#7C6FFD), share/upload icon → "Unlimited Sharing" → "Share all your lists — free includes 2"
Row 2: Blue tint (#3FA9F5), bar chart icon → "Stats & Insights" → "Charts, totals & currency conversion"
Row 3: Teal tint (#34C4A0), bell icon → "Gifting Alerts" → "Know when someone reserves a gift"
Row 4: Orange tint (#FF7043), grid/widgets icon → "All Widget Sizes" → "Medium & Lock Screen widgets unlocked"

**Purchase card (centered, prominent):**
Rounded card (36px radius) with indigo gradient tint background (rgba indigo 20% → 5%) and 2px indigo 40% border, creating a glowing premium feel. Contains:
- "LIFETIME ACCESS" in dim uppercase tracking
- "$4.99" in very large white bold text (56px)
- "One-time purchase. No subscription." in dim white
- Wide indigo pill button: "Get Gimme Pro" in white bold text, with indigo glow shadow beneath

**Footer:** three dim text links: "Restore Purchases", "Privacy Policy", "Terms"

---

## Export Notes

- All screenshots should be exported at exactly **1290 x 2796 px** (iPhone 15 Pro Max 6.7")
- For 6.1" (iPhone 15 Pro): scale down to **1179 x 2556 px**
- Save as PNG with no compression artifacts
- Ensure all text is crisp and readable at the target resolution
- The device should feel like a real photograph of a phone, not a flat illustration
