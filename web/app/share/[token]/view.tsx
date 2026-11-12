import type { CSSProperties } from "react";
import Link from "next/link";
import { AppStoreButton, HandUnderline, Icon, Sparkle, Wordmark } from "@/app/_site/brand";
import { Sky } from "@/app/_site/chrome";
import { Reveal } from "@/app/_site/reveal";
import type { WishList, WishItem } from "@/lib/supabase";
import { WishItemCard } from "@/components/WishItemCard";
import { BottomCTA } from "./BottomCTA";

/* What the shared-wishlist page draws. It is separate from the data loading in
   page.tsx so the design can also be previewed with sample data. */

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

/** Shown when the link doesn't lead to a list that is being shared. */
export function ShareNotFound() {
  return (
      <main className="share-page g-solo">
        <Sky />
        <div className="g-solo__glow" aria-hidden="true" />
        <Link href="/" className="g-solo__logo" aria-label="Gimme, home">
          <Wordmark />
        </Link>
        <div className="g-solo__in l-anim">
          <span className="g-solo__ic s-float">
            <Icon name="search" />
          </span>
          <h1 className="g-solo__title" style={{ fontSize: "clamp(38px, 8vw, 60px)" }}>
            List not found
          </h1>
          <p className="g-solo__sub">This wishlist doesn&apos;t exist or is no longer shared.</p>
          <div className="g-solo__acts">
            <AppStoreButton label="Get Gimme and make your own" />
          </div>
        </div>
      </main>
  );
}

export function ShareView({ list, items, token }: { list: WishList; items: WishItem[]; token: string }) {
  const anonymous = list.anonymous_reservations === true;
  // still free to claim: neither bought nor reserved by someone
  const availableCount   = items.filter((i) => !i.is_purchased && !i.is_reserved_by_friend).length;
  const claimedCount     = items.filter((i) => i.is_reserved_by_friend && !i.is_purchased).length;
  const purchasedCount   = items.filter((i) => i.is_purchased).length;
  const totalPrice       = formatTotalPrice(items);
  const allClaimedOrPurchased = items.length > 0 && availableCount === 0;

  return (
    <main className="share-page" style={{ "--list": list.color_hex } as CSSProperties}>
      <Sky />

      {/* ── Glow in the list's own colour ── */}
      <div className="s-glow" aria-hidden="true" />

      <div className="relative max-w-lg mx-auto px-4 pt-6 pb-44">

      {/* ── Brand ── */}
      <Link href="/" className="s-logo l-anim mb-11" aria-label="Gimme, home">
        <Wordmark />
      </Link>

      {/* ── List header ── */}
      <header className="text-center mb-9 l-anim l-d1">
        <div className="s-emoji s-float mb-7" aria-hidden="true">
          {list.emoji}
          <Sparkle />
        </div>
        <p className="s-kicker mb-3">
          {allClaimedOrPurchased ? "Everything has been claimed or purchased" : "A shared wishlist"}
        </p>
        <h1 className="s-title">{list.name}</h1>
      </header>

      {/* ── Counts ── */}
      {items.length > 0 && (
        <p className="s-stats text-center mb-10 l-anim l-d2">
          <b>{availableCount}</b> gift{availableCount === 1 ? "" : "s"} to claim
          {totalPrice && (
            <>
              <i>·</i>
              <b>{totalPrice}</b> total
            </>
          )}
          {claimedCount > 0 && (
            <>
              <i>·</i>
              <b style={{ color: "var(--list-ink)" }}>{claimedCount}</b> claimed
            </>
          )}
          {purchasedCount > 0 && (
            <>
              <i>·</i>
              <b style={{ color: "var(--ok)" }}>{purchasedCount}</b> bought
            </>
          )}
        </p>
      )}

      {/* ── Wishes, two across ── */}
      {items.length === 0 ? (
        <EmptyState />
      ) : allClaimedOrPurchased ? (
        <>
          <AllDoneState name={list.name} />
          <div className="mt-6 grid grid-cols-2 gap-3 mb-20">
            {items.map((item, index) => (
              <div key={item.id} className={`l-anim l-d${Math.min(index + 4, 8)}`}>
                <WishItemCard item={item} shareToken={token} accent={list.color_hex} anonymous={anonymous} />
              </div>
            ))}
          </div>
        </>
      ) : (
        <div className="grid grid-cols-2 gap-3 mb-20">
          {items.map((item, index) => (
            <div key={item.id} className={`l-anim l-d${Math.min(index + 3, 8)}`}>
              <WishItemCard item={item} shareToken={token} accent={list.color_hex} anonymous={anonymous} />
            </div>
          ))}
        </div>
      )}

      {/* ── "You can have one too" ── */}
      {items.length > 0 && (
        <Reveal as="section" className="text-center max-w-sm mx-auto">
          <div className="s-divider mb-12" />

          <p className="s-pitch mb-9">
            Made with Gimme.
            <br />
            <span style={{ color: "var(--lavender)" }}>
              You can have{" "}
              <span className="g-under">
                one too.
                <HandUnderline />
              </span>
            </span>
          </p>

          <ol className="grid grid-cols-3 gap-2.5 mb-10">
            <Step n="01" label="Add wishes" />
            <Step n="02" label="Share a link" />
            <Step n="03" label="Friends claim" />
          </ol>

          <AppStoreButton />

          <p className="s-dim text-[13.5px] mt-6">Free · Optional Pro upgrade · No subscriptions</p>
        </Reveal>
      )}

      </div>

      {/* ── Fixed bar at the bottom; it can be dismissed ── */}
      <BottomCTA />
    </main>
  );
}

function Step({ n, label }: { n: string; label: string }) {
  return (
    <li className="s-step">
      <b>{n}</b>
      <span>{label}</span>
    </li>
  );
}

function EmptyState() {
  return (
    <div className="text-center py-14 l-anim l-d3">
      <span className="s-tile s-float mx-auto mb-5">
        <Icon name="gift" />
      </span>
      <p className="text-[18px] font-semibold mb-1.5">Nothing here yet</p>
      <p className="s-muted text-[15px] max-w-[26ch] mx-auto leading-relaxed">
        The list owner hasn&apos;t added any wishes. Check back soon.
      </p>
    </div>
  );
}

function AllDoneState({ name }: { name: string }) {
  return (
    <div className="s-done l-anim l-d3">
      <span className="s-done__ic">
        <Icon name="check" />
      </span>
      <div>
        <p className="text-[15px] font-semibold leading-snug">Everything&apos;s been claimed</p>
        <p className="s-muted text-[13.5px] mt-0.5">All gifts on {name} are taken</p>
      </div>
    </div>
  );
}
