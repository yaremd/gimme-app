import { ImageResponse } from "@vercel/og";
import { createClient } from "@supabase/supabase-js";
import type { WishList, WishItem } from "@/lib/supabase";

export const runtime = "edge";
export const alt = "Gimme Wishlist";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/* ── Hex → RGB components ── */
function hexToRgb(hex: string): [number, number, number] {
  const h = hex.replace("#", "");
  return [
    parseInt(h.substring(0, 2), 16),
    parseInt(h.substring(2, 4), 16),
    parseInt(h.substring(4, 6), 16),
  ];
}

/* ── Fallback OG ── */
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
        fontFamily: "system-ui, sans-serif",
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
          <div style={{ fontSize: 42, fontWeight: 800, color: "white" }}>Gimme</div>
          <div style={{ fontSize: 20, color: "rgba(255,255,255,0.4)" }}>Wishlist & Gift Ideas</div>
        </div>
      </div>
    </div>
  );
}

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

  const { data: list } = await supabaseClient
    .from("wish_lists")
    .select("*")
    .eq("share_token", token)
    .eq("is_shared", true)
    .single<WishList>();

  if (!list) {
    return new ImageResponse(<FallbackOG />, { ...size });
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
  const itemCount = items.length;
  const claimedCount = items.filter((i) => i.is_reserved_by_friend && !i.is_purchased).length;

  // Up to 4 items with images for thumbnails
  const imageItems = items.filter((i) => i.image_url).slice(0, 4);

  // Parse accent color
  const [r, g, b] = hexToRgb(list.color_hex);
  const accentSoft  = `rgba(${r},${g},${b},0.18)`;
  const accentGlow  = `rgba(${r},${g},${b},0.35)`;
  const accentSolid = list.color_hex;

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          background: `linear-gradient(135deg, #14121F 0%, #0D0D0F 55%, #0C0C0F 100%)`,
          fontFamily: "system-ui, -apple-system, sans-serif",
          position: "relative",
          overflow: "hidden",
        }}
      >
        {/* ── Accent radial glow top-left ── */}
        <div
          style={{
            position: "absolute",
            top: -120,
            left: -120,
            width: 560,
            height: 560,
            borderRadius: "50%",
            background: `radial-gradient(circle, ${accentGlow} 0%, transparent 70%)`,
            pointerEvents: "none",
          }}
        />

        {/* ── Subtle grid texture ── */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            backgroundImage: `linear-gradient(rgba(255,255,255,0.018) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.018) 1px, transparent 1px)`,
            backgroundSize: "60px 60px",
            pointerEvents: "none",
          }}
        />

        {/* ── Main content row ── */}
        <div
          style={{
            display: "flex",
            flex: 1,
            padding: "56px 72px",
            gap: 64,
            alignItems: "center",
          }}
        >
          {/* ── Left column: list info ── */}
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              flex: "0 0 auto",
              width: imageItems.length > 0 ? 480 : "100%",
              justifyContent: "center",
              gap: 0,
            }}
          >
            {/* Emoji icon */}
            <div
              style={{
                width: 96,
                height: 96,
                borderRadius: 28,
                backgroundColor: accentSoft,
                border: `1.5px solid rgba(${r},${g},${b},0.28)`,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                fontSize: 52,
                marginBottom: 28,
                boxShadow: `0 16px 48px rgba(${r},${g},${b},0.18)`,
              }}
            >
              {list.emoji}
            </div>

            {/* List name */}
            <div
              style={{
                fontSize: 52,
                fontWeight: 800,
                color: "white",
                lineHeight: 1.1,
                letterSpacing: "-0.02em",
                marginBottom: 16,
                maxWidth: 460,
              }}
            >
              {list.name}
            </div>

            {/* Item count + claimed badge row */}
            <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
              <div
                style={{
                  fontSize: 22,
                  color: "rgba(255,255,255,0.42)",
                  fontWeight: 500,
                }}
              >
                {itemCount} {itemCount === 1 ? "wish" : "wishes"}
              </div>

              {claimedCount > 0 && (
                <>
                  <div style={{ width: 4, height: 4, borderRadius: 2, backgroundColor: "rgba(255,255,255,0.2)" }} />
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: 7,
                      backgroundColor: "rgba(52,196,138,0.14)",
                      border: "1px solid rgba(52,196,138,0.22)",
                      borderRadius: 9999,
                      padding: "5px 14px",
                      fontSize: 17,
                      fontWeight: 600,
                      color: "#34C48A",
                    }}
                  >
                    {/* Checkmark */}
                    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                      <path d="M3 7.5L5.5 10L11 4" stroke="#34C48A" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                    {claimedCount} claimed
                  </div>
                </>
              )}
            </div>

            {/* CTA pill */}
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 10,
                marginTop: 36,
                backgroundColor: accentSolid,
                borderRadius: 9999,
                padding: "13px 24px",
                width: "fit-content",
                boxShadow: `0 8px 28px rgba(${r},${g},${b},0.38)`,
              }}
            >
              <div
                style={{
                  fontSize: 19,
                  fontWeight: 700,
                  color: "white",
                  letterSpacing: "-0.01em",
                }}
              >
                Tap to claim a gift
              </div>
              {/* Arrow */}
              <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
                <path d="M4.5 13.5L13.5 4.5M13.5 4.5H6.5M13.5 4.5V11.5" stroke="white" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
          </div>

          {/* ── Right column: item thumbnails ── */}
          {imageItems.length > 0 && (
            <div
              style={{
                display: "flex",
                flex: 1,
                alignItems: "center",
                justifyContent: "flex-end",
              }}
            >
              {imageItems.length === 1 && (
                <div
                  style={{
                    width: 340,
                    height: 340,
                    borderRadius: 28,
                    overflow: "hidden",
                    border: "1.5px solid rgba(255,255,255,0.1)",
                    boxShadow: "0 24px 64px rgba(0,0,0,0.4)",
                    display: "flex",
                  }}
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={imageItems[0].image_url!} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                </div>
              )}

              {imageItems.length === 2 && (
                <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
                  {imageItems.map((item, i) => (
                    <div
                      key={i}
                      style={{
                        width: 220,
                        height: 220,
                        borderRadius: 22,
                        overflow: "hidden",
                        border: "1.5px solid rgba(255,255,255,0.08)",
                        boxShadow: "0 12px 40px rgba(0,0,0,0.35)",
                        display: "flex",
                        transform: i === 0 ? "translateX(20px)" : "translateX(-20px)",
                      }}
                    >
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={item.image_url!} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                    </div>
                  ))}
                </div>
              )}

              {imageItems.length >= 3 && (
                <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
                  {/* Top row */}
                  <div style={{ display: "flex", gap: 12 }}>
                    {imageItems.slice(0, 2).map((item, i) => (
                      <div
                        key={i}
                        style={{
                          width: 192,
                          height: 192,
                          borderRadius: 20,
                          overflow: "hidden",
                          border: "1.5px solid rgba(255,255,255,0.09)",
                          boxShadow: "0 8px 32px rgba(0,0,0,0.3)",
                          display: "flex",
                        }}
                      >
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img src={item.image_url!} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                      </div>
                    ))}
                  </div>
                  {/* Bottom row */}
                  <div style={{ display: "flex", gap: 12 }}>
                    {imageItems.slice(2, 4).map((item, i) => (
                      <div
                        key={i}
                        style={{
                          width: 192,
                          height: 192,
                          borderRadius: 20,
                          overflow: "hidden",
                          border: "1.5px solid rgba(255,255,255,0.09)",
                          boxShadow: "0 8px 32px rgba(0,0,0,0.3)",
                          display: "flex",
                          ...(i === 1 && imageItems.length === 3
                            ? { opacity: 0.5, filter: "blur(1px)" }
                            : {}),
                        }}
                      >
                        {imageItems[2 + i] ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={imageItems[2 + i].image_url!} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                        ) : (
                          <div
                            style={{
                              width: "100%",
                              height: "100%",
                              backgroundColor: accentSoft,
                              display: "flex",
                              alignItems: "center",
                              justifyContent: "center",
                              fontSize: 28,
                              color: "rgba(255,255,255,0.2)",
                            }}
                          >
                            {itemCount - 3 > 0 ? `+${itemCount - 3}` : ""}
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        {/* ── Footer bar ── */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            padding: "18px 72px",
            borderTop: "1px solid rgba(255,255,255,0.06)",
          }}
        >
          {/* Gimme branding */}
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <div
              style={{
                width: 32,
                height: 32,
                borderRadius: 9,
                backgroundColor: accentSoft,
                border: `1px solid rgba(${r},${g},${b},0.25)`,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                fontSize: 18,
                fontWeight: 800,
                color: accentSolid,
              }}
            >
              G
            </div>
            <div
              style={{
                fontSize: 16,
                fontWeight: 600,
                color: "rgba(255,255,255,0.38)",
                letterSpacing: "0.06em",
                textTransform: "uppercase",
              }}
            >
              gimmelist.com
            </div>
          </div>

          {/* Right: item count summary */}
          <div
            style={{
              fontSize: 15,
              color: "rgba(255,255,255,0.24)",
            }}
          >
            Wishlist &amp; Gift Ideas
          </div>
        </div>
      </div>
    ),
    { ...size }
  );
}
