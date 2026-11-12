import type { Metadata } from "next";
import { AppStoreButton, HandArrow, HandRing, HandUnderline, Icon, Sparkle, Wordmark } from "../_shared/brand";
import { FOOTER_LINKS, PLANS, SCREENS } from "../_shared/data";
import { Phone, QRCard, SiriPhrase, Spotlight, WidgetMedium, WidgetSmall } from "../_shared/fragments";
import { AutoFill, ClaimCard, PriceCard, Reveal } from "../_shared/live";
import "./b.css";
import { Chat, HeroStage, Nav } from "./parts";

export const metadata: Metadata = { title: "Option B · Dusk to night" };

/* Option B, "Dusk to night": the page opens in the app's cream light mode and
   falls into night as you scroll. Day is for saving, dusk is for sharing, and
   night is when friends claim gifts and prices drop. Shows both app themes. */
export default function OptionB() {
  return (
    <div className="opt-b">
      <Nav />

      <main id="top">
        {/* ── Day ── */}
        <div className="b-day">
          <section className="b-hero">
            <div className="g-wrap b-hero__grid">
              <div className="b-hero__copy">
                <p className="b-kicker">
                  <img src="/v2/icon-light.png" alt="" width={28} height={28} />
                  Wishlist for iPhone
                </p>
                <h1 className="b-h1">
                  Drop a{" "}
                  <Reveal as="span" plain className="b-under">
                    hint.
                    <HandUnderline />
                  </Reveal>
                  <br />
                  Get the gift.
                  <Sparkle className="b-h1__spark" />
                </h1>
                <p className="b-sub">
                  Gimme keeps everything you want in one list. Share it, and the people who love you quietly claim
                  what they are getting.
                </p>
                <div className="b-cta">
                  <AppStoreButton className="g-btn g-btn--ink" />
                  <QRCard className="b-cta__qr g-glass--day" />
                </div>
                <p className="b-cta__note">Free. Pro is a one-time $4.99.</p>
              </div>
              <HeroStage />
            </div>
          </section>

          <section id="how" className="b-save">
            <div className="g-wrap b-split">
              <Reveal className="b-split__copy">
                <p className="g-eyebrow">By day · Save</p>
                <h2 className="b-h2">Save it the second you see it.</h2>
                <p className="b-lede">
                  Share any product page to Gimme, or paste the link. The name, photo and price fill themselves in.
                </p>
                <div className="b-save__demo">
                  <AutoFill className="g-glass--day" />
                  <HandArrow className="b-save__arrow" />
                </div>
              </Reveal>
              <Reveal className="b-split__art" delay={120}>
                <Phone screens={[SCREENS.listLight]} className="b-phone b-phone--right" />
              </Reveal>
            </div>
          </section>
        </div>

        {/* ── Dusk ── */}
        <section className="b-dusk">
          <span data-b-night className="b-dusk__mark" aria-hidden="true" />
          <div className="g-wrap b-dusk__in">
            <Reveal className="b-dusk__top">
              <p className="g-eyebrow b-dusk__eyebrow">At dusk · Share</p>
              <h2 className="b-h2 b-dusk__title">Then send one link.</h2>
            </Reveal>
            <Chat />
            <Reveal className="b-dusk__bottom">
              <Sparkle className="b-dusk__star" />
              <p className="b-dusk__line">
                Friends open your list in any browser.
                <br />
                No app to install. No account to make.
              </p>
            </Reveal>
          </div>
        </section>

        {/* ── Night ── */}
        <div className="b-night" data-b-night>
          <div className="b-night__stars" aria-hidden="true" />

          <section className="b-claim">
            <div className="g-wrap b-split b-split--flip">
              <Reveal className="b-split__art">
                <Phone screens={[SCREENS.listDark]} className="b-phone b-phone--left" />
              </Reveal>
              <Reveal className="b-split__copy" delay={120}>
                <p className="g-eyebrow">By night · Claim</p>
                <h2 className="b-h2">
                  They claim it.
                  <br />
                  Nobody doubles up.
                </h2>
                <p className="b-lede">
                  A friend taps “I’ll get this” and everyone else sees it is taken. Turn on anonymous reservations and
                  even you won’t know who.
                </p>
                <ClaimCard className="b-demo" />
              </Reveal>
            </div>
          </section>

          <section id="track" className="b-track">
            <div className="g-wrap b-split">
              <Reveal className="b-split__copy">
                <p className="g-eyebrow">By night · Track</p>
                <h2 className="b-h2">
                  Prices drop while you{" "}
                  <span className="b-ring">
                    sleep.
                    <HandRing />
                  </span>
                </h2>
                <p className="b-lede">
                  Gimme watches the price of what you saved and tells you the moment it falls. Set a target and wait
                  for it.
                </p>
                <div className="b-note g-glass" role="img" aria-label="Notification from Gimme: Nike Free running shoes dropped to $99, the lowest price yet">
                  <img src="/v2/icon-dark.png" alt="" width={38} height={38} loading="lazy" />
                  <span>
                    <b>
                      Price drop <small>now</small>
                    </b>
                    Nike Free running shoes are down to $99. Lowest price yet.
                  </span>
                </div>
              </Reveal>
              <Reveal className="b-split__art b-track__art" delay={120}>
                <Phone screens={[SCREENS.itemDark]} className="b-phone b-phone--right" />
                <PriceCard className="b-track__card" />
              </Reveal>
            </div>
          </section>

          <section id="iphone" className="b-native">
            <div className="g-wrap">
              <Reveal as="header" className="b-head">
                <p className="g-eyebrow">Only on iPhone</p>
                <h2 className="b-h2">It lives where you look.</h2>
              </Reveal>
              <div className="b-quad">
                <Reveal className="b-cell b-cell--widgets">
                  <div className="b-cell__art b-widgets">
                    <WidgetMedium />
                    <WidgetSmall />
                  </div>
                  <h3>Widgets</h3>
                  <p>Your list on the Home Screen and the Lock Screen.</p>
                </Reveal>
                <Reveal className="b-cell" delay={80}>
                  <div className="b-cell__art">
                    <SiriPhrase>“Add wish in Gimme”</SiriPhrase>
                  </div>
                  <h3>Siri</h3>
                  <p>Add a wish or hear your total, hands free.</p>
                </Reveal>
                <Reveal className="b-cell" delay={160}>
                  <div className="b-cell__art">
                    <Spotlight />
                  </div>
                  <h3>Spotlight</h3>
                  <p>Every wish is searchable from the Home Screen.</p>
                </Reveal>
              </div>
            </div>
          </section>

          <section id="pricing" className="b-pricing">
            <div className="g-wrap">
              <Reveal as="header" className="b-head b-head--center">
                <p className="g-eyebrow">Pricing</p>
                <h2 className="b-h2">
                  One price.{" "}
                  <span className="b-under b-under--coral">
                    Yours forever.
                    <HandUnderline />
                  </span>
                </h2>
              </Reveal>
              <div className="b-plans">
                <Reveal className="b-plan">
                  <p className="b-plan__name">{PLANS.free.name}</p>
                  <p className="b-plan__price">{PLANS.free.price}</p>
                  <p className="b-plan__note">{PLANS.free.note}</p>
                  <ul>
                    {PLANS.free.features.map((f) => (
                      <li key={f}>
                        <Icon name="check" />
                        {f}
                      </li>
                    ))}
                  </ul>
                </Reveal>
                <Reveal className="b-plan b-plan--pro" delay={90}>
                  <p className="b-plan__name">{PLANS.pro.name}</p>
                  <p className="b-plan__price">
                    {PLANS.pro.price} <span>once</span>
                  </p>
                  <p className="b-plan__note">{PLANS.pro.note}</p>
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

          <section className="b-final">
            <Reveal className="g-wrap b-final__in">
              <Sparkle className="b-final__star" />
              <h2 className="b-final__title">Make a wish.</h2>
              <p className="b-lede">The first star is out. The list takes a minute to start.</p>
              <div className="b-cta b-cta--center">
                <AppStoreButton />
                <QRCard className="b-cta__qr" />
              </div>
              <p className="b-cta__note">Free on the App Store. iPhone only.</p>
            </Reveal>
          </section>

          <footer className="b-foot">
            <div className="g-wrap b-foot__in">
              <Wordmark className="b-foot__logo" />
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
      </main>
    </div>
  );
}
