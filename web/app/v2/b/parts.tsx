"use client";

import { motion, useReducedMotion } from "motion/react";
import { useEffect, useRef, useState, type CSSProperties } from "react";
import { AppStoreButton, Wordmark } from "../_shared/brand";
import { NAV, SCREENS, WISHES } from "../_shared/data";
import { Phone } from "../_shared/fragments";
import { Tilt, useInView } from "../_shared/live";

const vars = (v: Record<string, string | number>) => v as CSSProperties;

/* ── Nav: day glass over the cream part of the page, night glass after dusk ── */
export function Nav() {
  const [night, setNight] = useState(false);

  useEffect(() => {
    // "night" regions: the dark half of the dusk gradient and everything after it.
    // The observer's root is a thin band where the nav sits, so this also holds
    // when the page jumps (anchor links) rather than scrolls.
    const zones = Array.from(document.querySelectorAll<HTMLElement>("[data-b-night]"));
    if (!zones.length || typeof IntersectionObserver === "undefined") return;
    const under = new Set<Element>();
    const io = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) under.add(entry.target);
          else under.delete(entry.target);
        }
        setNight(under.size > 0);
      },
      { rootMargin: "-40px 0px -92% 0px" },
    );
    zones.forEach((zone) => io.observe(zone));
    return () => io.disconnect();
  }, []);

  return (
    <header className="b-nav" data-night={night}>
      <nav className={`b-nav__pill g-glass ${night ? "" : "g-glass--day"}`} aria-label="Main">
        <a href="#top" className="b-nav__logo" aria-label="Gimme, back to top">
          <Wordmark />
        </a>
        {NAV.map((item) => (
          <a key={item.href} href={item.href} className="b-nav__link">
            {item.label}
          </a>
        ))}
        <AppStoreButton className={`g-btn g-btn--sm ${night ? "g-btn--primary" : "g-btn--ink"}`} label="Download" />
      </nav>
    </header>
  );
}

/* ── Hero stage: the light-mode phone with wishes stuck around it like stickers.
      With a mouse you can pick a sticker up; it springs back when you let go. ── */
/* size, tilt and parallax depth per sticker; where each one sits is set in b.css
   (the positions differ between phone and desktop) */
const STICKERS = [
  { size: 92, rot: -9, k: 20 },
  { size: 76, rot: 8, k: -14 },
  { size: 96, rot: -6, k: 24 },
  { size: 78, rot: 11, k: -18 },
  { size: 84, rot: -5, k: 14 },
  { size: 72, rot: 7, k: -22 },
];

export function HeroStage() {
  const reduce = useReducedMotion();
  const [canDrag, setCanDrag] = useState(false);

  useEffect(() => {
    setCanDrag(window.matchMedia("(hover: hover) and (pointer: fine)").matches);
  }, []);

  return (
    <Tilt className="b-stage">
      <div className="b-stage__glow" aria-hidden="true" />
      <div className="b-stage__phone">
        <Phone screens={[SCREENS.homeLight]} eager />
      </div>
      {WISHES.map((wish, i) => {
        const s = STICKERS[i];
        return (
          <motion.span
            key={wish.name}
            className={`b-sticker b-sticker--${i + 1}`}
            style={vars({
              "--size": `${s.size}px`,
              "--rot": `${s.rot}deg`,
              "--k": s.k,
            })}
            drag={canDrag && !reduce}
            dragSnapToOrigin
            dragElastic={0.6}
            // a thrown sticker carries momentum, so it earns a little bounce on the way home
            dragTransition={{ bounceStiffness: 260, bounceDamping: 18 }}
            whileDrag={{ scale: 1.12, zIndex: 9 }}
            whileTap={canDrag ? { scale: 1.06 } : undefined}
            role="img"
            aria-label={`${wish.name}, ${wish.price}`}
          >
            <img className="b-sticker__in" src={wish.image} alt="" width={400} height={400} draggable={false} />
            {wish.badge && <span className={`b-sticker__tag b-sticker__tag--${wish.badge.kind}`}>{wish.badge.text}</span>}
          </motion.span>
        );
      })}
    </Tilt>
  );
}

/* ── Dusk: the list goes out as one message, and a friend answers ── */
export function Chat() {
  const [ref, inView] = useInView<HTMLDivElement>({ once: true, threshold: 0.5, margin: "0px" });
  return (
    <div ref={ref} className="b-chat" data-inview={inView}>
      <div className="b-bubble b-bubble--me b-bubble--link">
        <span className="b-bubble__preview">
          <span className="b-bubble__tile g-emoji">🎂</span>
          <span>
            <b>Birthday · 6 wishes</b>
            <small>gimmelist.com</small>
          </span>
        </span>
      </div>
      <div className="b-bubble b-bubble--me">here’s the list, no pressure 😇</div>
      <div className="b-bubble b-bubble--them">ooh. calling the camera 📸</div>
      <div className="b-bubble b-bubble--them">don’t look at the list for a bit</div>
    </div>
  );
}
