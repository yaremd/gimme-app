import type { Metadata } from "next";
import type { CSSProperties } from "react";
import Link from "next/link";
import { AppStoreButton, HandRing, HandUnderline, Icon, Sparkle } from "./_site/brand";
import { Sky, SiteFooter, SiteNav } from "./_site/chrome";
import { FAQS, PLANS, SCREENS } from "./_site/data";
import { Phone, QRCard, SiriPhrase, Spotlight, WidgetMedium, WidgetSmall } from "./_site/fragments";
import { CountUp, Reveal } from "./_site/live";
import { Hero, Statement, Story } from "./_home/parts";
import "./home.css";

/* Title, description and the social card come from the root layout. */
export const metadata: Metadata = { alternates: { canonical: "/" } };

const faqJsonLd = {
  "@context": "https://schema.org",
  "@type": "FAQPage",
  mainEntity: FAQS.map((f) => ({
    "@type": "Question",
    name: f.q,
    acceptedAnswer: { "@type": "Answer", text: f.a },
  })),
};

/* "Night sky": fully dark and cinematic. One centred phone with wishes orbiting
   it, a statement that lights up on scroll, and a phone that stays put while the
   four-step story moves past it. */
export default function Home() {
  return (
    <>
      <Sky />
      <SiteNav />

      <main id="main">
        <Hero />
        <Statement />
        <Story />

        <section className="a-stats">
          <div className="g-wrap a-stats__grid">
            <Reveal as="header" className="a-head">
              <p className="g-eyebrow a-stats__eyebrow">
                <Sparkle still />
                Gimme Pro
              </p>
              <h2 className="a-h2">
                See what it all{" "}
                <span className="a-under">
                  adds up to.
                  <HandUnderline />
                </span>
              </h2>
              <p className="a-lede">
                Every list in one place: what is still wanted, what is already bought, and which gifts friends have
                reserved.
              </p>
              <dl className="a-nums">
                <div>
                  <dt>Across 5 lists</dt>
                  <dd>
                    <CountUp to={2154} prefix="$" />
                  </dd>
                </div>
                <div>
                  <dt>Wishes saved</dt>
                  <dd>
                    <CountUp to={21} />
                  </dd>
                </div>
                <div>
                  <dt>Fulfilled</dt>
                  <dd>
                    <CountUp to={19} suffix="%" />
                  </dd>
                </div>
              </dl>
            </Reveal>

            <Reveal className="a-stats__stage" delay={90}>
              <div className="a-stats__halo" aria-hidden="true" />
              <div className="a-stats__crop">
                <Phone screens={[SCREENS.statsDark]} className="a-stats__phone" />
              </div>
              <div className="a-stats__chips">
                <span className="g-chip g-glass a-stats__chip a-stats__chip--1">
                  <span className="g-chip__ic" style={{ "--c": "#FF8A5C" } as CSSProperties}>
                    <Icon name="gift" />
                  </span>
                  <span>
                    2 reserved by friends
                    <small>Anna, Max</small>
                  </span>
                </span>
                <span className="g-chip g-glass a-stats__chip a-stats__chip--2">
                  <span className="g-chip__ic">
                    <Icon name="tag" />
                  </span>
                  <span>
                    $110.48 average
                    <small>from $24 to $349</small>
                  </span>
                </span>
              </div>
            </Reveal>
          </div>
        </section>

        <section id="iphone" className="a-native">
          <div className="g-wrap">
            <Reveal as="header" className="a-head">
              <p className="g-eyebrow">Made for iPhone</p>
              <h2 className="a-h2">
                At home on your{" "}
                <span className="a-ring a-ring--violet">
                  iPhone.
                  <HandRing />
                </span>
              </h2>
              <p className="a-lede">Gimme is a native iPhone app, so it shows up where you already look.</p>
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
                      <img src="/img/icon-dark.png" alt="" width={56} height={56} loading="lazy" />
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

        <section className="a-trust">
          <div className="g-wrap">
            <Reveal as="header" className="a-head a-head--center">
              <p className="g-eyebrow">Privacy</p>
              <h2 className="a-h2 a-h2--sm">Yours until you share it.</h2>
            </Reveal>
            <ul className="a-facts">
              <Reveal as="li" className="a-fact">
                <span className="a-fact__ic">
                  <Icon name="wifi-off" />
                </span>
                <h3>Works offline</h3>
                <p>No account needed. Your lists stay on your iPhone until you choose to sync.</p>
              </Reveal>
              <Reveal as="li" className="a-fact" delay={80}>
                <span className="a-fact__ic">
                  <Icon name="eye-off" />
                </span>
                <h3>No ads, no tracking</h3>
                <p>The app carries no advertising and no analytics SDKs.</p>
              </Reveal>
              <Reveal as="li" className="a-fact" delay={160}>
                <span className="a-fact__ic">
                  <Icon name="lock" />
                </span>
                <h3>Private by default</h3>
                <p>Nobody sees a list until you share it, and you can stop sharing whenever you like.</p>
              </Reveal>
            </ul>
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

        <section id="faq" className="a-faq">
          <div className="g-wrap a-faq__in">
            <Reveal as="header" className="a-head">
              <p className="g-eyebrow">Questions</p>
              <h2 className="a-h2 a-h2--sm">Good to know.</h2>
              <p className="a-lede">
                Anything else? <Link href="/support">Support</Link> has the how-tos, or{" "}
                <Link href="/contact">write to us</Link>.
              </p>
            </Reveal>
            <Reveal className="g-faq" delay={90}>
              {FAQS.map((f) => (
                <details key={f.q}>
                  <summary>
                    {f.q}
                    <span className="g-faq__ic" aria-hidden="true">
                      <Icon name="plus" />
                    </span>
                  </summary>
                  <p className="g-faq__a">{f.a}</p>
                </details>
              ))}
            </Reveal>
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
            <p className="a-cta__note">Free on the App Store, for iPhone.</p>
          </Reveal>
        </section>
      </main>

      <SiteFooter />

      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }} />
    </>
  );
}
