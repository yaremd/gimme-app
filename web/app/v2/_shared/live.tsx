"use client";

import { motion, useMotionValue, useReducedMotion, useSpring } from "motion/react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState, type CSSProperties, type PointerEvent, type ReactNode } from "react";
import { Icon } from "./brand";
import { Tile } from "./fragments";

const cx = (...parts: Array<string | false | null | undefined>) => parts.filter(Boolean).join(" ");

/* ── In-view tracking ─────────────────────────────────────────────────── */
export function useInView<T extends Element>({
  once = true,
  threshold = 0.18,
  margin = "0px 0px -6% 0px",
}: { once?: boolean; threshold?: number; margin?: string } = {}) {
  const ref = useRef<T>(null);
  const [inView, setInView] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (typeof IntersectionObserver === "undefined") {
      setInView(true);
      return;
    }
    const io = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setInView(true);
          if (once) io.disconnect();
        } else if (!once) {
          setInView(false);
        }
      },
      { threshold, rootMargin: margin },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [once, threshold, margin]);
  return [ref, inView] as const;
}

type RevealTag = "div" | "section" | "li" | "p" | "h2" | "h3" | "span" | "figure" | "header";

/** Fades and lifts its content in once, and triggers hand-drawn strokes inside it.
 *  With `plain` it only marks itself in view (for strokes) and stays put. */
export function Reveal({
  as = "div",
  className,
  delay,
  plain,
  style,
  id,
  children,
}: {
  as?: RevealTag;
  className?: string;
  delay?: number;
  plain?: boolean;
  style?: CSSProperties;
  id?: string;
  children: ReactNode;
}) {
  const [ref, inView] = useInView<HTMLElement>();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const Tag = as as any;
  return (
    <Tag
      ref={ref}
      id={id}
      className={cx(!plain && "g-reveal", className)}
      data-inview={inView}
      style={{ ...(delay ? ({ "--d": `${delay}ms` } as CSSProperties) : null), ...style }}
    >
      {children}
    </Tag>
  );
}

/* ── Pointer-reactive stage: exposes --px / --py (−1…1) to its children ── */
export function Tilt({
  className,
  style,
  children,
}: {
  className?: string;
  style?: CSSProperties;
  children: ReactNode;
}) {
  const reduce = useReducedMotion();
  const px = useMotionValue(0);
  const py = useMotionValue(0);
  // critically damped: the stage follows the pointer without overshoot
  const sx = useSpring(px, { stiffness: 140, damping: 24, mass: 0.7 });
  const sy = useSpring(py, { stiffness: 140, damping: 24, mass: 0.7 });

  const onMove = (e: PointerEvent<HTMLDivElement>) => {
    if (reduce || e.pointerType === "touch") return;
    const r = e.currentTarget.getBoundingClientRect();
    px.set(((e.clientX - r.left) / r.width) * 2 - 1);
    py.set(((e.clientY - r.top) / r.height) * 2 - 1);
  };
  const onLeave = () => {
    px.set(0);
    py.set(0);
  };

  return (
    <motion.div
      className={className}
      style={{ ...style, "--px": sx, "--py": sy } as never}
      onPointerMove={onMove}
      onPointerLeave={onLeave}
    >
      {children}
    </motion.div>
  );
}

/* ── Price-drop card: the number ticks down, the line draws, the verdict pops ── */
export function PriceCard({ className, style }: { className?: string; style?: CSSProperties }) {
  const [ref, inView] = useInView<HTMLDivElement>({ once: false, threshold: 0.45, margin: "0px" });
  const reduce = useReducedMotion();
  const [price, setPrice] = useState(99);
  const [run, setRun] = useState(0);

  useEffect(() => {
    if (!inView || reduce) return;
    let raf = 0;
    let timer: ReturnType<typeof setTimeout>;
    const play = () => {
      setRun((r) => r + 1);
      const t0 = performance.now();
      const tick = (t: number) => {
        const k = Math.min(1, (t - t0) / 1100);
        const eased = 1 - Math.pow(1 - k, 3);
        setPrice(Math.round(129 - 30 * eased));
        if (k < 1) raf = requestAnimationFrame(tick);
      };
      raf = requestAnimationFrame(tick);
      timer = setTimeout(play, 7200);
    };
    timer = setTimeout(play, 450);
    return () => {
      cancelAnimationFrame(raf);
      clearTimeout(timer);
      setPrice(99);
    };
  }, [inView, reduce]);

  return (
    <div ref={ref} className={cx("g-price g-glass", className)} style={style} data-run={run > 0}>
      <div className="g-price__head">
        <Tile image="/v2/products/shoes.webp" />
        <span>
          <span className="g-price__name">Nike Free running shoes</span>
          <span className="g-price__store">Tracked for 6 weeks</span>
        </span>
      </div>
      <div className="g-price__nums" key={`n${run}`}>
        <span className="g-price__now" aria-label="Now $99">
          ${price}
        </span>
        <span className="g-price__was">$129</span>
        <span className="g-price__verdict">Lowest price yet</span>
      </div>
      <svg className="g-price__chart" viewBox="0 0 280 96" key={`c${run}`} role="img" aria-label="Price history falling from $129 to $99 over six weeks">
        <defs>
          <linearGradient id="g-price-fill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#ABA4FF" stopOpacity="0.3" />
            <stop offset="1" stopColor="#ABA4FF" stopOpacity="0" />
          </linearGradient>
        </defs>
        {/* a stepped line, as the app draws price history: a price holds until it changes */}
        <path className="g-price__area" d="M6 20.100H97.500V26.900H143.300V20.100H189V37H221.700V43.800H254.400V53.900H274V70.800V96H6z" />
        <line className="g-price__target" x1="6" x2="274" y1="77.600" y2="77.600" />
        <path className="g-price__line" pathLength={1} d="M6 20.100H97.500V26.900H143.300V20.100H189V37H221.700V43.800H254.400V53.900H274V70.800" />
        <circle className="g-price__halo" cx="274" cy="70.800" r="4.500" />
        <circle className="g-price__dot" cx="274" cy="70.800" r="4.500" />
      </svg>
      <div className="g-price__foot">
        <span>
          Target <b>$95</b>
        </span>
        <span>Alert is on</span>
      </div>
    </div>
  );
}

