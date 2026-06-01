"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { createPortal } from "react-dom";
import { supabase, WishItem } from "@/lib/supabase";

/* ── Priority config ── */
const priorityConfig = {
  high:   { label: "High",   dot: "bg-red-400",    badge: "bg-red-500/15 text-red-400" },
  medium: { label: "Med",    dot: "bg-yellow-400",  badge: "bg-yellow-500/15 text-yellow-400" },
  low:    { label: "Low",    dot: "bg-green-400",   badge: "bg-green-500/15 text-green-400" },
};

/* ── Confetti particle definitions ── */
const CONFETTI = [
  { cx: "0px",    cy: "-62px",  cr: "20deg",   color: "#FFD60A", delay: 0 },
  { cx: "44px",   cy: "-44px",  cr: "-15deg",  color: "#FF6B6B", delay: 40 },
  { cx: "62px",   cy: "0px",    cr: "30deg",   color: "#32D74B", delay: 80 },
  { cx: "44px",   cy: "44px",   cr: "-25deg",  color: "#0AC8FF", delay: 30 },
  { cx: "-44px",  cy: "-44px",  cr: "10deg",   color: "#FF9F0A", delay: 60 },
  { cx: "-62px",  cy: "0px",    cr: "-30deg",  color: "#BF5AF2", delay: 20 },
  { cx: "-30px",  cy: "-58px",  cr: "40deg",   color: "#FF6B6B", delay: 50 },
  { cx: "30px",   cy: "-58px",  cr: "-40deg",  color: "#FFD60A", delay: 70 },
  { cx: "-50px",  cy: "34px",   cr: "15deg",   color: "#32D74B", delay: 10 },
  { cx: "50px",   cy: "-28px",  cr: "-20deg",  color: "#0AC8FF", delay: 90 },
];

/* ── Helpers ── */
function contrastingText(hex: string): string {
  const h = hex.replace("#", "");
  const r = parseInt(h.substring(0, 2), 16) / 255;
  const g = parseInt(h.substring(2, 4), 16) / 255;
  const b = parseInt(h.substring(4, 6), 16) / 255;
  const luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  return luminance > 0.45 ? "#000000" : "#ffffff";
}

function formatPrice(price: number, currency: string) {
  try {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency,
      minimumFractionDigits: 2,
    }).format(price);
  } catch {
    return `${price} ${currency}`;
  }
}

function hostFromURL(url: string): string {
  try {
    return new URL(url).hostname.replace("www.", "");
  } catch {
    return url;
  }
}

/* ── LocalStorage claim tracking ── */
const STORAGE_KEY = "gimme_claimed_items";

function getClaimedItems(): string[] {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "[]");
  } catch {
    return [];
  }
}

function addClaimedItem(id: string) {
  const items = getClaimedItems();
  if (!items.includes(id)) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify([...items, id]));
  }
}

function removeClaimedItem(id: string) {
  const items = getClaimedItems().filter((i) => i !== id);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
}

/* ── Confetti burst (isolated, purely CSS-driven) ── */
function ConfettiBurst({ accent }: { accent: string }) {
  return (
    <div className="absolute inset-0 pointer-events-none flex items-center justify-center" style={{ zIndex: 20 }}>
      {CONFETTI.map((p, i) => (
        <span
          key={i}
          className="confetti-dot"
          style={{
            "--cx": p.cx,
            "--cy": p.cy,
            "--cr": p.cr,
            backgroundColor: i === 0 ? accent : p.color,
            animationDelay: `${p.delay}ms`,
          } as React.CSSProperties}
        />
      ))}
    </div>
  );
}

