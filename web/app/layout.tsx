import type { Metadata, Viewport } from "next";
import { Inter, Outfit } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-inter",
});

const outfit = Outfit({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-outfit",
});

export const viewport: Viewport = {
  themeColor: "#0D0D0F",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  viewportFit: "cover",
};

const siteUrl = "https://gimmelist.com";
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
  metadataBase: new URL(siteUrl),
  alternates: { canonical: siteUrl },
  appLinks: {
    ios: {
      app_store_id: "6762543923",
      url: siteUrl,
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
    url: siteUrl,
  },
  twitter: {
    card: "summary_large_image",
    title,
    description,
  },
};

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "Gimme",
  operatingSystem: "iOS",
  applicationCategory: "LifestyleApplication",
  description,
  url: siteUrl,
  downloadUrl:
    "https://apps.apple.com/app/gimme-wishlist-gift-ideas/id6762543923",
  offers: [
    { "@type": "Offer", price: "0", priceCurrency: "USD", name: "Free" },
    { "@type": "Offer", price: "4.99", priceCurrency: "USD", name: "Gimme Pro" },
  ],
  author: {
    "@type": "Person",
    name: "Dmytro Yaremchuk",
    url: siteUrl,
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`${inter.variable} ${outfit.variable}`}>
      <head>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body className="font-sans text-white antialiased min-h-dvh selection:bg-[#5B54E0]/30">
        {children}
      </body>
    </html>
  );
}
