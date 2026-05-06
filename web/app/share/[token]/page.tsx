import { Metadata } from "next";
import { notFound } from "next/navigation";
import { supabase, WishList, WishItem } from "@/lib/supabase";
import { WishItemCard } from "@/components/WishItemCard";

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

  return { list, items: items ?? [] };
}

function formatTotalPrice(items: WishItem[]): string | null {
  const priced = items.filter((i) => i.price_double != null && !i.is_purchased);
  if (priced.length === 0) return null;
  const currency = priced[0].currency ?? "USD";
  const sameCurrency = priced.every((i) => (i.currency ?? "USD") === currency);
  if (!sameCurrency) return null;
  const total = priced.reduce((sum, i) => sum + (i.price_double ?? 0), 0);
  try {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(total);
  } catch {
    return null;
  }
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { token } = await params;
  const result = await getSharedList(token);

  if (!result) {
    return { title: "List not found — Gimme" };
  }

  const { list, items } = result;
  const itemCount = items.length;
  const title = `${list.emoji} ${list.name}`;
  const description = `${itemCount} wish${itemCount === 1 ? "" : "es"} on Gimme — tap to claim a gift`;

  return {
    title: `${title} — Gimme`,
    description,
    openGraph: {
      title,
      description,
      type: "website",
      siteName: "Gimme",
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
    },
  };
}

const APP_STORE_URL = "https://apps.apple.com/app/gimme-wishlist-gift-ideas/id6762543923";

