import Link from "next/link";
import { Sparkle, Wordmark } from "../_site/brand";

const OPTIONS = [
  {
    href: "/",
    name: "A · Night sky (chosen, now the live home page)",
    text: "Fully dark and cinematic. One centred phone with wishes orbiting it, a statement that lights up as you scroll, and a phone that stays put while the story moves.",
  },
  {
    href: "/options/b",
    name: "B · Dusk to night",
    text: "Opens in the app’s cream light mode and falls into night as you scroll. Shows both app themes. The warmest of the three.",
  },
  {
    href: "/options/c",
    name: "C · Glass bento",
    text: "Dark and compact. A grid of live interface fragments you can poke. The quickest to scan.",
  },
  {
    href: "/options/share",
    name: "Shared wishlist page · sample data",
    text: "What a friend sees when they open a share link. Add ?anon=1 for a list with anonymous reservations, ?state=done, ?state=empty or ?state=missing for the other states.",
  },
];

export default function OptionsIndex() {
  return (
    <main className="g-wrap" style={{ paddingBlock: "96px 160px", display: "grid", gap: 40, maxWidth: 820 }}>
      <Wordmark style={{ height: 26, width: 79, color: "var(--lavender)" }} />
      <h1 style={{ font: "800 clamp(40px, 7vw, 68px)/1 var(--font-display)", letterSpacing: "-0.025em" }}>
        Saved designs and previews
        <Sparkle style={{ width: "0.4em", height: "0.4em", marginLeft: "0.12em", verticalAlign: "0.7em" }} />
      </h1>
      <ul style={{ display: "grid" }}>
        {OPTIONS.map((o) => (
          <li key={o.href} style={{ borderTop: "1px solid var(--hair)" }}>
            <Link href={o.href} style={{ display: "grid", gap: 6, padding: "22px 0", textDecoration: "none" }}>
              <span style={{ font: "700 24px/1.2 var(--font-display)" }}>{o.name}</span>
              <span style={{ color: "var(--muted)", maxWidth: "60ch" }}>{o.text}</span>
            </Link>
          </li>
        ))}
      </ul>
    </main>
  );
}
