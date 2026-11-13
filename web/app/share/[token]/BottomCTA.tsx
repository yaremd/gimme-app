"use client";

import { useEffect, useState } from "react";
import { APP_STORE_URL } from "@/app/_site/brand";

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
        <div className="absolute inset-x-0 bottom-0 h-24 bg-gradient-to-t from-[#0c0c11] via-[#0c0c11]/80 to-transparent" />
        <div className="relative max-w-lg mx-auto px-4 pb-[max(0.5rem,env(safe-area-inset-bottom))] pt-3 flex items-center justify-center pointer-events-auto">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="s-kicker s-muted inline-flex items-center min-h-[44px] px-4 no-underline hover:text-white transition-colors"
          >
            Gimme · Get the app
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed bottom-0 inset-x-0 z-40 p-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] pointer-events-none">
      <div className="absolute inset-0 bg-gradient-to-t from-[#0c0c11] via-[#0c0c11]/90 to-transparent pointer-events-none" />
      <div className="relative max-w-lg mx-auto pointer-events-auto">
        <button type="button" onClick={handleDismiss} aria-label="Dismiss" className="s-bar__close">
          <span>
            <svg width="10" height="10" viewBox="0 0 10 10" fill="none" aria-hidden="true">
              <path d="M2 2L8 8M8 2L2 8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
          </span>
        </button>

        <a href={APP_STORE_URL} target="_blank" rel="noopener noreferrer" className="s-bar g-glass">
          <span className="flex items-center gap-3 min-w-0">
            <img src="/img/icon-dark.png" alt="" width={42} height={42} />
            <span className="min-w-0">
              <b>Get Gimme</b>
              <small>Make your own wishlist in 30 seconds</small>
            </span>
          </span>
          <span className="g-btn g-btn--primary g-btn--sm">Download</span>
        </a>
      </div>
    </div>
  );
}
