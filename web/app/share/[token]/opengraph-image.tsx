import { ImageResponse } from "@vercel/og";
import { createClient } from "@supabase/supabase-js";
import type { WishList, WishItem } from "@/lib/supabase";

export const runtime = "edge";
export const alt = "Gimme Wishlist";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/* ── Format total price from items (returns "$340" or null) ── */
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

/* ── Fallback OG (when list doesn't exist) ── */
function FallbackOG() {
  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: "linear-gradient(135deg, #12111C 0%, #0D0D0F 100%)",
        fontFamily: "Outfit",
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
        <div
          style={{
            width: 72,
            height: 72,
            borderRadius: 20,
            background: "rgba(108,99,255,0.2)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontSize: 36,
            fontWeight: 800,
            color: "#8B83F0",
            border: "1px solid rgba(108,99,255,0.25)",
          }}
        >
          G
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
          <div style={{ display: "flex", fontSize: 42, fontWeight: 800, color: "white" }}>Gimme</div>
          <div style={{ display: "flex", fontSize: 20, color: "rgba(255,255,255,0.4)" }}>
            Wishlist & Gift Ideas
          </div>
        </div>
      </div>
    </div>
  );
}

/* ── Card: Midnight Atelier OG card (self-contained — computes its own stats) ── */
function Card({
  list,
  items,
  accent,
}: {
  list: WishList;
  items: WishItem[];
  accent: string;
}) {
  const color = accent || list?.color_hex || "#8B83F0";

  const validItems = items.slice(0, 4);
  const remaining = Math.max(items.length - 3, 0);

  const unpurchasedCount = items.filter((i) => !i.is_purchased).length;
  const claimedCount = items.filter(
    (i) => i.is_reserved_by_friend && !i.is_purchased
  ).length;
  const totalPrice = formatTotalPrice(items);

  // Compact stats — drop the middle segment when no price; drop "0 claimed"
  const stats = [
    `${unpurchasedCount} ${unpurchasedCount === 1 ? "gift" : "gifts"}`,
    totalPrice,
    claimedCount > 0 ? `${claimedCount} claimed` : null,
  ]
    .filter(Boolean)
    .join(" · ");

  const nameLen = list?.name?.length ?? 0;
  const title = nameLen > 28 ? 56 : nameLen > 18 ? 64 : 72;

  const isFullyClaimed = unpurchasedCount === 0 && items.length > 0;

  return (
    <div
      style={{
        width: 1200,
        height: 630,
        display: "flex",
        position: "relative",
        background: "#0C0C0F",
        color: "#fff",
        overflow: "hidden",
        fontFamily: "Outfit",
      }}
    >
      {/* Glow */}
      <div
        style={{
          position: "absolute",
          top: -120,
          left: -120,
          width: 520,
          height: 520,
          borderRadius: "50%",
          background: color,
          opacity: 0.18,
          filter: "blur(90px)",
          display: "flex",
        }}
      />

      {/* Subtle grid */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage:
            "linear-gradient(rgba(255,255,255,0.015) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.015) 1px, transparent 1px)",
          backgroundSize: "60px 60px",
          display: "flex",
        }}
      />

      {/* Single warmth gesture: hand-drawn underline beneath the title */}
      <div
        style={{
          position: "absolute",
          left: 120,
          top: 255,
          width: 180,
          height: 2,
          background: color,
          opacity: 0.3,
          transform: "rotate(-1.5deg)",
          display: "flex",
        }}
      />

      {/* Left column */}
      <div
        style={{
          width: "42%",
          padding: "72px 0 72px 72px",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          zIndex: 2,
        }}
      >
        <div style={{ display: "flex", flexDirection: "column" }}>
          {/* Emoji */}
          <div
            style={{
              width: 120,
              height: 120,
              borderRadius: 28,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: 64,
              border: `1px solid ${color}33`,
              background: "rgba(255,255,255,0.03)",
              marginBottom: 28,
            }}
          >
            {list?.emoji || "🎁"}
          </div>

          {/* Title — Fraunces italic */}
          <div
            style={{
              fontFamily: "Fraunces",
              fontStyle: "italic",
              fontWeight: 500,
              fontSize: title,
              lineHeight: 1.02,
              letterSpacing: "-0.04em",
              maxWidth: 420,
              display: "flex",
            }}
          >
            {list?.name || "A Shared Wishlist"}
          </div>

          {/* Stats */}
          <div
            style={{
              marginTop: 24,
              fontSize: 22,
              opacity: 0.42,
              display: "flex",
            }}
          >
            {stats}
          </div>

          {/* CTA */}
          <div style={{ marginTop: 36, display: "flex" }}>
            <div
              style={{
                background: "#FFFFFF",
                color: "#0C0C0F",
                borderRadius: 999,
                padding: "16px 26px",
                fontSize: 20,
                fontWeight: 500,
                display: "flex",
              }}
            >
              Open this wishlist →
            </div>
          </div>
        </div>

        {/* Footer */}
        <div
          style={{
            borderTop: "1px solid rgba(255,255,255,0.06)",
            paddingTop: 18,
            display: "flex",
            flexDirection: "column",
            gap: 6,
          }}
        >
          <div
            style={{
              display: "flex",
              fontSize: 16,
              letterSpacing: "0.18em",
              opacity: 0.85,
            }}
          >
            GIMMELIST.COM
          </div>
          <div
            style={{
              display: "flex",
              fontSize: 15,
              opacity: 0.32,
            }}
          >
            Make your own — free on iPhone
          </div>
        </div>
      </div>

      {/* Right column */}
      <div
        style={{
          width: "58%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          paddingRight: 72,
          zIndex: 2,
        }}
      >
        {validItems.length === 0 ? (
          <div
            style={{
              width: 420,
              height: 420,
              borderRadius: 32,
              border: "1px solid rgba(255,255,255,0.08)",
              background: "rgba(255,255,255,0.03)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: 28,
              opacity: 0.4,
            }}
          >
            Gifts will appear here
          </div>
        ) : (
          <div
            style={{
              width: 500,
              height: 500,
              display: "flex",
              flexWrap: "wrap",
              gap: 20,
              position: "relative",
            }}
          >
            {validItems.map((item, i) => {
              const showMore = i === 3 && items.length > 4;

              // When the slot is the "+N more" tile, render ONLY the overlay —
              // don't render the underlying item content (was leaking through 72% black).
              if (showMore && remaining > 0) {
                return (
                  <div
                    key={i}
                    style={{
                      width: 240,
                      height: 240,
                      borderRadius: 28,
                      border: "1.5px solid rgba(255,255,255,0.1)",
                      boxShadow: "0 24px 64px rgba(0,0,0,0.4)",
                      background: `linear-gradient(135deg, ${color}24, ${color}10)`,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      fontSize: 42,
                      fontWeight: 600,
                      color: "#fff",
                    }}
                  >
                    +{remaining} more
                  </div>
                );
              }

              return (
                <div
                  key={i}
                  style={{
                    width: 240,
                    height: 240,
                    borderRadius: 28,
                    overflow: "hidden",
                    position: "relative",
                    border: "1.5px solid rgba(255,255,255,0.1)",
                    boxShadow: "0 24px 64px rgba(0,0,0,0.4)",
                    background: item?.image_url ? "#1a1a1f" : `${color}22`,
                    display: "flex",
                  }}
                >
                  {item?.image_url ? (
                    /* eslint-disable-next-line @next/next/no-img-element */
                    <img
                      src={item.image_url}
                      alt=""
                      width="240"
                      height="240"
                      style={{ objectFit: "cover" }}
                    />
                  ) : (
                    <div
                      style={{
                        width: "100%",
                        height: "100%",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        padding: 20,
                        fontSize: 20,
                        opacity: 0.55,
                        textAlign: "center",
                      }}
                    >
                      {item?.title || "Gift"}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Fully claimed state */}
      {isFullyClaimed && (
        <div
          style={{
            position: "absolute",
            top: 48,
            right: 48,
            padding: "10px 18px",
            borderRadius: 999,
            background: "rgba(255,255,255,0.08)",
            border: "1px solid rgba(255,255,255,0.08)",
            fontSize: 16,
            display: "flex",
          }}
        >
          ✓ Fully claimed
        </div>
      )}
    </div>
  );
}

/* ── Image route ── */
export default async function Image({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;

  const supabaseClient = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  const outfit = await fetch(
    new URL("./Outfit-Medium.ttf", import.meta.url)
  ).then((r) => r.arrayBuffer());

  const fraunces = await fetch(
    new URL("./Fraunces-MediumItalic.ttf", import.meta.url)
  ).then((r) => r.arrayBuffer());

  const { data: list } = await supabaseClient
    .from("wish_lists")
    .select("*")
    .eq("share_token", token)
    .eq("is_shared", true)
    .single<WishList>();

  const fonts = [
    {
      name: "Outfit",
      data: outfit,
      weight: 500 as const,
    },
    {
      name: "Fraunces",
      data: fraunces,
      style: "italic" as const,
      weight: 500 as const,
    },
  ];

  if (!list) {
    return new ImageResponse(<FallbackOG />, {
      width: 1200,
      height: 630,
      fonts,
    });
  }

  const { data: allItems } = await supabaseClient
    .from("wish_items")
    .select("*")
    .eq("list_id", list.id)
    .eq("is_archived", false)
    .order("is_pinned", { ascending: false })
    .order("created_at", { ascending: false })
    .returns<WishItem[]>();

  const items = allItems ?? [];

  return new ImageResponse(
    <Card list={list} items={items} accent={list.color_hex} />,
    {
      width: 1200,
      height: 630,
      fonts,
    }
  );
}
