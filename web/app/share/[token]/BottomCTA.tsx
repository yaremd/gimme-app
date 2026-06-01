"use client";

import { useEffect, useState } from "react";

const APP_STORE_URL = "https://apps.apple.com/app/gimme-wishlist-gift-ideas/id6762543923";
const DISMISS_KEY = "gimme_share_cta_dismissed";

export function BottomCTA() {
  const [dismissed, setDismissed] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
    setDismissed(sessionStorage.getItem(DISMISS_KEY) === "1");
  }, []);

  function handleDismiss(e: React.MouseEvent) {
    e.preventDefault();
    e.stopPropagation();
    sessionStorage.setItem(DISMISS_KEY, "1");
    setDismissed(true);
  }

  if (!mounted) return null;

  if (dismissed) {
    return (
      <div className="fixed bottom-0 inset-x-0 z-40 pointer-events-none">
        <div className="absolute inset-0 bg-gradient-to-t from-[#0C0C0F] via-[#0C0C0F]/80 to-transparent h-24" />
        <div className="relative max-w-lg mx-auto px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-3 flex items-center justify-center gap-2 pointer-events-auto">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="text-[11px] font-semibold tracking-[0.18em] uppercase text-white/35 no-underline hover:text-white/70 transition-colors"
          >
            Gimme · Get the app
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed bottom-0 inset-x-0 z-40 p-4 pb-[max(1rem,env(safe-area-inset-bottom))] pointer-events-none">
      <div className="absolute inset-0 bg-gradient-to-t from-[#0C0C0F] via-[#0C0C0F]/96 to-transparent pointer-events-none" />
      <div className="relative max-w-lg mx-auto pointer-events-auto">
        <button
          type="button"
          onClick={handleDismiss}
          aria-label="Dismiss"
          className="absolute -top-2 -right-2 z-10 w-7 h-7 rounded-full bg-[#18181B] border border-white/10 flex items-center justify-center text-white/45 hover:text-white/80 hover:bg-[#222226] transition-all duration-300 shadow-lg"
        >
          <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
            <path d="M2 2L8 8M8 2L2 8" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
          </svg>
        </button>

        <a
          href={APP_STORE_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="s-card-outer flex items-center justify-between gap-4 no-underline"
        >
          <div className="s-card-inner w-full p-4 flex items-center justify-between gap-4">
            <div className="flex items-center gap-3 min-w-0">
              <img src="/app-icon.png" alt="" width={40} height={40} className="shrink-0 rounded-[12px]" />
              <div className="min-w-0">
                <p className="font-semibold text-[14px] text-white">Get Gimme</p>
                <p className="text-white/35 text-[12px] mt-0.5">Make your own wishlist in 30 seconds</p>
              </div>
            </div>
            <div className="shrink-0 inline-flex items-center gap-2 rounded-full pl-4 pr-1.5 py-1.5 text-[12px] font-bold s-download-cta no-underline">
              <span>Download</span>
              <span className="s-cta-arrow w-6 h-6 rounded-full bg-black/10 flex items-center justify-center">
                <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                  <path d="M2.5 7.5L7.5 2.5M7.5 2.5H3.5M7.5 2.5V6.5" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </span>
            </div>
          </div>
        </a>
      </div>
    </div>
  );
}
