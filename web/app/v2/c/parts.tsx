"use client";

import { useReducedMotion } from "motion/react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { useInView } from "../_shared/live";

/* The grid tracks the pointer and hands each tile its own --mx / --my, so a
   single soft highlight appears to slide across the glass from tile to tile. */
export function Bento({ children }: { children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const grid = ref.current;
    if (!grid) return;
    if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) return;

    let raf = 0;
    let point: { x: number; y: number } | null = null;

    const apply = () => {
      raf = 0;
      if (!point) return;
      grid.querySelectorAll<HTMLElement>(".c-tile").forEach((tile) => {
        const r = tile.getBoundingClientRect();
        tile.style.setProperty("--mx", `${point!.x - r.left}px`);
        tile.style.setProperty("--my", `${point!.y - r.top}px`);
      });
    };
    const onMove = (e: PointerEvent) => {
      point = { x: e.clientX, y: e.clientY };
      if (!raf) raf = requestAnimationFrame(apply);
    };

    grid.addEventListener("pointermove", onMove, { passive: true });
    return () => {
      grid.removeEventListener("pointermove", onMove);
      cancelAnimationFrame(raf);
    };
  }, []);

  return (
    <div ref={ref} className="c-bento">
      {children}
    </div>
  );
}

/** Counts up to a number the first time it scrolls into view. */
export function CountUp({ to, prefix = "" }: { to: number; prefix?: string }) {
  const [ref, inView] = useInView<HTMLSpanElement>({ once: true, threshold: 0.6, margin: "0px" });
  const reduce = useReducedMotion();
  const [value, setValue] = useState(to);

  useEffect(() => {
    if (!inView || reduce) return;
    let raf = 0;
    const t0 = performance.now();
    const tick = (t: number) => {
      const k = Math.min(1, (t - t0) / 1300);
      const eased = 1 - Math.pow(1 - k, 4);
      setValue(Math.round(to * eased));
      if (k < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [inView, reduce, to]);

  return (
    <span ref={ref} aria-label={`${prefix}${to.toLocaleString("en-US")}`}>
      {prefix}
      {value.toLocaleString("en-US")}
    </span>
  );
}
