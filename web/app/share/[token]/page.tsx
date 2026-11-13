import { Metadata } from "next";
import { notFound } from "next/navigation";
import { supabase, WishList, WishItem } from "@/lib/supabase";
import { ShareView } from "./view";

interface Props {
  params: Promise<{ token: string }>;
}

async function getSharedList(token: string) {
  const { data: list, error: listError } = await supabase
    .from("wish_lists")
    .select("*")
    .eq("share_token", token)
    .eq("is_shared", true)
    .single<WishList>();

  if (listError || !list) return null;

  const { data: items } = await supabase
    .from("wish_items")
    .select("*")
    .eq("list_id", list.id)
    .eq("is_archived", false)
    .order("is_pinned", { ascending: false })
    .order("created_at", { ascending: false })
    .returns<WishItem[]>();

  // What a visitor's browser receives. A reservation message is written for the
  // list's owner, so it stays on the server. On a list with anonymous reservations
  // the reserver's name stays there too: the page only says a gift is reserved.
  const anonymous = list.anonymous_reservations === true;
  const visible = (items ?? []).map((item) => ({
    ...item,
    reserved_comment: null,
    reserved_by_name: anonymous ? null : item.reserved_by_name,
  }));

  return { list, items: visible };
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { token } = await params;
  const result = await getSharedList(token);

  const shareUrl = `https://gimmelist.com/share/${token}`;
  // BUILD_ID is injected by next.config.js at build time — one unique value
  // per deploy. Appending it to og:image busts every CDN/scraper cache that
  // would otherwise hold @vercel/og's default 1-year immutable response.
  const ogImageUrl = `https://gimmelist.com/share/${token}/opengraph-image?v=${process.env.BUILD_ID ?? "dev"}`;

  if (!result) {
    return {
      title: "List not found — Gimme",
      // Override the layout's site-wide canonical so the share URL is canonical to itself
      alternates: { canonical: shareUrl },
      // Wishlists are private-by-link — keep them out of search results
      robots: { index: false, follow: false },
    };
  }

  const { list, items } = result;
  const itemCount = items.length;
  const title = `${list.emoji} ${list.name}`;
  const description = `${itemCount} wish${itemCount === 1 ? "" : "es"} on Gimme — tap to claim a gift`;

  return {
    title: `${title} — Gimme`,
    description,
    // Critical: override the layout's site-wide canonical. Without this, Facebook/Slack/iMessage
    // follow the rel="canonical" to the homepage and use the LANDING PAGE OG image.
    alternates: { canonical: shareUrl },
    // Private-by-link surface; don't index in search engines.
    robots: { index: false, follow: false },
    openGraph: {
      title,
      description,
      url: shareUrl,
      type: "website",
      siteName: "Gimme",
      images: [
        {
          url: ogImageUrl,
          width: 1200,
          height: 630,
          alt: `${list.name} — wishlist on Gimme`,
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [ogImageUrl],
    },
  };
}

export default async function SharePage({ params }: Props) {
  const { token } = await params;
  const result = await getSharedList(token);

  // answers with a real 404 and draws ./not-found.tsx
  if (!result) notFound();

  return <ShareView list={result.list} items={result.items} token={token} />;
}
