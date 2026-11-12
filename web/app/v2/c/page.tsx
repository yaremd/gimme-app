import type { Metadata } from "next";
import type { CSSProperties } from "react";
import { AppStoreButton, Icon, Sparkle, Wordmark } from "../_shared/brand";
import { FOOTER_LINKS, LISTS, NAV, PLANS, SCREENS } from "../_shared/data";
import { LinkPreview, Phone, QRCard, SiriPhrase, Spotlight, WidgetMedium } from "../_shared/fragments";
import { AutoFill, ClaimCard, PriceCard, Reveal, Tilt } from "../_shared/live";
import "./c.css";
import { Bento, CountUp } from "./parts";

export const metadata: Metadata = { title: "Option C · Glass bento" };

const vars = (v: Record<string, string | number>) => v as CSSProperties;

/* Option C, "Glass bento": dark and compact. The whole product fits in one grid
   of smoked-glass tiles, and each tile holds a live piece of the interface.
   A wide, technical display face is used for short phrases only. */
export default function OptionC() {
  return (
    <div className="opt-c">
      <div className="c-backdrop" aria-hidden="true" />

      <div className="g-wrap c-page">
        <header className="c-nav">
          <a href="#top" className="c-nav__logo" aria-label="Gimme, back to top">
            <img src="/v2/icon-dark.png" alt="" width={34} height={34} />
            <Wordmark />
          </a>
          <nav aria-label="Main">
            {NAV.map((item) => (
              <a key={item.href} href={item.href}>
                {item.label}
              </a>
            ))}
          </nav>
          <AppStoreButton className="g-btn g-btn--primary g-btn--sm" label="Download" />
        </header>

        <main id="top">
          <Bento>
            {/* ── Hero ── */}
            <section className="c-tile c-hero">
              <p className="c-chip">
                <Sparkle still />
                Wishlist for iPhone
              </p>
              <h1 className="c-h1">
                Every wish.
                <br />
                One link.
              </h1>
              <p className="c-sub">
                Save anything, track its price, and share a list friends can claim from without installing a thing.
              </p>
              <div className="c-cta">
                <AppStoreButton />
                <QRCard className="c-cta__qr" />
              </div>
              <p className="c-note">Free. Pro is a one-time $4.99.</p>
            </section>

            {/* ── Phone ── */}
            <section className="c-tile c-phone" aria-label="The Gimme home screen">
              <p className="c-label">Home</p>
              <Tilt className="c-phone__stage">
                <div className="c-phone__glow" aria-hidden="true" />
                <Phone screens={[SCREENS.homeDark]} eager />
                <span className="g-chip c-phone__chip c-phone__chip--1">
                  <span className="g-chip__ic" style={vars({ "--c": "#30D158" })}>
                    <Icon name="trend-down" />
                  </span>
                  <span>
                    Price dropped 23%
                    <small>Nike Free, now $99</small>
                  </span>
                </span>
                <span className="g-chip c-phone__chip c-phone__chip--2">
                  <span className="g-chip__ic" style={vars({ "--c": "#FF8A5C" })}>
                    <Icon name="gift" />
                  </span>
                  <span>
                    A friend reserved a gift
                    <small>Birthday</small>
                  </span>
                </span>
              </Tilt>
            </section>

            {/* ── Save ── */}
            <section id="how" className="c-tile c-save">
              <p className="c-label">01 · Save</p>
              <div className="c-art">
                <AutoFill />
              </div>
              <h2 className="c-h2">Paste a link. The rest fills in.</h2>
              <p className="c-p">Or share from Safari and any app with a Share button.</p>
            </section>

            {/* ── Track ── */}
            <section id="track" className="c-tile c-price">
              <p className="c-label">04 · Track</p>
              <div className="c-art">
                <PriceCard />
              </div>
              <h2 className="c-h2">Never pay full price.</h2>
              <p className="c-p">Price history, a verdict, and an alert at your target.</p>
            </section>

            {/* ── Share + claim ── */}
            <section className="c-tile c-share">
              <p className="c-label">02 · Share &nbsp; 03 · Claim</p>
              <div className="c-art c-share__art">
                <LinkPreview />
                <ClaimCard />
              </div>
              <h2 className="c-h2">One link. Friends claim, nobody doubles up.</h2>
              <p className="c-p">Your list opens in any browser. No app, no account.</p>
            </section>

            {/* ── Widgets ── */}
            <section id="iphone" className="c-tile c-widgets">
              <p className="c-label">Widgets</p>
              <div className="c-art c-widgets__art">
                <WidgetMedium />
              </div>
              <h2 className="c-h2">On your Home Screen.</h2>
              <p className="c-p">Small, medium and Lock Screen.</p>
            </section>

            {/* ── Lock Screen ── */}
            <section className="c-tile c-lock">
              <p className="c-label">Lock Screen</p>
              <div className="c-art">
                <div className="c-lockscreen" role="img" aria-label="Lock Screen at 9:41 showing five wishes remaining">
                  <span className="c-lockscreen__inline">
                    <Icon name="gift" />5 wishes remaining
                  </span>
                  <span className="c-lockscreen__time">9:41</span>
                </div>
              </div>
              <h2 className="c-h2">A glance away.</h2>
            </section>

            {/* ── Siri ── */}
            <section className="c-tile c-siri">
              <p className="c-label">Siri</p>
              <div className="c-art">
                <SiriPhrase>“Add wish in Gimme”</SiriPhrase>
              </div>
              <h2 className="c-h2">Hands free.</h2>
            </section>

            {/* ── Spotlight ── */}
            <section className="c-tile c-spot">
              <p className="c-label">Spotlight</p>
              <div className="c-art">
                <Spotlight />
              </div>
              <h2 className="c-h2">Find any wish from search.</h2>
            </section>

            {/* ── Stats ── */}
            <section className="c-tile c-stats">
              <p className="c-label">Stats · Pro</p>
              <div className="c-art c-stats__art">
                <p className="c-stats__big">
                  <CountUp to={2154} prefix="$" />
                </p>
                <p className="c-stats__cap">still on your lists, across 5 of them</p>
                <ul className="c-stats__bars">
                  {LISTS.map((list) => (
                    <li key={list.name} style={vars({ "--c": list.color, "--v": Number(list.value.replace(/\D/g, "")) / 762 })}>
                      <span className="g-emoji">{list.emoji}</span>
                      <i />
                      <b>{list.value}</b>
                    </li>
                  ))}
                </ul>
              </div>
              <h2 className="c-h2">See what it adds up to.</h2>
            </section>

            {/* ── Private ── */}
            <section className="c-tile c-private">
              <p className="c-label">Private</p>
              <ul className="c-private__list">
                <li>
                  <Icon name="eye-off" />
                  No ads
                </li>
                <li>
                  <Icon name="lock" />
                  No trackers
                </li>
                <li>
                  <Icon name="wifi-off" />
                  Works offline
                </li>
              </ul>
            </section>

            {/* ── Pricing ── */}
            <section id="pricing" className="c-tile c-pricing">
              <p className="c-label">Pricing</p>
              <div className="c-plans">
                <div className="c-plan">
                  <p className="c-plan__name">{PLANS.free.name}</p>
                  <p className="c-plan__price">{PLANS.free.price}</p>
                  <ul>
                    {PLANS.free.features.map((f) => (
                      <li key={f}>
                        <Icon name="check" />
                        {f}
                      </li>
                    ))}
                  </ul>
                </div>
                <div className="c-plan c-plan--pro">
                  <p className="c-plan__name">{PLANS.pro.name}</p>
                  <p className="c-plan__price">
                    {PLANS.pro.price} <span>once</span>
                  </p>
                  <ul>
                    {PLANS.pro.features.map((f) => (
                      <li key={f}>
                        <Icon name="check" />
                        {f}
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </section>

            {/* ── Final call ── */}
            <section className="c-tile c-final">
              <Sparkle className="c-final__spark" />
              <h2 className="c-final__title">
                Get
                <br />
                Gimme.
              </h2>
              <p className="c-p">No subscription. Free on the App Store, iPhone only.</p>
              <div className="c-cta">
                <AppStoreButton />
              </div>
            </section>
          </Bento>
        </main>

        <Reveal as="div" plain className="c-foot">
          <p>Made by Dmytro Yaremchuk · 2026</p>
          <nav aria-label="Footer">
            {FOOTER_LINKS.map((l) => (
              <a key={l.href} href={l.href}>
                {l.label}
              </a>
            ))}
          </nav>
        </Reveal>
      </div>
    </div>
  );
}
