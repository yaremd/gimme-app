/* Shared content for the landing options. The wishes and lists mirror the demo data
   seeded into the Simulator for the screenshots, so page copy and screens agree. */

export type Screen = { src: string; alt: string };

/* Bump when the captures are re-shot, so browsers don't show a cached older set. */
const CAPTURE_SET = "2026-11-12b";
const screen = (name: string, alt: string): Screen => ({ src: `/v2/screens/${name}.webp?v=${CAPTURE_SET}`, alt });

export const SCREENS = {
  homeDark: screen("home-dark", "Gimme home screen with five wishlists and what is left to buy"),
  homeLight: screen("home-light", "Gimme home screen in light mode with five wishlists"),
  listDark: screen("list-dark", "Birthday wishlist with Nike Free shoes, Sony headphones, a Polaroid camera and a Chemex: two price drops and one reserved gift"),
  listLight: screen("list-light", "Birthday wishlist in light mode with Nike Free shoes, Sony headphones, a Polaroid camera and a Chemex"),
  itemDark: screen("item-dark", "Nike Free running shoes with price history and a lowest-price-yet verdict"),
  itemLight: screen("item-light", "Nike Free running shoes in light mode with price history"),
  statsDark: screen("stats-dark", "Stats dashboard with totals across every wishlist"),
  statsLight: screen("stats-light", "Stats dashboard in light mode"),
  addDark: screen("add-dark", "New wish sheet with name, price and list filled in"),
  shareDark: screen("share-dark", "Sharing a wishlist from Gimme with one link"),
} as const;

export type Wish = {
  key: "shoes" | "headphones" | "camera" | "chemex" | "kindle" | "bottle";
  name: string;
  /** short form for chips and tight spots */
  short: string;
  price: string;
  image: string;
  badge?: { kind: "drop" | "gift"; text: string };
};

/* The six wishes on the demo Birthday list: real products, photographed.
   Photos are from Unsplash under the Unsplash License (free for commercial use),
   cropped square. Sources, by photo page on unsplash.com/photos/:
     shoes       unpaired-red-nike-sneaker-164_6wVEHfI
     headphones  a-pair-of-headphones-sitting-on-top-of-a-table-0QAe85hi_Mw   (Cosmin Ursea)
     camera      white-and-black-polaroid-instant-camera-OIFgeLnjwrM          (@pf91_photography)
     chemex      clear-glass-decanter-filled-with-black-liquid-Ve2SL0zMhWk    (Zarak Khan)
     kindle      a-tablet-and-a-cup-of-coffee-Y-l8j8na0TQ                     (@adryantos)
     bottle      yellow-and-black-sports-bottle-YDRrskIdMDw                   (Jamaal Cooks)
   The licence covers the photographs, not the brands' trademarks. */
const product = (key: Wish["key"]) => `/v2/products/${key}.webp`;

export const WISHES: Wish[] = [
  { key: "shoes", name: "Nike Free running shoes", short: "Nike Free", price: "$99", image: product("shoes"), badge: { kind: "drop", text: "−23%" } },
  { key: "headphones", name: "Sony wireless headphones", short: "Sony headphones", price: "$349", image: product("headphones"), badge: { kind: "drop", text: "−13%" } },
  { key: "camera", name: "Polaroid Supercolor 1000", short: "Polaroid camera", price: "$119", image: product("camera"), badge: { kind: "gift", text: "Reserved" } },
  { key: "chemex", name: "Chemex coffee maker", short: "Chemex", price: "$64", image: product("chemex") },
  { key: "kindle", name: "Kindle e-reader", short: "Kindle", price: "$89", image: product("kindle") },
  { key: "bottle", name: "Hydro Flask water bottle", short: "Hydro Flask", price: "$42", image: product("bottle") },
];

export const wish = (key: Wish["key"]): Wish => WISHES.find((w) => w.key === key)!;

export type List = {
  emoji: string;
  name: string;
  sub: string;
  value: string;
  color: string;
  progress: number;
  date?: string;
};

/* Values are each list's total, exactly as the Home screen shows them. */
export const LISTS: List[] = [
  { emoji: "🎂", name: "Birthday", sub: "5 of 6 remaining", value: "$762", color: "#E8586D", progress: 17, date: "Dec 5" },
  { emoji: "🎄", name: "Christmas", sub: "4 of 5 remaining", value: "$617", color: "#2EAA5F", progress: 20, date: "Dec 25" },
  { emoji: "💻", name: "Home office", sub: "3 of 4 remaining", value: "$361", color: "#3B8DD4", progress: 25 },
  { emoji: "✈️", name: "Trip to Lisbon", sub: "2 of 3 remaining", value: "$405", color: "#E07B3C", progress: 33, date: "Mar 12" },
  { emoji: "💐", name: "For Mom", sub: "3 of 3 remaining", value: "$175", color: "#D946A8", progress: 0, date: "May 9" },
];

/* Matches PaywallView.swift and the App Store listing on main (v1.1.1). */
export const PLANS = {
  free: {
    name: "Free",
    price: "$0",
    note: "No account needed to start",
    features: [
      "Unlimited lists and wishes",
      "Save from any app with the Share Extension",
      "Sync across your devices",
      "Share up to 2 lists",
      "Price tracking on 3 wishes",
      "Home Screen widget",
    ],
  },
  pro: {
    name: "Gimme Pro",
    price: "$4.99",
    note: "Once. No subscription.",
    features: [
      "Share every list",
      "Price tracking on everything",
      "Stats and insights",
      "Alerts when a friend reserves a gift",
      "Medium and Lock Screen widgets",
      "Every Pro feature we add later",
    ],
  },
} as const;

export const STEPS = [
  {
    key: "save",
    label: "Save",
    title: "Save it the second you see it.",
    body: "Share any product page to Gimme, or paste the link. The name, photo and price fill themselves in.",
  },
  {
    key: "share",
    label: "Share",
    title: "Send one link.",
    body: "Friends open your list in any browser. No app to install, no account to make.",
  },
  {
    key: "claim",
    label: "Claim",
    title: "They claim it. Nobody doubles up.",
    body: "A friend taps “I’ll get this” and everyone else sees it is taken. Turn on anonymous reservations and even you won’t know who.",
  },
  {
    key: "track",
    label: "Track",
    title: "Never pay full price.",
    body: "Gimme watches the price of what you saved and tells you the moment it drops. Set a target and wait for it.",
  },
] as const;

export const NAV = [
  { href: "#how", label: "How it works" },
  { href: "#iphone", label: "On iPhone" },
  { href: "#pricing", label: "Pricing" },
] as const;

export const FOOTER_LINKS = [
  { href: "/support", label: "Support" },
  { href: "/privacy", label: "Privacy" },
  { href: "/terms", label: "Terms" },
  { href: "/contact", label: "Contact" },
] as const;
