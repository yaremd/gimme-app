import type { Metadata } from "next";
import Link from "next/link";
import { HandRing, Icon, Sparkle } from "./_site/brand";
import { Sky, SiteFooter, SiteNav } from "./_site/chrome";
import { Reveal } from "./_site/reveal";

export const metadata: Metadata = {
  title: "Page not found — Gimme",
  robots: { index: false, follow: true },
};

export default function NotFound() {
  return (
    <>
      <Sky />
      <SiteNav />
      <main id="main" className="g-solo">
        <div className="g-solo__glow" aria-hidden="true" />
        <Reveal className="g-solo__in">
          <Sparkle className="g-solo__spark" />
          <p className="g-eyebrow">Error 404</p>
          <h1 className="g-solo__title">
            This wish got{" "}
            <span className="g-ringed">
              lost.
              <HandRing />
            </span>
          </h1>
          <p className="g-solo__sub">The page you&apos;re looking for doesn&apos;t exist or has been moved.</p>
          <div className="g-solo__acts">
            <Link href="/" className="g-btn g-btn--primary">
              <Icon name="arrow-left" style={{ width: 17, height: 17 }} />
              <span>Back to Gimme</span>
            </Link>
            <Link href="/support" className="g-btn g-btn--ghost">
              Support
            </Link>
          </div>
        </Reveal>
      </main>
      <SiteFooter />
    </>
  );
}
