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
  /** The list hides who reserves what (the owner's "Anonymous reservations" switch). */
  anonymous?: boolean;
}

/* ── Component ── */
export function WishItemCard({ item, shareToken, accent, anonymous = false }: Props) {
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
  const [imageFailed, setImageFailed]         = useState(false);
  const imageRef                              = useRef<HTMLImageElement>(null);
  const confettiTimer                         = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => { setMounted(true); }, []);

  // Shop images disappear over time. One that already failed before this code
  // took over the page would never report an error, so check once on mount.
  useEffect(() => {
    const img = imageRef.current;
    if (img && img.complete && img.naturalWidth === 0) setImageFailed(true);
  }, []);

  useEffect(() => {
    setClaimedByMe(getClaimedItems().includes(item.id));
  }, [item.id]);

  useEffect(() => {
    return () => {
      if (confettiTimer.current) clearTimeout(confettiTimer.current);
    };
  }, []);

  const closeModal = useCallback(() => {
    setShowModal(false);
    setName("");
    setComment("");
    setError("");
  }, []);

  // Escape closes the claim sheet
  useEffect(() => {
    if (!showModal) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") closeModal();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [showModal, closeModal]);

  const handleClaim = useCallback(async () => {
    // On a list with anonymous reservations nobody is asked for a name and none is
    // stored, exactly as in the app (SharedListView.swift).
    const claimer = anonymous ? "" : name.trim();
    if (!anonymous && !claimer) {
      setError("Please enter your name");
      return;
    }
    setLoading(true);
    setError("");
    const { data, error: rpcError } = await supabase.rpc("claim_item", {
      p_item_id: item.id,
      p_share_token: shareToken,
      p_claimer_name: claimer,
      p_comment: comment.trim() || null,
    });
    setLoading(false);
    if (rpcError || data?.error) {
      setError(data?.error ?? "Something went wrong. Try again.");
      return;
    }
    addClaimedItem(item.id);
    setReserved(true);
    setReservedBy(claimer);
    setReservedComment(comment.trim());
    setClaimedByMe(true);
    setJustClaimed(true);
    setShowConfetti(true);
    setShowModal(false);
    setName("");
    setComment("");
    confettiTimer.current = setTimeout(() => setShowConfetti(false), 1200);
  }, [item.id, shareToken, name, comment, anonymous]);

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
  const imageUrl  = item.image_url && !imageFailed ? item.image_url : null;

  return (
    <>
      {/* ── Card shell ── */}
      <div
        className={`s-card-outer relative h-full ${isUnavailable ? "opacity-60" : ""} ${
          showMyClaimInfo ? "s-claimed-ring" : ""
        }`}
        style={
          (showMyClaimInfo ? { borderColor: accent + "66", "--ring-c": ringColor } : {}) as React.CSSProperties
        }
      >
        <div className="s-card-inner relative overflow-hidden h-full flex flex-col">

          {/* Confetti burst overlay */}
          {showConfetti && <ConfettiBurst accent={accent} />}

          {/* Image area (always present — real image or gift placeholder) */}
          <div className="relative w-full aspect-square bg-white/[0.025] overflow-hidden">
            {imageUrl ? (
              <img
                ref={imageRef}
                src={imageUrl}
                alt=""
                className={`w-full h-full object-cover transition-all duration-700 ${isUnavailable ? "grayscale-[55%]" : ""}`}
                loading="lazy"
                onError={() => setImageFailed(true)}
              />
            ) : (
              <GiftPlaceholder accent={accent} />
            )}

            {/* Vignette */}
            <div className="absolute inset-x-0 bottom-0 h-14 bg-gradient-to-t from-black/35 to-transparent pointer-events-none" />

            {/* Status badges (compact) */}
            {item.is_purchased && (
              <div className="absolute top-2 right-2 flex items-center gap-1 rounded-full bg-[#1f9d47] px-2.5 py-1 text-[11.5px] font-semibold text-white shadow-md animate-scale-pop">
                <svg width="9" height="9" viewBox="0 0 12 12" fill="none">
                  <path d="M2.5 6.5L4.5 8.5L9.5 3.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
                Bought
              </div>
            )}
            {reserved && !item.is_purchased && !claimedByMe && (
              <div className="absolute top-2 right-2 rounded-full bg-black/55 backdrop-blur-md border border-white/15 px-2.5 py-1 text-[11.5px] font-medium text-white shadow-md">
                Reserved
              </div>
            )}
            {showMyClaimInfo && (
              <div
                className="absolute top-2 right-2 flex items-center gap-1 rounded-full px-2.5 py-1 text-[11.5px] font-bold shadow-md animate-scale-pop"
                style={{ backgroundColor: accent, color: contrastingText(accent) }}
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
                role="img"
                aria-label={`${priority.label} priority`}
              />
            </div>
          </div>

          {/* Content */}
          <div className="p-3 flex-1 flex flex-col">

            <h3
              className={`font-semibold text-[14px] leading-snug line-clamp-2 mb-1.5 ${
                isUnavailable ? "line-through s-muted" : "text-white"
              }`}
              title={item.title}
            >
              {item.title}
            </h3>

            {item.price_double != null && item.currency && (
              <p
                className={`text-[14px] font-semibold tabular-nums mb-auto ${
                  isUnavailable ? "s-dim" : "text-white/90"
                }`}
              >
                {formatPrice(item.price_double, item.currency)}
              </p>
            )}

            {/* Footer row: hostname + action */}
            <div className="flex items-center justify-between gap-2 mt-3 pt-2.5 min-h-[46px] border-t border-white/[0.07]">
              {item.url ? (
                <span className="text-[11.5px] s-dim truncate flex-1 min-w-0">
                  {hostFromURL(item.url)}
                </span>
              ) : (
                <span className="flex-1" />
              )}

              {showClaimButton && (
                <button
                  type="button"
                  onClick={() => setShowModal(true)}
                  className="shrink-0 relative z-10 rounded-full px-4 min-h-[36px] text-[13px] font-semibold transition-transform duration-200 active:scale-[0.96]"
                  style={{
                    backgroundColor: accent + "2E",
                    color: `color-mix(in srgb, ${accent} 62%, #fff)`,
                    border: `1px solid ${accent}66`,
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
                  className="shrink-0 relative z-10 min-h-[36px] px-1 text-[12.5px] s-muted underline underline-offset-2 hover:text-white transition-colors disabled:opacity-40"
                >
                  {loading ? "…" : "Unclaim"}
                </button>
              )}
              {reserved && !item.is_purchased && !claimedByMe && (
                <span className="shrink-0 text-[11.5px] s-dim">claimed</span>
              )}
              {item.is_purchased && (
                <span className="shrink-0 text-[11.5px] s-dim">bought</span>
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
            className="absolute inset-0 rounded-[24px] z-[1]"
          />
        )}
      </div>

      {/* ── Claim modal — portalled to body to escape CSS stacking contexts ── */}
      {showModal && mounted && createPortal(
        <div
          className="fixed inset-0 z-[9999] flex items-end sm:items-center justify-center overlay-backdrop animate-fade-in"
          onClick={(e) => {
            if (e.target === e.currentTarget) closeModal();
          }}
        >
          <div
            role="dialog"
            aria-modal="true"
            aria-label={`Claim ${item.title}`}
            className="w-full max-w-sm s-modal-outer rounded-t-[1.75rem] sm:rounded-[1.75rem] animate-slide-up sm:animate-scale-in"
          >
            <div className="s-modal-inner rounded-t-[calc(1.75rem-5px)] sm:rounded-[calc(1.75rem-5px)] p-6">

              {/* Drag handle (mobile) */}
              <div className="w-9 h-1 rounded-full bg-white/15 mx-auto mb-5 sm:hidden" />

              {/* Item preview */}
              {imageUrl ? (
                <div className="w-16 h-16 rounded-2xl overflow-hidden mb-4 mx-auto ring-1 ring-white/[0.08]">
                  <img src={imageUrl} alt="" className="w-full h-full object-cover"/>
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

              <h2 className="s-modal-title text-center mb-1 line-clamp-2">
                {item.title}
              </h2>
              {item.price_double != null && item.currency && (
                <p className="s-muted text-[15px] text-center mb-1 tabular-nums">
                  {formatPrice(item.price_double, item.currency)}
                </p>
              )}
              <p className="s-dim text-[14px] leading-snug text-center mb-6 max-w-[30ch] mx-auto">
                {anonymous
                  ? "This list keeps reservations anonymous. Nobody will see who is getting this."
                  : "Let everyone know you\u2019re getting this"}
              </p>

              {/* Form */}
              <div className="space-y-3 mb-5">
                {!anonymous && (
                  <input
                    type="text"
                    placeholder="Your name"
                    aria-label="Your name"
                    autoComplete="given-name"
                    value={name}
                    onChange={(e) => { setName(e.target.value); setError(""); }}
                    onKeyDown={(e) => e.key === "Enter" && handleClaim()}
                    autoFocus
                    className="s-field"
                  />
                )}
                <textarea
                  placeholder="Leave a message (optional)"
                  aria-label="Message (optional)"
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                  rows={2}
                  autoFocus={anonymous}
                  className="s-field"
                />
              </div>

              {/* Reservation info (shown in modal so card stays compact) */}
              {!anonymous && reserved && reservedBy && !claimedByMe && (
                <p className="s-muted text-[13px] text-center mb-4">
                  Currently reserved by {reservedBy}
                </p>
              )}

              {error && (
                <p role="alert" className="text-red-400 text-[13.5px] text-center mb-3 flex items-center justify-center gap-1.5">
                  <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
                    <path d="M6 1L11 10H1L6 1z" stroke="currentColor" strokeWidth="1.2" strokeLinejoin="round"/>
                    <path d="M6 5v2.5M6 9v.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/>
                  </svg>
                  {error}
                </p>
              )}

              <button
                onClick={handleClaim}
                disabled={loading || (!anonymous && !name.trim())}
                className="w-full rounded-[14px] min-h-[52px] font-semibold text-[16px] transition-all disabled:opacity-35 active:scale-[0.98]"
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
                onClick={closeModal}
                className="w-full mt-1.5 min-h-[44px] text-[14.5px] s-muted hover:text-white transition-colors"
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
          className="col-span-2 flex items-center gap-3 rounded-[20px] p-3 no-underline l-anim mt-2 g-glass"
          onClick={() => setJustClaimed(false)}
        >
          <img
            src="/img/icon-dark.png"
            alt=""
            width={36}
            height={36}
            className="shrink-0"
          />
          <div className="min-w-0 flex-1">
            <p className="text-[13.5px] font-semibold leading-tight text-white">Want your own wishlist?</p>
            <p className="text-[12.5px] mt-0.5 s-muted">Get Gimme, it&apos;s free</p>
          </div>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" className="shrink-0 s-muted" aria-hidden="true">
            <path d="M4 10L10 4M10 4H5.5M10 4V8.5" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </a>
      )}
    </>
  );
}
