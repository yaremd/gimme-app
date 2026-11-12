"use client";

import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";

/* Scroll reveals, on their own so that pages which only need these (the text pages,
   the shared wishlist) don't also download the animation library that live.tsx uses. */

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