export default async function SharePage({ params }: Props) {
  const { token } = await params;
  const result = await getSharedList(token);

  if (!result) {
    return (
      <main className="share-page flex items-center justify-center min-h-[100dvh] px-6">
        <div className="text-center max-w-xs l-anim">
          {/* Illustrated 404 icon */}
          <div className="w-24 h-24 rounded-[2rem] bg-white/[0.03] border border-white/[0.05] flex items-center justify-center mx-auto mb-6 s-float">
            <svg width="36" height="36" viewBox="0 0 36 36" fill="none">
              <circle cx="15" cy="15" r="9" stroke="rgba(255,255,255,0.18)" strokeWidth="1.5"/>
              <path d="M22 22L30 30" stroke="rgba(255,255,255,0.18)" strokeWidth="1.5" strokeLinecap="round"/>
              <path d="M12 15h6M15 12v6" stroke="rgba(255,255,255,0.10)" strokeWidth="1.5" strokeLinecap="round"/>
            </svg>
          </div>
          <h1 className="text-2xl font-bold mb-2.5 tracking-tight">
            List not found
          </h1>
          <p className="text-white/35 mb-8 leading-relaxed text-[14px] max-w-[22ch] mx-auto">
            This wishlist doesn&apos;t exist or is no longer shared.
          </p>
          <DownloadCTA />
        </div>
      </main>
    );
  }

  const { list, items } = result;
  const unpurchasedCount = items.filter((i) => !i.is_purchased).length;
  const claimedCount     = items.filter((i) => i.is_reserved_by_friend && !i.is_purchased).length;
  const purchasedCount   = items.filter((i) => i.is_purchased).length;
  const totalPrice       = formatTotalPrice(items);
  const allClaimedOrPurchased = items.length > 0 && unpurchasedCount === 0;

  return (
    <main className="share-page max-w-lg mx-auto px-4 pt-6 pb-36">

      {/* ── Branded header ── */}
      <a
        href="https://gimmelist.com"
        className="l-anim flex items-center justify-center gap-2 mb-8 no-underline"
      >
        <img src="/app-icon.png" alt="Gimme" width={20} height={20} className="rounded-md opacity-50" />
        <span className="text-[11px] font-bold text-white/25 tracking-[0.18em] uppercase">Gimme</span>
      </a>

      {/* ── List header ── */}
      <header className="text-center mb-8 l-anim l-d1">
        {/* Emoji icon with list color */}
        <div
          className="inline-flex items-center justify-center w-[88px] h-[88px] rounded-[1.75rem] text-[42px] mb-5"
          style={{
            backgroundColor: list.color_hex + "16",
            boxShadow: `0 12px 40px ${list.color_hex}14, inset 0 1px 0 rgba(255,255,255,0.06)`,
            border: `1px solid ${list.color_hex}20`,
          }}
        >
          {list.emoji}
        </div>

        <h1 className="text-[28px] font-bold tracking-tight leading-tight mb-2">
          {list.name}
        </h1>

        {/* Subtitle line */}
        <p className="text-white/35 text-[13px]">
          {items.length > 0
            ? allClaimedOrPurchased
              ? "Everything has been claimed or purchased"
              : `${unpurchasedCount} gift${unpurchasedCount === 1 ? "" : "s"} to claim`
            : "No items yet"}
          {claimedCount > 0 && !allClaimedOrPurchased && (
            <span
              className="ml-2 inline-flex items-center gap-1 text-[11px] font-semibold rounded-full px-2 py-0.5"
              style={{ backgroundColor: list.color_hex + "1A", color: list.color_hex + "CC" }}
            >
              <svg width="9" height="9" viewBox="0 0 12 12" fill="none">
                <path d="M2.5 6.5L4.5 8.5L9.5 3.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
              {claimedCount} claimed
            </span>
          )}
        </p>
      </header>

      {/* ── Stats strip ── */}
      {items.length > 0 && (
        <div className="l-anim l-d2 flex items-center justify-center gap-8 mb-8">
          <Stat
            value={String(unpurchasedCount)}
            label="remaining"
            color={list.color_hex}
          />
          {totalPrice && (
            <>
              <div className="w-px h-8 bg-white/[0.06]" />
              <Stat value={totalPrice} label="total" />
            </>
          )}
          {purchasedCount > 0 && (
            <>
              <div className="w-px h-8 bg-white/[0.06]" />
              <Stat value={String(purchasedCount)} label="purchased" color="#34C48A" />
            </>
          )}
          {claimedCount > 0 && purchasedCount === 0 && (
            <>
              <div className="w-px h-8 bg-white/[0.06]" />
              <Stat value={String(claimedCount)} label="claimed" color="#34C48A" />
            </>
          )}
        </div>
      )}

      {/* ── Items list ── */}
      {items.length === 0 ? (
        <EmptyState color={list.color_hex} />
      ) : allClaimedOrPurchased ? (
        <>
          <AllDoneState color={list.color_hex} name={list.name} />
          <div className="mt-6 flex flex-col gap-3">
            {items.map((item, index) => (
              <div key={item.id} className={`l-anim l-d${Math.min(index + 4, 8)}`}>
                <WishItemCard item={item} shareToken={token} accent={list.color_hex} />
              </div>
            ))}
          </div>
        </>
      ) : (
        <div className="flex flex-col gap-3">
          {items.map((item, index) => (
            <div key={item.id} className={`l-anim l-d${Math.min(index + 3, 8)}`}>
              <WishItemCard item={item} shareToken={token} accent={list.color_hex} />
            </div>
          ))}
        </div>
      )}

      {/* ── Fixed bottom download CTA ── */}
      <div className="fixed bottom-0 inset-x-0 z-40 p-4 pb-[max(1rem,env(safe-area-inset-bottom))]">
        <div className="absolute inset-0 bg-gradient-to-t from-[#0C0C0F] via-[#0C0C0F]/96 to-transparent pointer-events-none" />
        <div className="relative max-w-lg mx-auto">
          <DownloadCTA />
        </div>
      </div>

    </main>
  );
}

