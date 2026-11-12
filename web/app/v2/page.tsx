import Link from "next/link";
import { Sparkle, Wordmark } from "./_shared/brand";

const OPTIONS = [
  {
    slug: "a",
    name: "A · Night sky",
    text: "Fully dark and cinematic. One centred phone with wishes orbiting it, a statement that lights up as you scroll, and a phone that stays put while the story moves.",
  },
  {
    slug: "b",
    name: "B · Dusk to night",
    text: "Opens in the app’s cream light mode and falls into night as you scroll. Shows both app themes. The warmest of the three.",
  },
  {
    slug: "c",
    name: "C · Glass bento",
    text: "Dark and compact. A grid of live interface fragments you can poke. The quickest to scan.",
  },
];

export default function OptionsIndex() {
  return (
    <main className="g-wrap" style={{ paddingBlock: "96px 160px", display: "grid", gap: 40, maxWidth: 820 }}>
      <Wordmark style={{ height: 26, width: 79, color: "var(--lavender)" }} />
      <h1 style={{ font: "800 clamp(40px, 7vw, 68px)/1 var(--font-display)", letterSpacing: "-0.025em" }}>
        Three ways to reach for the sparkle
        <Sparkle style={{ width: "0.4em", height: "0.4em", marginLeft: "0.12em", verticalAlign: "0.7em" }} />
      </h1>
      <ul style={{ display: "grid" }}>
        {OPTIONS.map((o) => (
          <li key={o.slug} style={{ borderTop: "1px solid var(--hair)" }}>
            <Link href={`/v2/${o.slug}`} style={{ display: "grid", gap: 6, padding: "22px 0", textDecoration: "none" }}>
              <span style={{ font: "700 24px/1.2 var(--font-display)" }}>{o.name}</span>
              <span style={{ color: "var(--muted)", maxWidth: "60ch" }}>{o.text}</span>
            </Link>
          </li>
        ))}
      </ul>
    </main>
  );
}
