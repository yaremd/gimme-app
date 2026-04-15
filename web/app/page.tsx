const APP_STORE_URL = "https://apps.apple.com/app/gimme-wishlist-gift-ideas/id0000000000"; // TODO: Replace with real App Store URL

export default function Home() {
  return (
    <main className="landing min-h-[100dvh] overflow-x-hidden">
      {/* ── Floating pill nav ── */}
      <nav className="max-w-[1400px] mx-auto px-4 md:px-12 pt-5 l-anim">
        <div className="mx-auto w-full md:w-max flex items-center justify-between md:justify-center gap-8 rounded-full px-5 py-3 bg-white/60 border border-[#18181B]/[0.04] shadow-[0_2px_12px_rgba(24,24,27,0.04)]"
          style={{ backdropFilter: "blur(12px)", WebkitBackdropFilter: "blur(12px)" }}
        >
          <div className="flex items-center gap-2.5">
            <img src="/app-icon.png" alt="Gimme" width={28} height={28} className="rounded-lg" />
            <span className="text-[15px] font-semibold tracking-tight">Gimme</span>
          </div>
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="group inline-flex items-center gap-2 rounded-full pl-4 pr-1.5 py-1.5 text-xs font-semibold l-cta no-underline"
          >
            <span>Download</span>
            <span className="l-cta-arrow w-6 h-6 rounded-full bg-white/10 flex items-center justify-center">
              <svg width="10" height="10" viewBox="0 0 10 10" fill="none"><path d="M2.5 7.5L7.5 2.5M7.5 2.5H3.5M7.5 2.5V6.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round"/></svg>
            </span>
          </a>
        </div>
      </nav>

      {/* ── Hero — Editorial Split ── */}
      <section className="relative max-w-[1400px] mx-auto px-6 md:px-12 pt-24 md:pt-40 pb-32 md:pb-48">
        {/* Decorative shapes */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none" aria-hidden="true">
          <div className="absolute -top-20 right-[10%] w-[300px] h-[220px] rounded-[48px] bg-[#3D3580]/[0.03] rotate-12 l-float" />
          <div className="absolute top-[45%] -left-20 w-[240px] h-[180px] rounded-[40px] bg-[#C4956A]/[0.04] -rotate-6 l-float-alt" />
          <div className="absolute bottom-10 right-[20%] w-[180px] h-[140px] rounded-[36px] bg-[#3D3580]/[0.02] rotate-3 l-float" style={{ animationDelay: "3s" }} />
        </div>

        <div className="relative grid grid-cols-1 md:grid-cols-2 gap-16 md:gap-20 items-center">
          {/* Left: Text */}
          <div>
            <div className="l-anim l-d1">
              <span className="l-eyebrow mb-6 inline-flex">
                <svg width="12" height="12" viewBox="0 0 12 12" fill="none" className="opacity-60"><path d="M6 1v10M1 6h10" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/></svg>
                Wishlist for iPhone
              </span>
            </div>
            <h1 className="text-[clamp(2.5rem,6vw,4.5rem)] font-bold tracking-[-0.04em] leading-[1.02] mb-6 l-anim l-d2">
              Your wishes,<br />all in one place
            </h1>
            <p className="text-lg md:text-xl leading-[1.7] max-w-[480px] mb-10 l-anim l-d3" style={{ color: "var(--l-muted)" }}>
              Save what you want from any app. Share a link with friends and family — they claim gifts without downloading anything.
            </p>
            <div className="flex flex-col sm:flex-row items-start gap-5 l-anim l-d4">
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="group inline-flex items-center gap-3 rounded-full pl-6 pr-2 py-2 text-[15px] font-semibold l-cta no-underline"
              >
                <svg width="16" height="20" viewBox="0 0 16 20" fill="currentColor" className="shrink-0">
                  <path d="M11.86 10.36c-.03-2.3 1.88-3.4 1.97-3.46-1.07-1.57-2.74-1.78-3.34-1.81-1.42-.14-2.77.84-3.49.84s-1.83-.82-3.01-.8c-1.55.03-2.98.9-3.78 2.29-1.61 2.79-.41 6.93 1.16 9.19.77 1.11 1.68 2.36 2.88 2.31 1.16-.05 1.6-.75 3-.75s1.79.75 3.01.73c1.24-.03 2.04-1.13 2.8-2.24.88-1.29 1.24-2.53 1.27-2.6-.03-.01-2.44-.94-2.47-3.7zM9.53 3.5c.64-.77 1.07-1.85.95-2.92-.92.04-2.03.61-2.69 1.38-.59.68-1.11 1.77-.97 2.82 1.02.08 2.07-.52 2.71-1.28z"/>
                </svg>
                <span>Download on the App Store</span>
                <span className="l-cta-arrow w-8 h-8 rounded-full bg-white/10 flex items-center justify-center ml-1">
                  <svg width="12" height="12" viewBox="0 0 12 12" fill="none"><path d="M3 9L9 3M9 3H4.5M9 3V7.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round"/></svg>
                </span>
              </a>
              <span className="text-sm font-medium pt-2.5" style={{ color: "var(--l-muted)" }}>
                Free with optional Pro upgrade
              </span>
            </div>
          </div>

          {/* Right: App icon in Double-Bezel shell */}
          <div className="flex items-center justify-center l-anim l-d5">
            <div className="doppel-outer p-2 md:p-3">
              <div className="doppel-inner p-8 md:p-12 flex items-center justify-center">
                <div className="relative">
                  <div className="absolute inset-0 rounded-[40px] bg-[#3D3580]/[0.05] scale-[1.5] blur-3xl" />
                  <img
                    src="/app-icon.png"
                    alt="Gimme"
                    width={180}
                    height={180}
                    className="relative rounded-[40px] shadow-[0_24px_64px_rgba(24,24,27,0.1)]"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── Features — Asymmetrical Bento Grid ── */}
      <section className="max-w-[1400px] mx-auto px-6 md:px-12 py-32 md:py-40">
        <div className="mb-16 md:mb-20 max-w-2xl l-anim">
          <span className="l-eyebrow mb-5 inline-flex">Features</span>
          <h2 className="text-3xl md:text-[2.75rem] font-bold tracking-[-0.03em] leading-[1.1]">
            Built for how you actually use your iPhone
          </h2>
        </div>

        <div className="l-bento">
          {/* Row 1: 8 + 4 */}
          <div className="l-bento-8 l-anim l-d1">
            <BentoCard>
              <div className="flex flex-col md:flex-row gap-8 items-start">
                <div className="flex-1">
                  <span className="l-eyebrow mb-4 inline-flex">Sharing</span>
                  <h3 className="text-xl md:text-2xl font-bold tracking-tight mb-3 leading-snug">
                    Send a link. That&apos;s it.
                  </h3>
                  <p className="text-sm leading-relaxed max-w-sm" style={{ color: "var(--l-muted)" }}>
                    Friends see your wishes on a clean web page and quietly claim what they&apos;re getting. No downloads, no sign-ups.
                  </p>
                </div>
                <div className="doppel-outer-dark shrink-0 w-full md:w-[260px]">
                  <div className="doppel-inner-dark p-5">
                    <div className="flex items-center gap-2.5 mb-4">
                      <div className="w-8 h-8 rounded-lg bg-rose-500/20 flex items-center justify-center">
                        <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M2.5 7.5v3.5a1 1 0 001 1h7a1 1 0 001-1V7.5M9.5 4L7 1.5 4.5 4M7 1.5V9" stroke="#F43F5E" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round"/></svg>
                      </div>
                      <div>
                        <p className="text-xs font-semibold">Birthday Wishes</p>
                        <p className="text-[10px] text-white/30">gimmelist.com/share/...</p>
                      </div>
                    </div>
                    <div className="space-y-1.5">
                      <MockRow title="AirPods Max" price="$549" claimed />
                      <MockRow title="Kindle Paperwhite" price="$149" />
                      <MockRow title="Patagonia Fleece" price="$179" />
                    </div>
                  </div>
                </div>
              </div>
            </BentoCard>
          </div>

          <div className="l-bento-4 l-anim l-d2">
            <BentoCard>
              <span className="l-eyebrow mb-4 inline-flex">Capture</span>
              <h3 className="text-xl font-bold tracking-tight mb-3 leading-snug">
                Save from anywhere
              </h3>
              <p className="text-sm leading-relaxed mb-5" style={{ color: "var(--l-muted)" }}>
                Share Extension auto-fills title, image, and price from any URL.
              </p>
              <div className="doppel-outer-dark">
                <div className="doppel-inner-dark p-4">
                  <div className="flex items-center gap-1.5 mb-2">
                    <div className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
                    <p className="text-[10px] text-white/35">Auto-filled</p>
                  </div>
                  <p className="text-sm font-semibold">Sony WH-1000XM5</p>
                  <p className="text-lg font-bold mt-1 tabular-nums">$348.00</p>
                </div>
              </div>
            </BentoCard>
          </div>

          {/* Row 2: 5 + 7 */}
          <div className="l-bento-5 l-anim l-d3">
            <BentoCard>
              <span className="l-eyebrow mb-4 inline-flex">Native</span>
              <h3 className="text-xl font-bold tracking-tight mb-3 leading-snug">
                Widgets. Siri. Spotlight.
              </h3>
              <p className="text-sm leading-relaxed mb-5" style={{ color: "var(--l-muted)" }}>
                Home Screen and Lock Screen widgets. Five Siri Shortcuts. Spotlight finds any item instantly.
              </p>
              <div className="grid grid-cols-2 gap-2">
                <div className="doppel-outer-dark">
                  <div className="doppel-inner-dark p-3">
                    <p className="text-[9px] text-white/25 uppercase tracking-widest mb-1.5">Widget</p>
                    <p className="text-xl font-bold tabular-nums">$2,340</p>
                    <p className="text-[10px] text-white/35 mt-0.5">12 remaining</p>
                  </div>
                </div>
                <div className="doppel-outer-dark">
                  <div className="doppel-inner-dark p-3">
                    <p className="text-[9px] text-white/25 uppercase tracking-widest mb-1.5">Siri</p>
                    <div className="w-5 h-5 rounded-full bg-gradient-to-br from-blue-400 to-violet-500 mb-1.5" />
                    <p className="text-[10px] text-white/40 italic">&ldquo;Add wish&rdquo;</p>
                  </div>
                </div>
              </div>
            </BentoCard>
          </div>

          <div className="l-bento-7 l-anim l-d4">
            <BentoCard>
              <span className="l-eyebrow mb-4 inline-flex">Stats</span>
              <h3 className="text-xl md:text-2xl font-bold tracking-tight mb-3 leading-snug">
                See where your money goes
              </h3>
              <p className="text-sm leading-relaxed mb-6" style={{ color: "var(--l-muted)" }}>
                Visual breakdown of your spending by list and priority. Supports 9 currencies with automatic conversion.
              </p>
              <div className="doppel-outer-dark">
                <div className="doppel-inner-dark p-5">
                  <div className="flex items-end gap-6">
                    <div>
                      <p className="text-[10px] text-white/30 uppercase tracking-widest mb-1">Total value</p>
                      <p className="text-3xl font-bold tabular-nums">$4,847</p>
                    </div>
                    <div className="flex items-end gap-1 pb-1">
                      {[40, 65, 45, 80, 55, 70, 90].map((h, i) => (
                        <div key={i} className="w-3 rounded-sm bg-white/10" style={{ height: `${h * 0.4}px` }} />
                      ))}
                    </div>
                  </div>
                  <div className="flex gap-4 mt-4 pt-3 border-t border-white/[0.06]">
                    <div>
                      <p className="text-[10px] text-white/30">Purchased</p>
                      <p className="text-sm font-semibold tabular-nums text-emerald-400">$1,290</p>
                    </div>
                    <div>
                      <p className="text-[10px] text-white/30">Remaining</p>
                      <p className="text-sm font-semibold tabular-nums">$3,557</p>
                    </div>
                    <div>
                      <p className="text-[10px] text-white/30">Lists</p>
                      <p className="text-sm font-semibold tabular-nums">7</p>
                    </div>
                  </div>
                </div>
              </div>
            </BentoCard>
          </div>
        </div>
      </section>

      {/* ── How it works — Editorial numbered ── */}
      <section className="py-32 md:py-40" style={{ background: "var(--l-surface)" }}>
        <div className="max-w-[1400px] mx-auto px-6 md:px-12">
          <div className="mb-16 md:mb-20 max-w-xl">
            <span className="l-eyebrow mb-5 inline-flex">How it works</span>
            <h2 className="text-3xl md:text-[2.75rem] font-bold tracking-[-0.03em] leading-[1.1]">
              Three steps.<br />Zero friction.
            </h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {[
              { n: "01", t: "Add your wishes", d: "Paste a link or add manually. Title, price, and image auto-fill from any URL." },
              { n: "02", t: "Share a link", d: "Tap share on any list. Friends get a clean web page with your wishes visible instantly." },
              { n: "03", t: "Friends claim gifts", d: "They pick what they're getting. You see the count, but never who claimed what." },
            ].map((s) => (
              <div key={s.n} className="doppel-outer">
                <div className="doppel-inner p-8 md:p-10">
                  <p className="text-5xl md:text-6xl font-bold tracking-[-0.05em] mb-5" style={{ color: "var(--l-accent)", opacity: 0.12 }}>
                    {s.n}
                  </p>
                  <h3 className="text-lg font-bold tracking-tight mb-2.5">{s.t}</h3>
                  <p className="text-sm leading-relaxed" style={{ color: "var(--l-muted)" }}>{s.d}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── More features — clean list ── */}
      <section className="max-w-[1400px] mx-auto px-6 md:px-12 py-32 md:py-40">
        <div className="mb-16 md:mb-20 max-w-xl">
          <span className="l-eyebrow mb-5 inline-flex">And more</span>
          <h2 className="text-3xl md:text-[2.75rem] font-bold tracking-[-0.03em] leading-[1.1]">
            Every detail, considered
          </h2>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-16 gap-y-10 max-w-3xl">
          <FeatureItem
            icon={<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M9 2v14M2 9h14" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/></svg>}
            title="Unlimited lists"
            description="Birthday, holiday, personal. Create a list for every occasion with custom colors."
          />
          <FeatureItem
            icon={<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><circle cx="9" cy="9" r="6.5" stroke="currentColor" strokeWidth="1.2"/><path d="M9 5.5v3.5l2 2" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round"/></svg>}
            title="Reminders"
            description="Get notified 1 day, 3 days, or 1 week before birthdays and events."
          />
          <FeatureItem
            icon={<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><rect x="2.5" y="2.5" width="13" height="13" rx="3" stroke="currentColor" strokeWidth="1.2"/><path d="M6 6h6M6 9h4" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/></svg>}
            title="Share Extension"
            description="Save items from Safari, Amazon, or any app with one tap."
          />
          <FeatureItem
            icon={<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M14.5 9c0 3.04-2.46 5.5-5.5 5.5S3.5 12.04 3.5 9 5.96 3.5 9 3.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/><path d="M12 3.5h3.5V7" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round"/></svg>}
            title="Cloud sync"
            description="Sign in with Apple or email. Your wishes stay in sync across devices."
          />
          <FeatureItem
            icon={<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><rect x="4" y="1.5" width="10" height="15" rx="2" stroke="currentColor" strokeWidth="1.2"/><path d="M7.5 13.5h3" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/></svg>}
            title="Privacy first"
            description="No ads, no tracking SDKs. Works fully offline. Your data stays on your device."
          />
          <FeatureItem
            icon={<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M4.5 9l3 3 6-6" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round"/></svg>}
            title="One purchase, forever"
            description="No subscriptions. Gimme Pro is a single lifetime purchase."
          />
        </div>
      </section>

      {/* ── Pricing — Double-Bezel cards ── */}
      <section className="py-32 md:py-40" style={{ background: "var(--l-surface)" }}>
        <div className="max-w-[1400px] mx-auto px-6 md:px-12">
          <div className="text-center mb-16 md:mb-20">
            <span className="l-eyebrow mb-5 inline-flex">Pricing</span>
            <h2 className="text-3xl md:text-[2.75rem] font-bold tracking-[-0.03em] leading-[1.1] mb-4">
              One price. Yours forever.
            </h2>
            <p className="text-base max-w-md mx-auto leading-relaxed" style={{ color: "var(--l-muted)" }}>
              No subscriptions, no recurring charges. Pay once and get every future update included.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 max-w-2xl mx-auto">
            {/* Free */}
            <div className="doppel-outer">
              <div className="doppel-inner p-8 md:p-10">
                <p className="text-sm font-semibold mb-1" style={{ color: "var(--l-muted)" }}>Free</p>
                <p className="text-4xl font-bold tracking-[-0.03em] mb-8">$0</p>
                <ul className="space-y-3.5">
                  <PricingRow text="Unlimited lists and items" />
                  <PricingRow text="Share Extension" />
                  <PricingRow text="Home Screen widgets" />
                  <PricingRow text="Siri Shortcuts" />
                </ul>
              </div>
            </div>

            {/* Pro */}
            <div className="doppel-outer-dark">
              <div className="doppel-inner-dark p-8 md:p-10 relative overflow-hidden">
                <div className="absolute top-5 right-5 text-[10px] font-semibold uppercase tracking-[0.15em] rounded-full px-3 py-1 bg-white/10 border border-white/[0.06]">
                  Lifetime
                </div>
                <p className="text-sm font-semibold mb-1 text-white/50">Gimme Pro</p>
                <p className="text-4xl font-bold tracking-[-0.03em] mb-8">$4.99</p>
                <ul className="space-y-3.5">
                  <PricingRow text="Everything in Free" light />
                  <PricingRow text="Cloud sync across devices" light />
                  <PricingRow text="Share wishlists via link" light />
                  <PricingRow text="Stats dashboard" light />
                  <PricingRow text="All future features" light />
                </ul>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── Bottom CTA ── */}
      <section className="max-w-[1400px] mx-auto px-6 md:px-12 py-32 md:py-44 text-center">
        <h2 className="text-3xl md:text-[3.5rem] font-bold tracking-[-0.04em] leading-[1.05] mb-6">
          Start saving your wishes
        </h2>
        <p className="text-lg mb-10 max-w-md mx-auto leading-relaxed" style={{ color: "var(--l-muted)" }}>
          Download Gimme and create your first wishlist in seconds.
        </p>
        <a
          href={APP_STORE_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="group inline-flex items-center gap-3 rounded-full pl-7 pr-2 py-2.5 text-[15px] font-semibold l-cta no-underline"
        >
          <svg width="16" height="20" viewBox="0 0 16 20" fill="currentColor" className="shrink-0">
            <path d="M11.86 10.36c-.03-2.3 1.88-3.4 1.97-3.46-1.07-1.57-2.74-1.78-3.34-1.81-1.42-.14-2.77.84-3.49.84s-1.83-.82-3.01-.8c-1.55.03-2.98.9-3.78 2.29-1.61 2.79-.41 6.93 1.16 9.19.77 1.11 1.68 2.36 2.88 2.31 1.16-.05 1.6-.75 3-.75s1.79.75 3.01.73c1.24-.03 2.04-1.13 2.8-2.24.88-1.29 1.24-2.53 1.27-2.6-.03-.01-2.44-.94-2.47-3.7zM9.53 3.5c.64-.77 1.07-1.85.95-2.92-.92.04-2.03.61-2.69 1.38-.59.68-1.11 1.77-.97 2.82 1.02.08 2.07-.52 2.71-1.28z"/>
          </svg>
          <span>Download on the App Store</span>
          <span className="l-cta-arrow w-8 h-8 rounded-full bg-white/10 flex items-center justify-center ml-1">
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none"><path d="M3 9L9 3M9 3H4.5M9 3V7.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </span>
        </a>
      </section>

      {/* ── Footer ── */}
      <footer className="border-t" style={{ borderColor: "var(--l-border)" }}>
        <div className="max-w-[1400px] mx-auto px-6 md:px-12 py-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-6 text-sm" style={{ color: "var(--l-muted)" }}>
            <a href="/support" className="no-underline hover:opacity-70 transition-opacity" style={{ color: "var(--l-muted)" }}>Support</a>
            <a href="/privacy" className="no-underline hover:opacity-70 transition-opacity" style={{ color: "var(--l-muted)" }}>Privacy</a>
            <a href="/terms" className="no-underline hover:opacity-70 transition-opacity" style={{ color: "var(--l-muted)" }}>Terms</a>
            <a href="/contact" className="no-underline hover:opacity-70 transition-opacity" style={{ color: "var(--l-muted)" }}>Contact</a>
          </div>
          <p className="text-sm" style={{ color: "var(--l-muted)", opacity: 0.5 }}>
            Dmytro Yaremchuk 2026
          </p>
        </div>
      </footer>
    </main>
  );
}

/* ── Bento Card — Double-Bezel architecture ── */
function BentoCard({ children }: { children: React.ReactNode }) {
  return (
    <div className="doppel-outer h-full">
      <div className="doppel-inner p-7 md:p-9 h-full">
        {children}
      </div>
    </div>
  );
}

/* ── Feature list item ── */
function FeatureItem({
  icon,
  title,
  description,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
}) {
  return (
    <div className="flex gap-4">
      <div className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0" style={{ background: "var(--l-accent-soft)", color: "var(--l-accent)" }}>
        {icon}
      </div>
      <div>
        <h4 className="text-[15px] font-semibold mb-1 tracking-tight">{title}</h4>
        <p className="text-sm leading-relaxed" style={{ color: "var(--l-muted)" }}>{description}</p>
      </div>
    </div>
  );
}

/* ── Mock wishlist row (inside dark cards) ── */
function MockRow({ title, price, claimed }: { title: string; price: string; claimed?: boolean }) {
  return (
    <div className="flex items-center justify-between rounded-lg bg-white/[0.04] border border-white/[0.04] px-3 py-2">
      <div>
        <p className={`text-xs font-medium ${claimed ? "text-white/35 line-through" : ""}`}>{title}</p>
        <p className="text-[10px] text-white/25 tabular-nums">{price}</p>
      </div>
      {claimed && (
        <span className="text-[9px] font-semibold bg-emerald-500/15 text-emerald-400 rounded-full px-2 py-0.5">
          Claimed
        </span>
      )}
    </div>
  );
}

/* ── Pricing row ── */
function PricingRow({ text, light }: { text: string; light?: boolean }) {
  return (
    <li className="flex items-center gap-3 text-sm">
      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" className="shrink-0">
        <path d="M3 7.5l2.5 2.5L11 4" stroke={light ? "rgba(255,255,255,0.4)" : "var(--l-accent)"} strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
      <span style={{ opacity: light ? 0.75 : 1 }}>{text}</span>
    </li>
  );
}
