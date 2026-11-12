import type { Metadata } from "next";
import { AppStoreButton, HandRing, HandUnderline, Icon, Sparkle, Wordmark } from "../_shared/brand";
import { FOOTER_LINKS, NAV, PLANS } from "../_shared/data";
import { QRCard, SiriPhrase, Spotlight, WidgetMedium, WidgetSmall } from "../_shared/fragments";
import { Reveal } from "../_shared/live";
import "./a.css";
import { Hero, Statement, Story } from "./parts";

export const metadata: Metadata = { title: "Option A · Night sky" };

/* Option A, "Night sky": fully dark and cinematic. One centred phone with wishes
   orbiting it, a statement that lights up on scroll, and a phone that stays put
   while the four-step story moves past it. */
export default function OptionA() {
  return (
    <div className="opt-a">
      <div className="a-sky" aria-hidden="true" />

      <header className="a-nav">
        <nav className="a-nav__pill g-glass" aria-label="Main">
          <a href="#top" className="a-nav__logo" aria-label="Gimme, back to top">
            <Wordmark />
          </a>
          {NAV.map((item) => (
            <a key={item.href} href={item.href} className="a-nav__link">
              {item.label}
            </a>
          ))}
          <AppStoreButton className="g-btn g-btn--primary g-btn--sm" label="Download" />
        </nav>
      </header>

      <main id="top">
        <Hero />
        <Statement />
        <Story />

        <section id="iphone" className="a-native">
          <div className="g-wrap">
            <Reveal as="header" className="a-head">
              <p className="g-eyebrow">Only on iPhone</p>
              <h2 className="a-h2">
                At home on your{" "}
                <span className="a-ring a-ring--violet">
                  iPhone.
                  <HandRing />
                </span>
              </h2>
              <p className="a-lede">
                Gimme is built for iPhone and nothing else, so it shows up where you already look.
              </p>
            </Reveal>

            <div className="a-bento">
              <Reveal className="a-tile a-tile--widgets">
                <div className="a-tile__art a-widgets">
                  <WidgetMedium />
                  <WidgetSmall />
                </div>
                <h3>Widgets</h3>
                <p>Your list on the Home Screen, one tap from adding the next wish.</p>
              </Reveal>

              <Reveal className="a-tile a-tile--lock" delay={80}>
                <div className="a-tile__art">
                  <div className="a-lock" role="img" aria-label="Lock Screen at 9:41 with Gimme widgets showing five wishes remaining">
                    <span className="a-lock__inline">
                      <Icon name="gift" />5 wishes remaining
                    </span>
                    <span className="a-lock__time">9:41</span>
                    <span className="a-lock__gauge">
                      <svg viewBox="0 0 48 48" aria-hidden="true">
                        <path d="M10.6 38.4a19 19 0 1 1 26.8 0" pathLength={1} />
                        <path d="M10.6 38.4a19 19 0 1 1 26.8 0" pathLength={1} className="a-lock__fill" />
                      </svg>
                      <b>5</b>
                    </span>
                  </div>
                </div>
                <h3>Lock Screen</h3>
                <p>A glance tells you what is left.</p>
              </Reveal>

              <Reveal className="a-tile a-tile--siri">
                <div className="a-tile__art">
                  <SiriPhrase>“Add wish in Gimme”</SiriPhrase>
                </div>
                <h3>Siri</h3>
                <p>Five shortcuts for adding a wish or hearing your total, hands free.</p>
              </Reveal>

              <Reveal className="a-tile a-tile--spot" delay={80}>
                <div className="a-tile__art">
                  <Spotlight />
                </div>
                <h3>Spotlight</h3>
                <p>Every wish is searchable from the Home Screen.</p>
              </Reveal>

              <Reveal className="a-tile a-tile--ext" delay={160}>
                <div className="a-tile__art">
                  <div className="a-sheet" role="img" aria-label="Share sheet with Gimme as a destination">
                    <span className="a-sheet__app" />
                    <span className="a-sheet__app" />
                    <span className="a-sheet__app a-sheet__app--gimme">
                      <img src="/v2/icon-dark.png" alt="" width={56} height={56} loading="lazy" />
                      <HandRing />
                      <small>Gimme</small>
                    </span>
                    <span className="a-sheet__app" />
                  </div>
                </div>
                <h3>Share Extension</h3>
                <p>Save from Safari, or from any app with a Share button.</p>
              </Reveal>
            </div>
          </div>
        </section>

        <section id="pricing" className="a-pricing">
          <div className="g-wrap">
            <Reveal as="header" className="a-head a-head--center">
              <p className="g-eyebrow">Pricing</p>
              <h2 className="a-h2">
                One price.{" "}
                <span className="a-under">
                  Yours forever.
                  <HandUnderline />
                </span>
              </h2>
              <p className="a-lede">No subscription. Pay once, and every Pro feature we add later is yours.</p>
            </Reveal>

            <div className="a-plans">
              <Reveal className="a-plan">
                <p className="a-plan__name">{PLANS.free.name}</p>
                <p className="a-plan__price">{PLANS.free.price}</p>
                <p className="a-plan__note">{PLANS.free.note}</p>
                <ul>
                  {PLANS.free.features.map((f) => (
                    <li key={f}>
                      <Icon name="check" />
                      {f}
                    </li>
                  ))}
                </ul>
              </Reveal>
              <Reveal className="a-plan a-plan--pro" delay={90}>
                <Sparkle className="a-plan__spark" />
                <p className="a-plan__name">{PLANS.pro.name}</p>
                <p className="a-plan__price">
                  {PLANS.pro.price} <span>once</span>
                </p>
                <p className="a-plan__note">{PLANS.pro.note}</p>
                <ul>
                  {PLANS.pro.features.map((f) => (
                    <li key={f}>
                      <Icon name="check" />
                      {f}
                    </li>
                  ))}
                </ul>
              </Reveal>
            </div>
          </div>
        </section>

        <section className="a-final">
          <div className="a-final__glow" aria-hidden="true" />
          <Reveal className="g-wrap a-final__in">
            <Sparkle className="a-final__spark" />
            <h2 className="a-final__title">
              Go on.
              <br />
              Make a wish.
            </h2>
            <div className="a-cta">
              <AppStoreButton />
              <QRCard className="a-cta__qr" />
            </div>
            <p className="a-cta__note">Free on the App Store. iPhone only.</p>
          </Reveal>
        </section>
      </main>

      <footer className="a-foot">
        <div className="g-wrap a-foot__in">
          <Wordmark className="a-foot__logo" />
          <nav aria-label="Footer">
            {FOOTER_LINKS.map((l) => (
              <a key={l.href} href={l.href}>
                {l.label}
              </a>
            ))}
          </nav>
          <p>Made by Dmytro Yaremchuk · 2026</p>
        </div>
      </footer>
    </div>
  );
}