/* ── Empty state ── */
function EmptyState({ color }: { color: string }) {
  return (
    <div className="text-center py-16 l-anim l-d3">
      <div
        className="w-20 h-20 rounded-[1.75rem] flex items-center justify-center mx-auto mb-5 s-float"
        style={{
          backgroundColor: color + "10",
          border: `1px solid ${color}18`,
          boxShadow: `0 12px 32px ${color}0A`,
        }}
      >
        {/* Gift box illustration */}
        <svg width="32" height="32" viewBox="0 0 32 32" fill="none">
          <rect x="5" y="13" width="22" height="16" rx="2" stroke={color} strokeWidth="1.4" strokeOpacity="0.5"/>
          <rect x="3" y="9" width="26" height="5" rx="2" stroke={color} strokeWidth="1.4" strokeOpacity="0.5"/>
          <path d="M16 9V29" stroke={color} strokeWidth="1.4" strokeOpacity="0.5" strokeLinecap="round"/>
          <path d="M16 9C16 9 13 5 10.5 5C8.5 5 8 7 10.5 8C12.5 9 16 9 16 9Z" stroke={color} strokeWidth="1.4" strokeOpacity="0.6" strokeLinejoin="round"/>
          <path d="M16 9C16 9 19 5 21.5 5C23.5 5 24 7 21.5 8C19.5 9 16 9 16 9Z" stroke={color} strokeWidth="1.4" strokeOpacity="0.6" strokeLinejoin="round"/>
        </svg>
      </div>
      <p className="text-[15px] font-semibold text-white/40 mb-1">
        Nothing here yet
      </p>
      <p className="text-[13px] text-white/22 max-w-[22ch] mx-auto leading-relaxed">
        The list owner hasn&apos;t added any wishes. Check back soon.
      </p>
    </div>
  );
}

/* ── All done state ── */
function AllDoneState({ color, name }: { color: string; name: string }) {
  return (
    <div
      className="rounded-2xl p-4 mb-4 l-anim l-d3 flex items-center gap-3"
      style={{
        background: `linear-gradient(135deg, ${color}10, ${color}06)`,
        border: `1px solid ${color}18`,
      }}
    >
      <div
        className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
        style={{ backgroundColor: color + "18" }}
      >
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
          <path d="M3 8.5L6 11.5L13 4.5" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      </div>
      <div>
        <p className="text-[13px] font-semibold text-white/70 leading-snug">
          Everything&apos;s been claimed
        </p>
        <p className="text-[11px] text-white/30 mt-0.5">
          All gifts on {name} are taken
        </p>
      </div>
    </div>
  );
}

/* ── Stat pill ── */
function Stat({ value, label, color }: { value: string; label: string; color?: string }) {
  return (
    <div className="text-center">
      <p
        className="text-[18px] font-bold tabular-nums leading-none"
        style={color ? { color } : { color: "rgba(255,255,255,0.8)" }}
      >
        {value}
      </p>
      <p className="text-[10px] text-white/22 uppercase tracking-[0.16em] mt-1 font-semibold">
        {label}
      </p>
    </div>
  );
}

/* ── Download CTA — Button-in-Button ── */
function DownloadCTA() {
  return (
    <a
      href={APP_STORE_URL}
      target="_blank"
      rel="noopener noreferrer"
      className="s-card-outer flex items-center justify-between gap-4 no-underline"
    >
      <div className="s-card-inner w-full p-4 flex items-center justify-between gap-4">
        <div className="flex items-center gap-3 min-w-0">
          <img
            src="/app-icon.png"
            alt="Gimme"
            width={40}
            height={40}
            className="shrink-0 rounded-[12px]"
          />
          <div className="min-w-0">
            <p className="font-semibold text-[14px] text-white">Get Gimme</p>
            <p className="text-white/28 text-[12px] mt-0.5">
              Create your own wishlist
            </p>
          </div>
        </div>
        <div className="group shrink-0 inline-flex items-center gap-2 rounded-full pl-4 pr-1.5 py-1.5 text-[12px] font-bold s-download-cta no-underline">
          <span>Download</span>
          <span className="s-cta-arrow w-6 h-6 rounded-full bg-black/10 flex items-center justify-center">
            <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
              <path d="M2.5 7.5L7.5 2.5M7.5 2.5H3.5M7.5 2.5V6.5" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </span>
        </div>
      </div>
    </a>
  );
}
