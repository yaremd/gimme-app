"use client";

import { motion, useScroll, useTransform } from "motion/react";
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { AppStoreButton, HandRing, Icon, Sparkle } from "../_site/brand";
import { SCREENS, STEPS, WISHES } from "../_site/data";
import { LinkPreview, Phone, QRCard, WishCard } from "../_site/fragments";
import { AutoFill, ClaimCard, PriceCard, Reveal, Tilt } from "../_site/live";

const vars = (v: Record<string, string | number>) => v as CSSProperties;

/* Where each wish floats around the phone: x is the card's left edge from the
   stage centre, y its top from the stage top, k its parallax depth. */
const ORBIT = [
  { x: -486, y: 96, k: 22, dur: 7.2, delay: 0 },
  { x: 206, y: 34, k: -16, dur: 8.4, delay: -2.1 },
  { x: 236, y: 268, k: 26, dur: 6.6, delay: -4.4 },
  { x: -520, y: 318, k: -12, dur: 9, delay: -1.2 },
  { x: -428, y: 520, k: 16, dur: 7.8, delay: -3.3 },
  { x: 196, y: 488, k: -20, dur: 8, delay: -5.2 },
];

/* Reduced motion is handled in home.css, not here: the server cannot know the
   visitor's setting, so branching on it in the markup makes the first client render
   disagree with the server's, and React then leaves the server's version in place. */
export function Hero() {
  const ref = useRef<HTMLElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end start"] });
  // wishes hold their orbit until the phone is centred, then fall into it as it leaves
  const s = useTransform(scrollYProgress, [0.3, 0.8], [0, 1], { clamp: true });

  return (
    <motion.section ref={ref} className="a-hero" style={{ "--s": s } as never}>
      <div className="g-wrap a-hero__copy">
        <a className="a-pill g-glass" href="#track">
          <Sparkle still />
          New: price-drop alerts
          <Icon name="arrow-up-right" />
        </a>
        <h1 className="a-h1">
          <span>Wish it.</span> <span>Share it.</span>{" "}
          <span>
            <Reveal as="span" plain className="a-ring">
              Get it.
              <HandRing />
              <Sparkle />
            </Reveal>
          </span>
        </h1>
        <p className="a-sub">
          Save anything from any app. Send one link. Friends claim gifts without downloading a thing.
        </p>
        <div className="a-cta">
          <AppStoreButton />
          <QRCard className="a-cta__qr" />
        </div>
        <p className="a-cta__note">Free. Pro is a one-time $4.99.</p>
      </div>

      <Tilt className="a-stage">
        <div className="a-halo" aria-hidden="true" />
        <Phone screens={[SCREENS.homeDark]} eager className="a-hero__phone" />
        {WISHES.map((wish, i) => (
          <WishCard
            key={wish.name}
            wish={wish}
            className={`a-orb a-orb--${i + 1}`}
            style={vars({
              "--x": `${ORBIT[i].x}px`,
              "--y": `${ORBIT[i].y}px`,
              "--k": ORBIT[i].k,
              animationDuration: `${ORBIT[i].dur}s`,
              animationDelay: `${ORBIT[i].delay}s`,
            })}
          />
        ))}
      </Tilt>
    </motion.section>
  );
}

const STATEMENT = "Every birthday, someone asks what you want. Gimme is the answer you send.";

export function Statement() {
  const ref = useRef<HTMLParagraphElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start 0.88", "end 0.42"] });
  const words = STATEMENT.split(" ");

  return (
    <section className="a-statement">
      <div className="g-wrap">
        <motion.p
          ref={ref}
          className="a-statement__text"
          style={{ "--p": scrollYProgress, "--n": words.length } as never}
        >
          {words.map((word, i) => (
            <span key={i} style={vars({ "--i": i })}>
              {word}{" "}
            </span>
          ))}
        </motion.p>
      </div>
    </section>
  );
}

const STORY_SCREENS = [SCREENS.addDark, SCREENS.shareDark, SCREENS.listDark, SCREENS.itemDark];
const STORY_TINT = ["#6C63FF", "#3B8DD4", "#FF8A5C", "#30D158"];

const DEMOS: ReactNode[] = [
  <AutoFill key="save" />,
  <div key="share" className="a-share">
    <LinkPreview />
    <span className="g-chip g-glass">
      <span className="g-chip__ic" style={vars({ "--c": "#3B8DD4" })}>
        <Icon name="link" />
      </span>
      <span>
        Opens in any browser
        <small>No app, no account</small>
      </span>
    </span>
  </div>,
  <ClaimCard key="claim" />,
  <PriceCard key="track" />,
];

export function Story() {
  const [active, setActive] = useState(0);
  const steps = useRef<Array<HTMLElement | null>>([]);

  useEffect(() => {
    if (typeof IntersectionObserver === "undefined") return;
    // a step is "current" while it crosses the middle of the viewport
    const io = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) setActive(Number((entry.target as HTMLElement).dataset.i));
        }
      },
      { rootMargin: "-48% 0px -48% 0px" },
    );
    steps.current.forEach((el) => el && io.observe(el));
    return () => io.disconnect();
  }, []);

  return (
    <section id="how" className="a-story">
      <div className="g-wrap a-story__grid">
        <div className="a-story__steps">
          {STEPS.map((step, i) => (
            <article
              key={step.key}
              id={step.key === "track" ? "track" : undefined}
              ref={(el) => {
                steps.current[i] = el;
              }}
              data-i={i}
              data-active={active === i}
              className="a-step"
            >
              <p className="g-eyebrow">
                <span className="a-step__n">0{i + 1}</span> {step.label}
              </p>
              <h2 className="a-step__title">{step.title}</h2>
              <p className="a-step__body">{step.body}</p>
              <div className="a-step__demo">{DEMOS[i]}</div>
              <div className="a-step__phone">
                <Phone screens={[STORY_SCREENS[i]]} />
              </div>
            </article>
          ))}
        </div>

        <div className="a-story__stage" style={vars({ "--tint": STORY_TINT[active] })}>
          <div className="a-story__halo" aria-hidden="true" />
          <Phone screens={STORY_SCREENS} active={active} className="a-story__phone" />
          <ol className="a-story__dots" aria-hidden="true">
            {STEPS.map((step, i) => (
              <li key={step.key} data-active={active === i}>
                {step.label}
              </li>
            ))}
          </ol>
        </div>
      </div>
    </section>
  );
}
