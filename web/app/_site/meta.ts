import type { Metadata } from "next";

/* The social preview card, a screenshot of /options/og (see that page for how to
   re-render it). Bump the query when public/og.jpg changes, so Messages, Slack and
   the rest fetch the new one instead of their cached copy. */
export const OG_IMAGE = {
  url: "/og.jpg?v=2026-11-12",
  width: 1200,
  height: 630,
  alt: "Gimme: wish it, share it, get it. A wishlist app for iPhone.",
};

/** Title, description, a canonical URL of its own, and the social card, for one page.
 *  `path` is relative to the site root and is resolved by the layout's metadataBase. */
export function pageMeta({ title, description, path }: { title: string; description: string; path: string }): Metadata {
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: { title, description, url: path, siteName: "Gimme", type: "website", images: [OG_IMAGE] },
    twitter: { card: "summary_large_image", title, description, images: [OG_IMAGE.url] },
  };
}
