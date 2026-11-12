import type { WishItem, WishList } from "@/lib/supabase";
import { ShareNotFound, ShareView } from "../../share/[token]/view";
import { WISHES } from "../../_site/data";

/* A local preview of the shared-wishlist page with sample data, so its design and
   every state can be seen without a real share link. Like the rest of /options it
   does not exist on the live site.

     /options/share                the usual page
     /options/share?anon=1         a list with anonymous reservations
     /options/share?state=done     everything claimed or bought
     /options/share?state=empty    a list with no wishes
     /options/share?state=missing  a link that leads nowhere

   The sample wishes are not in the database, so "Claim this gift" answers with
   an error here. That is expected. */

const PRICES: Record<string, number> = { shoes: 99, headphones: 349, camera: 119, chemex: 64, kindle: 89, bottle: 42 };

function sample(state: string | undefined, anonymous: boolean): { list: WishList; items: WishItem[] } {
  const list: WishList = {
    id: "00000000-0000-4000-8000-000000000000",
    name: "Birthday",
    emoji: "🎂",
    color_hex: "#E8586D",
    is_shared: true,
    share_token: "preview",
    anonymous_reservations: anonymous,
    created_at: "2026-11-01T09:41:00Z",
  };

  const items: WishItem[] = WISHES.map((w, i) => ({
    id: `00000000-0000-4000-8000-00000000000${i + 1}`,
    title: w.name,
    notes: null,
    url: w.key === "bottle" ? null : `https://shop.example/${w.key}`,
    image_url: w.image,
    price_double: PRICES[w.key],
    currency: "USD",
    priority: (["high", "medium", "medium", "low", "medium", "low"] as const)[i],
    is_purchased: state === "done" ? i % 2 === 0 : w.key === "kindle",
    is_reserved_by_friend: state === "done" ? true : w.key === "camera",
    reserved_by_name: anonymous ? null : w.key === "camera" ? "Anna" : null,
    reserved_comment: null,
    is_pinned: i === 0,
    is_archived: false,
    created_at: "2026-11-01T09:41:00Z",
  }));

  // one wish without a photo, to show the placeholder
  items.push({
    ...items[0],
    id: "00000000-0000-4000-8000-000000000009",
    title: "Concert tickets",
    url: null,
    image_url: null,
    price_double: 120,
    priority: "medium",
    is_purchased: state === "done",
    is_reserved_by_friend: state === "done",
    is_pinned: false,
  });

  return { list, items: state === "empty" ? [] : items };
}

export default async function SharePreview({
  searchParams,
}: {
  searchParams: Promise<{ state?: string; anon?: string }>;
}) {
  const { state, anon } = await searchParams;
  if (state === "missing") return <ShareNotFound />;
  const { list, items } = sample(state, anon === "1");
  return <ShareView list={list} items={items} token="preview" />;
}