/* ── Gift box placeholder for items without an image ── */
function GiftPlaceholder({ accent }: { accent: string }) {
  return (
    <div
      className="relative w-full h-full flex items-center justify-center"
      style={{
        background: `linear-gradient(135deg, ${accent}14 0%, ${accent}05 60%, transparent 100%)`,
      }}
    >
      <svg width="46" height="46" viewBox="0 0 48 48" fill="none" aria-hidden="true">
        <ellipse cx="24" cy="40" rx="14" ry="2" fill="black" fillOpacity="0.18" />
        <rect x="11" y="18" width="26" height="22" rx="2.5" fill="white" fillOpacity="0.03" stroke={accent} strokeWidth="1.3" strokeOpacity="0.55" />
        <rect x="9" y="13" width="30" height="7" rx="2" fill={accent} fillOpacity="0.65" />
        <line x1="24" y1="13" x2="24" y2="40" stroke={accent} strokeWidth="1.4" strokeOpacity="0.65" />
        <line x1="11" y1="20" x2="37" y2="20" stroke={accent} strokeWidth="1.4" strokeOpacity="0.65" />
        <path d="M19 12 Q22 4 24 12" stroke={accent} strokeWidth="1.4" strokeLinecap="round" fill="none" strokeOpacity="0.65" />
        <path d="M24 12 Q26 4 29 12" stroke={accent} strokeWidth="1.4" strokeLinecap="round" fill="none" strokeOpacity="0.65" />
      </svg>
    </div>
  );
}

/* ── Animated checkmark SVG ── */
function AnimatedCheck({ color }: { color: string }) {
  return (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none" className="shrink-0">
      <path
        d="M2.5 6.5L4.5 8.5L9.5 3.5"
        stroke={color}
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="animate-draw-check"
      />
    </svg>
  );
}

/* ── Props ── */
interface Props {
  item: WishItem;
  shareToken: string;
  accent: string;
}