/* ── Claim card: what a friend does on the shared web page ────────────── */
const CONFETTI = ["#E8586D", "#D4A017", "#2EAA5F", "#3B8DD4", "#8B5CF6", "#FF8A5C"];

export function ClaimCard({ className, style }: { className?: string; style?: CSSProperties }) {
  const [on, setOn] = useState(false);
  const host = useRef<HTMLDivElement>(null);
  const reduce = useReducedMotion();

  const burst = (btn: HTMLElement) => {
    const el = host.current;
    if (!el) return;
    const hb = el.getBoundingClientRect();
    const b = btn.getBoundingClientRect();
    const cx0 = b.left - hb.left + b.width / 2;
    const cy0 = b.top - hb.top + b.height / 2;
    for (let i = 0; i < 28; i++) {
      const piece = document.createElement("i");
      piece.className = "g-confetto";
      piece.style.left = `${cx0}px`;
      piece.style.top = `${cy0}px`;
      piece.style.background = CONFETTI[i % CONFETTI.length];
      el.appendChild(piece);
      piece.getBoundingClientRect();
      const angle = Math.random() * Math.PI * 2;
      const dist = 60 + Math.random() * 110;
      piece.style.transform = `translate(${Math.cos(angle) * dist}px, ${Math.sin(angle) * dist - 40}px) rotate(${Math.random() * 540}deg)`;
      piece.style.opacity = "0";
      setTimeout(() => piece.remove(), 1000);
    }
  };

  return (
    <div ref={host} className={cx("g-claim g-glass", className)} style={style}>
      <div className="g-claim__item">
        <Tile image="/v2/products/chemex.webp" size={52} />
        <span>
          <span className="g-claim__name">Chemex coffee maker</span>
          <span className="g-claim__meta">$64 · Birthday</span>
        </span>
      </div>
      <button
        type="button"
        className="g-claim__btn"
        aria-pressed={on}
        onClick={(e) => {
          const next = !on;
          setOn(next);
          if (next && !reduce) burst(e.currentTarget);
        }}
      >
        <Icon name="check" style={{ strokeWidth: 2.8 }} />
        {on ? "Reserved" : "I’ll get this"}
      </button>
      <p className="g-claim__note" aria-live="polite">
        {on ? "Everyone else now sees it is taken. Tap again to undo." : "Go on, tap it. This is what a friend sees."}
      </p>
    </div>
  );
}

/* ── Auto-fill card: paste a link, the fields fill themselves ─────────── */
export function AutoFill({ className, style }: { className?: string; style?: CSSProperties }) {
  const [ref, inView] = useInView<HTMLDivElement>({ once: false, threshold: 0.4, margin: "0px" });
  return (
    <div ref={ref} className={cx("g-fill g-glass", className)} style={style} data-loop={inView}>
      <div className="g-fill__url">
        <Icon name="link" />
        <span className="g-fill__typed">shop.example/nike-free-running-shoes</span>
      </div>
      <div className="g-fill__body">
        <span className="g-fill__in">
          <Tile image="/v2/products/shoes.webp" size={58} />
        </span>
        <div className="g-fill__rows">
          <div className="g-fill__row">
            <span>Name</span>
            <span className="g-fill__in g-fill__in--2">Nike Free running shoes</span>
          </div>
          <div className="g-fill__row">
            <span>Price</span>
            <span className="g-fill__in g-fill__in--3">$129</span>
          </div>
          <div className="g-fill__row">
            <span>List</span>
            <span className="g-fill__in g-fill__in--4">Birthday</span>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ── Scaffolding for comparing the options; removed once one is chosen ── */
export function OptionSwitcher() {
  const path = usePathname();
  const options = [
    ["a", "A"],
    ["b", "B"],
    ["c", "C"],
  ];
  return (
    <nav className="g-switch" aria-label="Design options">
      <span>Option</span>
      {options.map(([slug, label]) => (
        <Link key={slug} href={`/v2/${slug}`} aria-current={path === `/v2/${slug}` ? "page" : undefined}>
          {label}
        </Link>
      ))}
    </nav>
  );
}
