import { Metadata } from "next";
import { Fraunces } from "next/font/google";
import { supabase, WishList, WishItem } from "@/lib/supabase";
import { WishItemCard } from "@/components/WishItemCard";
import { BottomCTA } from "./BottomCTA";

const fraunces = Fraunces({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-fraunces",
  weight: ["400", "500", "600"],
  style: ["normal", "italic"],
});

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
    <main className={`share-page atelier ${fraunces.variable} relative overflow-hidden min-h-[100dvh]`}>

      {/* ── Radial glow in list color ── */}
      <div
        className="absolute top-0 left-1/2 -translate-x-1/2 w-[900px] h-[700px] pointer-events-none"
        style={{
          background: `radial-gradient(ellipse at center, ${list.color_hex}1F 0%, ${list.color_hex}0A 35%, transparent 65%)`,
          filter: "blur(50px)",
        }}
        aria-hidden="true"
      />

      {/* ── Film grain ── */}
      <div className="atelier-grain pointer-events-none fixed inset-0 z-50" aria-hidden="true" />

      <div className="relative max-w-lg mx-auto px-4 pt-7 pb-44">

      {/* ── Branded header ── */}
      <a
        href="https://gimmelist.com"
        className="l-anim flex items-center justify-center gap-2.5 mb-14 no-underline"
      >
        <img src="/app-icon.png" alt="Gimme" width={28} height={28} className="rounded-lg opacity-75" />
        <span className="text-[13px] font-bold text-white/55 tracking-[0.22em] uppercase">Gimme</span>
      </a>

      {/* ── List header ── */}
      <header className="text-center mb-12 l-anim l-d1">
        {/* Emoji icon with list color */}
        <div
          className="inline-flex items-center justify-center w-[120px] h-[120px] rounded-[2rem] text-[60px] mb-8 relative s-float"
          style={{
            backgroundColor: list.color_hex + "14",
            boxShadow: `0 24px 60px ${list.color_hex}22, inset 0 1px 0 rgba(255,255,255,0.08)`,
            border: `1px solid ${list.color_hex}26`,
          }}
        >
          {list.emoji}
        </div>

        <h1 className="atelier-name text-[40px] leading-[1.05] tracking-[-0.01em] mb-3 text-white">
          {list.name}
        </h1>

        {/* Subtitle line */}
        <p className="text-white/40 text-[13px] tracking-wide">
          {items.length > 0
            ? allClaimedOrPurchased
              ? "Everything has been claimed or purchased"
              : `A shared wishlist`
            : "A shared wishlist"}
        </p>
      </header>

      {/* ── Stats strip (compact inline) ── */}
      {items.length > 0 && (
        <div className="l-anim l-d2 mb-12">
          <div className="text-center text-[12px] text-white/45 tabular-nums tracking-wide">
            <span className="text-white/85 font-semibold">{unpurchasedCount}</span> gift{unpurchasedCount === 1 ? "" : "s"} to claim
            {totalPrice && (
              <>
                <span className="text-white/15 mx-2.5">·</span>
                <span className="text-white/85 font-semibold">{totalPrice}</span> total
              </>
            )}
            {claimedCount > 0 && (
              <>
                <span className="text-white/15 mx-2.5">·</span>
                <span className="font-semibold" style={{ color: list.color_hex }}>{claimedCount}</span> claimed
              </>
            )}
            {purchasedCount > 0 && (
              <>
                <span className="text-white/15 mx-2.5">·</span>
                <span className="font-semibold text-[#34C48A]">{purchasedCount}</span> bought
              </>
            )}
          </div>
        </div>
      )}

      {/* ── Items grid (2-up) ── */}
      {items.length === 0 ? (
        <EmptyState color={list.color_hex} />
      ) : allClaimedOrPurchased ? (
        <>
          <AllDoneState color={list.color_hex} name={list.name} />
          <div className="mt-6 grid grid-cols-2 gap-3">
            {items.map((item, index) => (
              <div key={item.id} className={`l-anim l-d${Math.min(index + 4, 8)}`}>
                <WishItemCard item={item} shareToken={token} accent={list.color_hex} />
              </div>
            ))}
          </div>
        </>
      ) : (
        <div className="grid grid-cols-2 gap-3 mb-20">
          {items.map((item, index) => (
            <div key={item.id} className={`l-anim l-d${Math.min(index + 3, 8)}`}>
              <WishItemCard item={item} shareToken={token} accent={list.color_hex} />
            </div>
          ))}
        </div>
      )}

      {/* ── Editorial "you-too" block ── */}
      {items.length > 0 && (
        <section className="l-anim l-d5">
          <div className="atelier-divider mb-14" />

          <div className="text-center max-w-sm mx-auto">
            <p className="atelier-name italic text-[26px] leading-[1.2] text-white/90 mb-1.5">
              Made with Gimme.
            </p>
            <p
              className="atelier-name italic text-[26px] leading-[1.2] mb-12"
              style={{ color: list.color_hex }}
            >
              You can have one too.
            </p>

            <div className="grid grid-cols-3 gap-3 mb-12">
              <Step n="01" label="Add wishes" />
              <Step n="02" label="Share a link" />
              <Step n="03" label="Friends claim" />
            </div>

            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2.5 rounded-full pl-5 pr-1.5 py-2 text-[13px] font-semibold no-underline atelier-cta"
            >
              <svg width="14" height="17" viewBox="0 0 16 20" fill="currentColor" className="shrink-0">
                <path d="M11.86 10.36c-.03-2.3 1.88-3.4 1.97-3.46-1.07-1.57-2.74-1.78-3.34-1.81-1.42-.14-2.77.84-3.49.84s-1.83-.82-3.01-.8c-1.55.03-2.98.9-3.78 2.29-1.61 2.79-.41 6.93 1.16 9.19.77 1.11 1.68 2.36 2.88 2.31 1.16-.05 1.6-.75 3-.75s1.79.75 3.01.73c1.24-.03 2.04-1.13 2.8-2.24.88-1.29 1.24-2.53 1.27-2.6-.03-.01-2.44-.94-2.47-3.7zM9.53 3.5c.64-.77 1.07-1.85.95-2.92-.92.04-2.03.61-2.69 1.38-.59.68-1.11 1.77-.97 2.82 1.02.08 2.07-.52 2.71-1.28z"/>
              </svg>
              <span>Download on the App Store</span>
              <span className="atelier-cta-arrow w-7 h-7 rounded-full bg-black/10 flex items-center justify-center">
                <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                  <path d="M2.5 7.5L7.5 2.5M7.5 2.5H3.5M7.5 2.5V6.5" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </span>
            </a>

            <p className="text-[11px] text-white/25 mt-7 tracking-wide">
              Free · Optional Pro upgrade · No subscriptions
            </p>
          </div>
        </section>
      )}

      </div>

      {/* ── Fixed bottom dismissible CTA ── */}
      <BottomCTA />

      <style>{`
        .atelier {
          font-family: var(--font-outfit), system-ui, sans-serif;
        }
        .atelier-name {
          font-family: var(--font-fraunces), Georgia, serif;
          font-weight: 500;
          font-style: italic;
          font-variation-settings: "opsz" 144, "SOFT" 50;
        }
        .atelier-grain {
          opacity: 0.04;
          background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
        }
        .atelier-divider {
          height: 1px;
          background: linear-gradient(90deg, transparent, rgba(255,255,255,0.10), transparent);
        }
        .atelier-cta {
          background: #FFFFFF;
          color: #0C0C0F;
          transition: all 0.7s cubic-bezier(0.32, 0.72, 0, 1);
          box-shadow: 0 4px 24px rgba(255,255,255,0.10);
        }
        .atelier-cta:hover {
          box-shadow: 0 10px 44px rgba(255,255,255,0.18);
          transform: translateY(-2px);
        }
        .atelier-cta:active {
          transform: translateY(0) scale(0.98);
        }
        .atelier-cta-arrow {
          transition: transform 0.7s cubic-bezier(0.32, 0.72, 0, 1);
        }
        .atelier-cta:hover .atelier-cta-arrow {
          transform: translate(2px, -1px) scale(1.05);
        }
        @media (prefers-reduced-motion: reduce) {
          .s-float, .l-anim, .atelier-cta, .atelier-cta-arrow {
            animation: none !important;
            opacity: 1 !important;
            transition: none !important;
          }
        }
      `}</style>
    </main>
  );
}

/* ── 3-step card ── */
function Step({ n, label }: { n: string; label: string }) {
  return (
    <div className="doppel-outer-dark">
      <div className="doppel-inner-dark p-4 text-center">
        <p className="text-white/30 text-[10px] font-bold tabular-nums tracking-[0.18em] mb-2">{n}</p>
        <p className="text-white/75 text-[11px] font-medium leading-tight">{label}</p>
      </div>
    </div>
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