/* ── Component ── */
export function WishItemCard({ item, shareToken, accent }: Props) {
  const priority = priorityConfig[item.priority] ?? priorityConfig.medium;

  const [reserved, setReserved]               = useState(item.is_reserved_by_friend);
  const [reservedBy, setReservedBy]           = useState(item.reserved_by_name ?? "");
  const [reservedComment, setReservedComment] = useState(item.reserved_comment ?? "");
  const [claimedByMe, setClaimedByMe]         = useState(false);
  const [showModal, setShowModal]             = useState(false);
  const [name, setName]                       = useState("");
  const [comment, setComment]                 = useState("");
  const [loading, setLoading]                 = useState(false);
  const [error, setError]                     = useState("");
  const [justClaimed, setJustClaimed]         = useState(false);
  const [showConfetti, setShowConfetti]       = useState(false);
  const [mounted, setMounted]                 = useState(false);
  const confettiTimer                         = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => { setMounted(true); }, []);

  useEffect(() => {
    setClaimedByMe(getClaimedItems().includes(item.id));
  }, [item.id]);

  useEffect(() => {
    return () => {
      if (confettiTimer.current) clearTimeout(confettiTimer.current);
    };
  }, []);

  const handleClaim = useCallback(async () => {
    if (!name.trim()) {
      setError("Please enter your name");
      return;
    }
    setLoading(true);
    setError("");
    const { data, error: rpcError } = await supabase.rpc("claim_item", {
      p_item_id: item.id,
      p_share_token: shareToken,
      p_claimer_name: name.trim(),
      p_comment: comment.trim() || null,
    });
    setLoading(false);
    if (rpcError || data?.error) {
      setError(data?.error ?? "Something went wrong. Try again.");
      return;
    }
    addClaimedItem(item.id);
    setReserved(true);
    setReservedBy(name.trim());
    setReservedComment(comment.trim());
    setClaimedByMe(true);
    setJustClaimed(true);
    setShowConfetti(true);
    setShowModal(false);
    setName("");
    setComment("");
    confettiTimer.current = setTimeout(() => setShowConfetti(false), 1200);
  }, [item.id, shareToken, name, comment]);

  async function handleUnclaim() {
    setLoading(true);
    const { data, error: rpcError } = await supabase.rpc("unclaim_item", {
      p_item_id: item.id,
      p_share_token: shareToken,
    });
    setLoading(false);
    if (rpcError || data?.error) return;
    removeClaimedItem(item.id);
    setReserved(false);
    setReservedBy("");
    setReservedComment("");
    setClaimedByMe(false);
    setJustClaimed(false);
  }

  const isUnavailable   = item.is_purchased || (reserved && !claimedByMe);
  const showClaimButton = !item.is_purchased && !reserved;
  const showMyClaimInfo = !item.is_purchased && reserved && claimedByMe;

  const ringColor = `${accent}40`;

  return (
    <>
      {/* ── Card shell ── */}
      <div
        className={`s-card-outer relative h-full atelier-card transition-all duration-700 ${
          isUnavailable ? "opacity-50" : ""
        } ${showMyClaimInfo ? "s-claimed-ring" : ""}`}
        style={{
          transitionTimingFunction: "var(--s-ease, cubic-bezier(0.32, 0.72, 0, 1))",
          borderLeft: `2px solid ${accent}${showMyClaimInfo ? "70" : "1E"}`,
          ...(showMyClaimInfo
            ? {
                borderColor: accent + "35",
                "--ring-c": ringColor,
              }
            : {}),
        } as React.CSSProperties}
      >
        <div className="s-card-inner relative overflow-hidden h-full flex flex-col">

          {/* Confetti burst overlay */}
          {showConfetti && <ConfettiBurst accent={accent} />}

          {/* Image area (always present — real image or gift placeholder) */}
          <div className="relative w-full aspect-square bg-white/[0.025] overflow-hidden">
            {item.image_url ? (
              <img
                src={item.image_url}
                alt=""
                className={`w-full h-full object-cover transition-all duration-700 atelier-card-image ${isUnavailable ? "grayscale-[55%]" : ""}`}
                loading="lazy"
              />
            ) : (
              <GiftPlaceholder accent={accent} />
            )}

            {/* Vignette */}
            <div className="absolute inset-x-0 bottom-0 h-14 bg-gradient-to-t from-black/35 to-transparent pointer-events-none" />

            {/* Status badges (compact) */}
            {item.is_purchased && (
              <div className="absolute top-2 right-2 flex items-center gap-1 rounded-full bg-[#30D158]/90 backdrop-blur-md px-2 py-1 text-[10px] font-semibold text-white shadow-md animate-scale-pop">
                <svg width="9" height="9" viewBox="0 0 12 12" fill="none">
                  <path d="M2.5 6.5L4.5 8.5L9.5 3.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
                Bought
              </div>
            )}
            {reserved && !item.is_purchased && !claimedByMe && (
              <div className="absolute top-2 right-2 rounded-full bg-white/15 backdrop-blur-md border border-white/10 px-2 py-1 text-[10px] font-medium text-white/80 shadow-md">
                Reserved
              </div>
            )}
            {showMyClaimInfo && (
              <div
                className="absolute top-2 right-2 flex items-center gap-1 rounded-full backdrop-blur-md px-2 py-1 text-[10px] font-bold shadow-md animate-scale-pop"
                style={{ backgroundColor: accent + "EC", color: contrastingText(accent) }}
              >
                <AnimatedCheck color={contrastingText(accent)} />
                Yours
              </div>
            )}

            {/* Priority dot */}
            <div className="absolute top-2 left-2">
              <div
                className={`w-2 h-2 rounded-full ${priority.dot} shadow-md ring-1 ring-black/25`}
                title={`${priority.label} priority`}
              />
            </div>
          </div>

          {/* Content */}
          <div className="p-3 flex-1 flex flex-col">

            <h3
              className={`font-semibold text-[13px] leading-snug line-clamp-2 mb-1.5 ${
                isUnavailable ? "line-through text-white/35" : "text-white"
              }`}
              title={item.title}
            >
              {item.title}
            </h3>

            {item.price_double != null && item.currency && (
              <p
                className={`text-[13px] font-bold tabular-nums mb-auto ${
                  isUnavailable ? "text-white/30" : "text-white/85"
                }`}
              >
                {formatPrice(item.price_double, item.currency)}
              </p>
            )}

            {/* Footer row: hostname + action */}
            <div className="flex items-center justify-between gap-2 mt-3 pt-3 border-t border-white/[0.05]">
              {item.url ? (
                <span className="text-[10px] text-white/30 truncate flex-1 min-w-0">
                  {hostFromURL(item.url)}
                </span>
              ) : (
                <span className="flex-1" />
              )}

              {showClaimButton && (
                <button
                  type="button"
                  onClick={() => setShowModal(true)}
                  className="atelier-claim shrink-0 relative z-10 rounded-full px-3 py-1.5 text-[11px] font-semibold transition-all duration-300 active:scale-[0.97]"
                  style={{
                    backgroundColor: accent + "22",
                    color: accent,
                    border: `1px solid ${accent}40`,
                  }}
                >
                  Claim
                </button>
              )}
              {showMyClaimInfo && (
                <button
                  type="button"
                  onClick={handleUnclaim}
                  disabled={loading}
                  className="shrink-0 relative z-10 text-[10px] text-white/45 hover:text-white/70 italic transition-colors disabled:opacity-40"
                >
                  {loading ? "..." : "tap to unclaim"}
                </button>
              )}
              {reserved && !item.is_purchased && !claimedByMe && (
                <span className="shrink-0 text-[10px] text-white/30">claimed</span>
              )}
              {item.is_purchased && (
                <span className="shrink-0 text-[10px] text-white/30">bought</span>
              )}
            </div>
          </div>
        </div>

        {/* Stretched link covers entire card — buttons sit above via z-10 */}
        {item.url && (
          <a
            href={item.url}
            target="_blank"
            rel="noopener noreferrer"
            aria-label={`Open ${item.title}`}
            className="absolute inset-0 rounded-[1.5rem] z-[1]"
          />
        )}
      </div>

      {/* ── Claim modal — portalled to body to escape CSS stacking contexts ── */}
      {showModal && mounted && createPortal(
        <div
          className="fixed inset-0 z-[9999] flex items-end sm:items-center justify-center overlay-backdrop animate-fade-in"
          onClick={(e) => {
            if (e.target === e.currentTarget) {
              setShowModal(false);
              setName("");
              setComment("");
              setError("");
            }
          }}
        >
          <div className="w-full max-w-sm s-modal-outer rounded-t-[1.75rem] sm:rounded-[1.75rem] animate-slide-up sm:animate-scale-in">
            <div className="s-modal-inner rounded-t-[calc(1.75rem-5px)] sm:rounded-[calc(1.75rem-5px)] p-6">

              {/* Drag handle (mobile) */}
              <div className="w-9 h-1 rounded-full bg-white/15 mx-auto mb-5 sm:hidden" />

              {/* Item preview */}
              {item.image_url ? (
                <div className="w-16 h-16 rounded-2xl overflow-hidden mb-4 mx-auto ring-1 ring-white/[0.08]">
                  <img src={item.image_url} alt={item.title} className="w-full h-full object-cover"/>
                </div>
              ) : (
                <div
                  className="w-12 h-12 rounded-2xl mb-4 mx-auto flex items-center justify-center"
                  style={{ backgroundColor: accent + "18", border: `1px solid ${accent}22` }}
                >
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                    <path d="M20 12v10H4V12M22 7H2v5h20V7zM12 22V7M12 7H7.5a2.5 2.5 0 010-5C11 2 12 7 12 7zM12 7h4.5a2.5 2.5 0 000-5C13 2 12 7 12 7z" stroke={accent} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                </div>
              )}

              <h2 className="text-[17px] font-bold text-center mb-0.5 leading-snug line-clamp-2">
                {item.title}
              </h2>
              {item.price_double != null && item.currency && (
                <p className="text-white/40 text-sm text-center mb-1">
                  {formatPrice(item.price_double, item.currency)}
                </p>
              )}
              <p className="text-white/25 text-[12px] text-center mb-6">
                Let everyone know you&apos;re getting this
              </p>

              {/* Form */}
              <div className="space-y-3 mb-5">
                <input
                  type="text"
                  placeholder="Your name"
                  value={name}
                  onChange={(e) => { setName(e.target.value); setError(""); }}
                  onKeyDown={(e) => e.key === "Enter" && handleClaim()}
                  autoFocus
                  className="w-full rounded-[14px] bg-white/[0.06] border border-white/[0.08] px-4 py-3.5 text-white placeholder-white/25 outline-none focus:border-white/20 focus:bg-white/[0.08] transition-all text-[15px]"
                />
                <textarea
                  placeholder="Leave a message (optional)"
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                  rows={2}
                  className="w-full rounded-[14px] bg-white/[0.06] border border-white/[0.08] px-4 py-3.5 text-white placeholder-white/25 outline-none focus:border-white/20 focus:bg-white/[0.08] transition-all resize-none text-[15px]"
                />
              </div>

              {/* Reservation info (shown in modal so card stays compact) */}
              {reserved && reservedBy && !claimedByMe && (
                <p className="text-white/35 text-[12px] text-center mb-4 italic">
                  Currently reserved by {reservedBy}
                </p>
              )}

              {error && (
                <p className="text-red-400 text-[12px] text-center mb-3 flex items-center justify-center gap-1.5">
                  <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                    <path d="M6 1L11 10H1L6 1z" stroke="currentColor" strokeWidth="1.2" strokeLinejoin="round"/>
                    <path d="M6 5v2.5M6 9v.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/>
                  </svg>
                  {error}
                </p>
              )}

              <button
                onClick={handleClaim}
                disabled={loading || !name.trim()}
                className="w-full rounded-[14px] py-3.5 font-bold text-[15px] transition-all disabled:opacity-30 active:scale-[0.98]"
                style={{
                  backgroundColor: accent,
                  color: contrastingText(accent),
                  boxShadow: `0 4px 24px ${accent}45`,
                }}
              >
                {loading ? (
                  <span className="animate-pulse-soft">Claiming...</span>
                ) : (
                  "Claim this gift"
                )}
              </button>

              <button
                onClick={() => { setShowModal(false); setName(""); setComment(""); setError(""); }}
                className="w-full mt-2 py-2.5 text-[13px] text-white/28 hover:text-white/50 transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>,
        document.body
      )}

      {/* Post-claim mini download prompt — appears below card after successful claim */}
      {justClaimed && (
        <a
          href="https://apps.apple.com/app/gimme-wishlist-gift-ideas/id6762543923"
          target="_blank"
          rel="noopener noreferrer"
          className="col-span-2 flex items-center gap-3 rounded-[1.25rem] p-3 no-underline l-anim mt-1"
          style={{
            background: `linear-gradient(135deg, ${accent}10, ${accent}06)`,
            border: `1px solid ${accent}18`,
          }}
          onClick={() => setJustClaimed(false)}
        >
          <img
            src="/app-icon.png"
            alt="Gimme"
            width={36}
            height={36}
            className="rounded-[10px] shrink-0"
          />
          <div className="min-w-0 flex-1">
            <p className="text-[13px] font-semibold text-white">Want your own wishlist?</p>
            <p className="text-[11px] mt-0.5" style={{ color: accent + "99" }}>Get Gimme — it&apos;s free</p>
          </div>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" className="shrink-0 opacity-30">
            <path d="M4 10L10 4M10 4H5.5M10 4V8.5" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </a>
      )}
    </>
  );
}
