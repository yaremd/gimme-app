import type { Metadata, Viewport } from "next";
import { Figtree, Gabarito, Geist_Mono, Nunito } from "next/font/google";
import { Analytics } from "@vercel/analytics/next";
import { APP_STORE_URL } from "./_site/brand";
import { SITE_URL } from "./_site/data";
import { OG_IMAGE } from "./_site/meta";
import "./globals.css";
import "./site.css";

/* Figtree for text and Gabarito for headlines are on every page, so they preload.
   The mono face (small labels) and Nunito (a fallback for the rounded system face
   off Apple devices) load only where they are used. */
const figtree = Figtree({ subsets: ["latin"], display: "swap", variable: "--font-figtree" });
const gabarito = Gabarito({ subsets: ["latin"], display: "swap", variable: "--font-gabarito" });
const geistMono = Geist_Mono({ subsets: ["latin"], display: "swap", variable: "--font-geist-mono", preload: false });
const nunito = Nunito({ subsets: ["latin"], display: "swap", variable: "--font-nunito", preload: false });

export const viewport: Viewport = {
  themeColor: "#0C0C11",
  colorScheme: "dark",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

const title = "Gimme — Wishlist App for iPhone";
const description =
  "Create and share wishlists on iPhone. Friends claim gifts from a web link — no download needed. Paste any URL and price, image, title auto-fill. Free with optional Pro upgrade.";

export const metadata: Metadata = {
  title,
  description,
  applicationName: "Gimme",
  keywords: [
    "wishlist app",
    "wishlist app iphone",
    "gift list app",
    "birthday wishlist",
    "christmas wishlist app",
    "shared wishlist",
    "wish list app ios",
    "gift tracker",
    "wish list for gifts",
    "gimme app",
  ],
  metadataBase: new URL(SITE_URL),
  // No site-wide canonical here: each page declares its own (see _site/meta.ts),
  // otherwise every page would point search engines at the home page.
  appLinks: {
    ios: {
      app_store_id: "6762543923",
      url: SITE_URL,
    },
  },
  other: {
    "apple-itunes-app": "app-id=6762543923",
  },
  appleWebApp: {
    capable: true,
    title: "Gimme",
    statusBarStyle: "black-translucent",
  },
  openGraph: {
    title,
    description,
    siteName: "Gimme",
    type: "website",
    url: SITE_URL,
    images: [OG_IMAGE],
  },
  twitter: {
    card: "summary_large_image",
    title,
    description,
    images: [OG_IMAGE.url],
  },
};

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "Gimme",
  operatingSystem: "iOS",
  applicationCategory: "LifestyleApplication",
  description,
  url: SITE_URL,
  downloadUrl: APP_STORE_URL,
  image: `${SITE_URL}/og.jpg`,
  offers: [
    { "@type": "Offer", price: "0", priceCurrency: "USD", name: "Free" },
    { "@type": "Offer", price: "4.99", priceCurrency: "USD", name: "Gimme Pro" },
  ],
  author: {
    "@type": "Person",
    name: "Dmytro Yaremchuk",
    url: SITE_URL,
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const fonts = [figtree, gabarito, geistMono, nunito].map((f) => f.variable).join(" ");
  return (
    // The inline script below adds a class to <html> before React hydrates.
    <html lang="en" className={fonts} suppressHydrationWarning>
      <head>
        {/* Scroll reveals only hide content once scripting is known to work. */}
        <script dangerouslySetInnerHTML={{ __html: "document.documentElement.classList.add('js')" }} />
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      </head>
      <body className="g-root">
        {children}
        <Analytics />
      </body>
    </html>
  );
}
