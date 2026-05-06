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

export const metadata: Metadata = {
  title: "Gimme — Wishlists made simple",
  description:
    "Create and share wishlists with anyone. No account needed to view or claim gifts.",
  applicationName: "Gimme",
  appLinks: {
    ios: {
      app_store_id: "6762543923",
      url: "https://gimmelist.com",
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
    title: "Gimme — Wishlists made simple",
    description: "Create and share wishlists with anyone. No account needed to view or claim gifts.",
    siteName: "Gimme",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Gimme — Wishlists made simple",
    description: "Create and share wishlists with anyone. No account needed to view or claim gifts.",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`${inter.variable} ${outfit.variable}`}>
      <body className="font-sans text-white antialiased min-h-dvh selection:bg-[#5B54E0]/30">
        {children}
      </body>
    </html>
  );
}
