import Link from "next/link";
import { AppStoreButton, Wordmark } from "./brand";
import { FOOTER_LINKS, NAV } from "./data";

/** Faint stars behind the page. Sits inside the page's positioned root. */
export function Sky() {
  return <div className="g-sky" aria-hidden="true" />;
}

/** The floating glass pill at the top of every page. */
export function SiteNav() {
  return (
    <>
      <a className="g-skip" href="#main">
        Skip to content
      </a>
      <header className="g-nav">
        <nav className="g-nav__pill g-glass" aria-label="Main">
          <Link href="/" className="g-nav__logo" aria-label="Gimme, home">
            <Wordmark />
          </Link>
          {NAV.map((item) => (
            <Link key={item.href} href={item.href} className="g-nav__link">
              {item.label}
            </Link>
          ))}
          <AppStoreButton className="g-btn g-btn--primary g-btn--sm" label="Download" />
        </nav>
      </header>
    </>
  );
}

export function SiteFooter() {
  return (
    <footer className="g-foot">
      <div className="g-wrap g-foot__in">
        <Link href="/" className="g-foot__logo" aria-label="Gimme, home">
          <Wordmark />
        </Link>
        <nav aria-label="Footer">
          {FOOTER_LINKS.map((l) => (
            <Link key={l.href} href={l.href}>
              {l.label}
            </Link>
          ))}
        </nav>
        <p>Made by Dmytro Yaremchuk · 2026</p>
      </div>
    </footer>
  );
}
