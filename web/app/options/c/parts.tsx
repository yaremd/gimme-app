"use client";

import { useEffect, useRef, type ReactNode } from "react";

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

export { CountUp } from "../../_site/live";
