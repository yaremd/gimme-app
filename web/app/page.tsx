const APP_STORE_URL = "https://apps.apple.com/app/gimme-wishlist-gift-ideas/id6762543923";

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
                <div className="shrink-0 w-full md:w-[260px] flex items-center justify-center">
                  <SharingIllustration />
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
              <CaptureIllustration />
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
              <NativeIllustration />
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
              <StatsIllustration />
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

      {/* ── More features — split layout with illustration ── */}
      <section className="max-w-[1400px] mx-auto px-6 md:px-12 py-32 md:py-40">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 lg:gap-24 items-center">
          {/* Left: heading + feature list */}
          <div>
            <div className="mb-14 md:mb-16">
              <span className="l-eyebrow mb-5 inline-flex">And more</span>
              <h2 className="text-3xl md:text-[2.75rem] font-bold tracking-[-0.03em] leading-[1.1]">
                Every detail, considered
              </h2>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-12 gap-y-10">
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
          </div>
          {/* Right: decorative illustration */}
          <div className="flex items-center justify-center lg:justify-end">
            <AndMoreIllustration />
          </div>
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

/* ── Sharing Illustration ── */
function SharingIllustration() {
  return (
    <svg viewBox="0 0 260 140" fill="none" xmlns="http://www.w3.org/2000/svg"
         className="w-full h-auto" aria-hidden="true" role="presentation">
      {/* Left phone */}
      <rect x="8" y="16" width="52" height="90" rx="10" fill="#F5F2EC" stroke="#3D3580" strokeWidth="1.5" strokeOpacity="0.55"/>
      <rect x="14" y="23" width="40" height="64" rx="5" fill="#3D3580" fillOpacity="0.04"/>
      <rect x="22" y="20" width="18" height="2.5" rx="1.25" fill="#3D3580" fillOpacity="0.15"/>
      {/* Share icon on left screen */}
      <circle cx="34" cy="55" r="12" fill="#3D3580" fillOpacity="0.07"/>
      <path d="M30 58L34 54L38 58M34 54V63" stroke="#3D3580" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" strokeOpacity="0.55"/>
      {/* Dashed arc */}
      <path d="M62 60 C92 16 168 16 198 60" stroke="#3D3580" strokeWidth="1.5" strokeDasharray="5 3.5" strokeLinecap="round" fill="none" strokeOpacity="0.28"/>
      {/* Gift box — shadow */}
      <ellipse cx="130" cy="50" rx="19" ry="4.5" fill="#18181B" fillOpacity="0.05"/>
      {/* Gift box — body */}
      <rect x="119" y="34" width="22" height="16" rx="3" fill="#FDFBF7" stroke="#3D3580" strokeWidth="1.2" strokeOpacity="0.65"/>
      {/* Gift box — lid */}
      <rect x="117" y="24" width="26" height="12" rx="3" fill="#3D3580"/>
      {/* Ribbon vertical */}
      <line x1="130" y1="24" x2="130" y2="50" stroke="#C4956A" strokeWidth="1.5"/>
      {/* Ribbon horizontal */}
      <line x1="117" y1="34" x2="143" y2="34" stroke="#C4956A" strokeWidth="1.5"/>
      {/* Bow loops */}
      <path d="M125.5 23 Q128 17 130 23" stroke="#C4956A" strokeWidth="1.3" strokeLinecap="round" fill="none"/>
      <path d="M130 23 Q132 17 134.5 23" stroke="#C4956A" strokeWidth="1.3" strokeLinecap="round" fill="none"/>
      {/* Right phone */}
      <rect x="200" y="16" width="52" height="90" rx="10" fill="#F5F2EC" stroke="#3D3580" strokeWidth="1.5" strokeOpacity="0.55"/>
      <rect x="206" y="23" width="40" height="64" rx="5" fill="#3D3580" fillOpacity="0.04"/>
      <rect x="218" y="20" width="18" height="2.5" rx="1.25" fill="#3D3580" fillOpacity="0.15"/>
      {/* Wishlist rows on right phone */}
      <rect x="210" y="32" width="32" height="5" rx="2.5" fill="#3D3580" fillOpacity="0.13"/>
      <rect x="210" y="42" width="26" height="4" rx="2" fill="#3D3580" fillOpacity="0.09"/>
      <rect x="232" y="41" width="9" height="6" rx="3" fill="#10B981" fillOpacity="0.18"/>
      <path d="M233.5 44L235 45.5L237.5 43" stroke="#10B981" strokeWidth="0.9" strokeLinecap="round" strokeLinejoin="round"/>
      <rect x="210" y="52" width="28" height="4" rx="2" fill="#3D3580" fillOpacity="0.09"/>
      <rect x="210" y="61" width="24" height="4" rx="2" fill="#3D3580" fillOpacity="0.09"/>
      {/* Sparkles */}
      <g transform="translate(74,16)" fill="#3D3580" fillOpacity="0.32">
        <path d="M0,-5.5 L1.6,-1.6 L5.5,0 L1.6,1.6 L0,5.5 L-1.6,1.6 L-5.5,0 L-1.6,-1.6 Z"/>
      </g>
      <g transform="translate(186,18)" fill="#C4956A" fillOpacity="0.5">
        <path d="M0,-4.5 L1.4,-1.4 L4.5,0 L1.4,1.4 L0,4.5 L-1.4,1.4 L-4.5,0 L-1.4,-1.4 Z"/>
      </g>
      <g transform="translate(95,110)" fill="#3D3580" fillOpacity="0.16">
        <path d="M0,-3 L0.9,-0.9 L3,0 L0.9,0.9 L0,3 L-0.9,0.9 L-3,0 L-0.9,-0.9 Z"/>
      </g>
      <g transform="translate(163,114)" fill="#C4956A" fillOpacity="0.22">
        <path d="M0,-3.5 L1,-1 L3.5,0 L1,1 L0,3.5 L-1,1 L-3.5,0 L-1,-1 Z"/>
      </g>
    </svg>
  );
}

/* ── Capture Illustration ── */
function CaptureIllustration() {
  return (
    <svg viewBox="0 0 210 132" fill="none" xmlns="http://www.w3.org/2000/svg"
         className="w-full h-auto" aria-hidden="true" role="presentation">
      {/* Browser address bar */}
      <rect x="8" y="8" width="194" height="30" rx="15" fill="#F5F2EC" stroke="#3D3580" strokeWidth="1" strokeOpacity="0.18"/>
      {/* Emerald dot */}
      <circle cx="25" cy="23" r="4.5" fill="#10B981"/>
      {/* URL placeholder rects */}
      <rect x="38" y="19" width="55" height="7" rx="3.5" fill="#3D3580" fillOpacity="0.11"/>
      <rect x="99" y="19" width="38" height="7" rx="3.5" fill="#3D3580" fillOpacity="0.06"/>
      {/* Down arrow */}
      <line x1="105" y1="41" x2="105" y2="58" stroke="#3D3580" strokeWidth="1.5" strokeOpacity="0.25" strokeLinecap="round"/>
      <path d="M99 55L105 62L111 55" stroke="#3D3580" strokeWidth="1.5" strokeOpacity="0.25" strokeLinecap="round" strokeLinejoin="round"/>
      {/* Product card */}
      <rect x="8" y="65" width="194" height="60" rx="13" fill="white" stroke="#3D3580" strokeWidth="1" strokeOpacity="0.09"/>
      {/* Product image placeholder */}
      <rect x="18" y="75" width="38" height="40" rx="9" fill="#3D3580" fillOpacity="0.07"/>
      {/* Headphone arc suggestion */}
      <path d="M26 92 Q37 84 48 92" stroke="#3D3580" strokeWidth="1.2" strokeOpacity="0.25" fill="none" strokeLinecap="round"/>
      <circle cx="27" cy="93" r="3" fill="#3D3580" fillOpacity="0.15"/>
      <circle cx="47" cy="93" r="3" fill="#3D3580" fillOpacity="0.15"/>
      {/* Product title lines */}
      <rect x="64" y="76" width="95" height="7" rx="3.5" fill="#18181B" fillOpacity="0.14"/>
      <rect x="64" y="87" width="68" height="6" rx="3" fill="#18181B" fillOpacity="0.08"/>
      {/* Price */}
      <rect x="64" y="101" width="48" height="10" rx="4" fill="#3D3580" fillOpacity="0.11"/>
      {/* Auto-filled badge */}
      <circle cx="165" cy="76" r="4" fill="#10B981"/>
      <rect x="170" y="71" width="24" height="10" rx="5" fill="#10B981" fillOpacity="0.1" stroke="#10B981" strokeWidth="0.8" strokeOpacity="0.2"/>
    </svg>
  );
}

/* ── Native Illustration ── */
function NativeIllustration() {
  return (
    <svg viewBox="0 0 256 162" fill="none" xmlns="http://www.w3.org/2000/svg"
         className="w-full h-auto" aria-hidden="true" role="presentation">
      <defs>
        <linearGradient id="siriGrad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#60A5FA"/>
          <stop offset="100%" stopColor="#8B5CF6"/>
        </linearGradient>
      </defs>
      {/* Row 1 — app icons */}
      {/* Icon 0: purple (Gimme) */}
      <rect x="10" y="8" width="56" height="54" rx="13" fill="#3D3580" fillOpacity="0.1"/>
      <path d="M33 26v14M26 33h14" stroke="#3D3580" strokeWidth="1.8" strokeOpacity="0.38" strokeLinecap="round"/>
      {/* Icon 1: amber (Reminders) */}
      <rect x="74" y="8" width="56" height="54" rx="13" fill="#C4956A" fillOpacity="0.1"/>
      <circle cx="102" cy="35" r="10" stroke="#C4956A" strokeWidth="1.3" strokeOpacity="0.45" fill="none"/>
      <path d="M102 28v7l5 5" stroke="#C4956A" strokeWidth="1.2" strokeOpacity="0.5" strokeLinecap="round" strokeLinejoin="round"/>
      {/* Icon 2: cream (Share) */}
      <rect x="138" y="8" width="56" height="54" rx="13" fill="#F5F2EC"/>
      <circle cx="155" cy="35" r="5" stroke="#3D3580" strokeOpacity="0.2" strokeWidth="1.2" fill="none"/>
      <circle cx="175" cy="28" r="4" stroke="#3D3580" strokeOpacity="0.2" strokeWidth="1.2" fill="none"/>
      <circle cx="175" cy="42" r="4" stroke="#3D3580" strokeOpacity="0.2" strokeWidth="1.2" fill="none"/>
      <path d="M159 32.5L172 30M159 37.5L172 40" stroke="#3D3580" strokeOpacity="0.15" strokeWidth="1.1"/>
      {/* Row 2 — widget + icon + siri */}
      {/* Widget: purple, 2-col wide */}
      <rect x="10" y="70" width="120" height="80" rx="13" fill="#3D3580"/>
      {/* Widget label indicator rect */}
      <rect x="20" y="80" width="32" height="5" rx="2" fill="white" fillOpacity="0.22"/>
      {/* Amount rect (represents "$2,340") */}
      <rect x="20" y="91" width="72" height="14" rx="3.5" fill="white" fillOpacity="0.82"/>
      {/* Remaining rect */}
      <rect x="20" y="112" width="54" height="8" rx="2.5" fill="white" fillOpacity="0.32"/>
      {/* Remaining dots */}
      <circle cx="21" cy="132" r="3.5" fill="white" fillOpacity="0.55"/>
      <circle cx="29" cy="132" r="3.5" fill="white" fillOpacity="0.38"/>
      <circle cx="37" cy="132" r="3.5" fill="white" fillOpacity="0.22"/>
      <circle cx="45" cy="132" r="3.5" fill="white" fillOpacity="0.12"/>
      {/* Single icon: emerald (sync) */}
      <rect x="138" y="70" width="56" height="54" rx="13" fill="#10B981" fillOpacity="0.08"/>
      <path d="M161 82 Q174 80 178 90" stroke="#10B981" strokeOpacity="0.4" strokeWidth="1.4" fill="none" strokeLinecap="round"/>
      <path d="M178 90 Q180 100 171 106" stroke="#10B981" strokeOpacity="0.4" strokeWidth="1.4" fill="none" strokeLinecap="round"/>
      <path d="M161 82 L159 86 M161 82 L165 84" stroke="#10B981" strokeOpacity="0.4" strokeWidth="1.2" strokeLinecap="round"/>
      {/* Siri orb */}
      <circle cx="212" cy="107" r="24" fill="url(#siriGrad)" fillOpacity="0.09"/>
      <circle cx="212" cy="107" r="13" fill="url(#siriGrad)" fillOpacity="0.22"/>
      <circle cx="212" cy="107" r="6" fill="url(#siriGrad)" fillOpacity="0.65"/>
      {/* Siri label placeholder */}
      <rect x="198" y="137" width="28" height="6" rx="3" fill="#3D3580" fillOpacity="0.1"/>
    </svg>
  );
}

/* ── Stats Illustration ── */
function StatsIllustration() {
  const bars = [40, 65, 45, 80, 55, 70, 90];
  const maxH = 90;
  const barW = 26;
  const gap = 12;
  const baseY = 118;
  const startX = 16;
  return (
    <svg viewBox="0 0 300 148" fill="none" xmlns="http://www.w3.org/2000/svg"
         className="w-full h-auto" aria-hidden="true" role="presentation">
      {/* Bars */}
      {bars.map((h, i) => {
        const x = startX + i * (barW + gap);
        const opacity = 0.14 + (h / maxH) * 0.72;
        return (
          <rect key={i} x={x} y={baseY - h} width={barW} height={h} rx="5"
                fill="#3D3580" fillOpacity={opacity}/>
        );
      })}
      {/* Gift box on tallest bar (index 6, x=238, top=28) */}
      {(() => {
        const gi = 6;
        const gx = startX + gi * (barW + gap) + barW / 2; // center = 16 + 6*38 + 13 = 257
        const topY = baseY - bars[gi]; // 118 - 90 = 28
        return (
          <g>
            {/* Shadow */}
            <ellipse cx={gx} cy={topY - 2} rx="13" ry="3" fill="#18181B" fillOpacity="0.06"/>
            {/* Body */}
            <rect x={gx - 11} y={topY - 18} width="22" height="16" rx="3" fill="#FDFBF7" stroke="#3D3580" strokeWidth="1.2" strokeOpacity="0.6"/>
            {/* Lid */}
            <rect x={gx - 13} y={topY - 28} width="26" height="12" rx="3" fill="#3D3580"/>
            {/* Ribbon V */}
            <line x1={gx} y1={topY - 28} x2={gx} y2={topY - 2} stroke="#C4956A" strokeWidth="1.4"/>
            {/* Ribbon H */}
            <line x1={gx - 11} y1={topY - 18} x2={gx + 11} y2={topY - 18} stroke="#C4956A" strokeWidth="1.4"/>
            {/* Bow */}
            <path d={`M${gx - 4} ${topY - 29} Q${gx - 1} ${topY - 35} ${gx} ${topY - 29}`} stroke="#C4956A" strokeWidth="1.2" strokeLinecap="round" fill="none"/>
            <path d={`M${gx} ${topY - 29} Q${gx + 1} ${topY - 35} ${gx + 4} ${topY - 29}`} stroke="#C4956A" strokeWidth="1.2" strokeLinecap="round" fill="none"/>
          </g>
        );
      })()}
      {/* Divider */}
      <line x1="16" y1="124" x2="284" y2="124" stroke="#3D3580" strokeOpacity="0.08" strokeWidth="1"/>
      {/* Stat: Purchased */}
      <rect x="16" y="130" width="38" height="5" rx="2" fill="#18181B" fillOpacity="0.12"/>
      <rect x="16" y="139" width="44" height="7" rx="2.5" fill="#10B981" fillOpacity="0.55"/>
      {/* Stat: Remaining */}
      <rect x="110" y="130" width="38" height="5" rx="2" fill="#18181B" fillOpacity="0.12"/>
      <rect x="110" y="139" width="44" height="7" rx="2.5" fill="#3D3580" fillOpacity="0.22"/>
      {/* Stat: Lists */}
      <rect x="210" y="130" width="22" height="5" rx="2" fill="#18181B" fillOpacity="0.12"/>
      <rect x="210" y="139" width="16" height="7" rx="2.5" fill="#3D3580" fillOpacity="0.35"/>
    </svg>
  );
}

/* ── And More Illustration ── */
function AndMoreIllustration() {
  return (
    <svg viewBox="0 0 380 420" fill="none" xmlns="http://www.w3.org/2000/svg"
         className="w-full h-auto max-w-[420px]" aria-hidden="true" role="presentation">
      {/* Background card */}
      <rect x="4" y="4" width="372" height="412" rx="28" fill="#F5F2EC"/>
      {/* Purple glow blobs */}
      <ellipse cx="190" cy="210" rx="160" ry="140" fill="#3D3580" fillOpacity="0.03"/>
      <ellipse cx="290" cy="120" rx="80" ry="70" fill="#3D3580" fillOpacity="0.03"/>

      {/* Central list card */}
      <rect x="90" y="80" width="200" height="230" rx="16" fill="white" stroke="#3D3580" strokeWidth="1" strokeOpacity="0.08"/>
      {/* Card header line */}
      <rect x="108" y="98" width="80" height="8" rx="4" fill="#3D3580" fillOpacity="0.15"/>
      <rect x="108" y="110" width="50" height="6" rx="3" fill="#3D3580" fillOpacity="0.08"/>
      {/* Divider */}
      <line x1="90" y1="124" x2="290" y2="124" stroke="#3D3580" strokeOpacity="0.06" strokeWidth="1"/>
      {/* List item 1: checked */}
      <circle cx="108" cy="143" r="7" fill="#3D3580" fillOpacity="0.1"/>
      <path d="M105 143L107.5 145.5L111 141" stroke="#3D3580" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" strokeOpacity="0.6"/>
      <rect x="122" y="139" width="90" height="7" rx="3.5" fill="#3D3580" fillOpacity="0.14"/>
      <rect x="122" y="150" width="55" height="5" rx="2.5" fill="#3D3580" fillOpacity="0.07"/>
      {/* List item 2: checked */}
      <circle cx="108" cy="174" r="7" fill="#10B981" fillOpacity="0.12"/>
      <path d="M105 174L107.5 176.5L111 172" stroke="#10B981" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" strokeOpacity="0.7"/>
      <rect x="122" y="170" width="75" height="7" rx="3.5" fill="#3D3580" fillOpacity="0.14"/>
      <rect x="122" y="181" width="45" height="5" rx="2.5" fill="#3D3580" fillOpacity="0.07"/>
      {/* List item 3: pending */}
      <circle cx="108" cy="205" r="7" stroke="#C4956A" strokeWidth="1.3" strokeOpacity="0.4" fill="none"/>
      <rect x="122" y="201" width="85" height="7" rx="3.5" fill="#3D3580" fillOpacity="0.11"/>
      <rect x="122" y="212" width="60" height="5" rx="2.5" fill="#3D3580" fillOpacity="0.07"/>
      {/* List item 4: pending */}
      <circle cx="108" cy="236" r="7" stroke="#3D3580" strokeWidth="1.3" strokeOpacity="0.2" fill="none"/>
      <rect x="122" y="232" width="70" height="7" rx="3.5" fill="#3D3580" fillOpacity="0.09"/>
      <rect x="122" y="243" width="40" height="5" rx="2.5" fill="#3D3580" fillOpacity="0.05"/>
      {/* List item 5: pending */}
      <circle cx="108" cy="267" r="7" stroke="#3D3580" strokeWidth="1.3" strokeOpacity="0.2" fill="none"/>
      <rect x="122" y="263" width="80" height="7" rx="3.5" fill="#3D3580" fillOpacity="0.09"/>
      <rect x="122" y="274" width="50" height="5" rx="2.5" fill="#3D3580" fillOpacity="0.05"/>

      {/* === Gift box: top-right === */}
      <g transform="translate(280, 100) rotate(12)">
        <ellipse cx="0" cy="44" rx="28" ry="5" fill="#18181B" fillOpacity="0.06"/>
        <rect x="-26" y="10" width="52" height="34" rx="6" fill="white" stroke="#3D3580" strokeWidth="1.3" strokeOpacity="0.6"/>
        <rect x="-28" y="-4" width="56" height="16" rx="5" fill="#3D3580"/>
        <line x1="0" y1="-4" x2="0" y2="44" stroke="#C4956A" strokeWidth="1.8"/>
        <line x1="-26" y1="10" x2="26" y2="10" stroke="#C4956A" strokeWidth="1.8"/>
        <path d="M-5 -5 Q-2 -14 0 -5" stroke="#C4956A" strokeWidth="1.4" strokeLinecap="round" fill="none"/>
        <path d="M0 -5 Q2 -14 5 -5" stroke="#C4956A" strokeWidth="1.4" strokeLinecap="round" fill="none"/>
      </g>

      {/* === Gift box: bottom-left === */}
      <g transform="translate(72, 310) rotate(-8)">
        <ellipse cx="0" cy="36" rx="24" ry="4" fill="#18181B" fillOpacity="0.05"/>
        <rect x="-22" y="8" width="44" height="28" rx="5" fill="#F5F2EC" stroke="#C4956A" strokeWidth="1.3" strokeOpacity="0.55"/>
        <rect x="-24" y="-3" width="48" height="13" rx="4" fill="#C4956A" fillOpacity="0.75"/>
        <line x1="0" y1="-3" x2="0" y2="36" stroke="#3D3580" strokeWidth="1.5" strokeOpacity="0.5"/>
        <line x1="-22" y1="8" x2="22" y2="8" stroke="#3D3580" strokeWidth="1.5" strokeOpacity="0.5"/>
        <path d="M-4 -4 Q-1.5 -11 0 -4" stroke="#3D3580" strokeWidth="1.2" strokeLinecap="round" fill="none" strokeOpacity="0.5"/>
        <path d="M0 -4 Q1.5 -11 4 -4" stroke="#3D3580" strokeWidth="1.2" strokeLinecap="round" fill="none" strokeOpacity="0.5"/>
      </g>

      {/* === Gift box: top-left, small === */}
      <g transform="translate(44, 130) rotate(-14)">
        <ellipse cx="0" cy="29" rx="18" ry="3" fill="#18181B" fillOpacity="0.05"/>
        <rect x="-16" y="7" width="32" height="22" rx="4" fill="#FDFBF7" stroke="#C4956A" strokeWidth="1.2" strokeOpacity="0.5"/>
        <rect x="-18" y="-2" width="36" height="11" rx="3" fill="#C4956A" fillOpacity="0.65"/>
        <line x1="0" y1="-2" x2="0" y2="29" stroke="#3D3580" strokeWidth="1.2" strokeOpacity="0.4"/>
        <line x1="-16" y1="7" x2="16" y2="7" stroke="#3D3580" strokeWidth="1.2" strokeOpacity="0.4"/>
        <path d="M-3 -3 Q-1 -9 0 -3" stroke="#3D3580" strokeWidth="1" strokeLinecap="round" fill="none" strokeOpacity="0.4"/>
        <path d="M0 -3 Q1 -9 3 -3" stroke="#3D3580" strokeWidth="1" strokeLinecap="round" fill="none" strokeOpacity="0.4"/>
      </g>

      {/* === Gift box: bottom-right, medium === */}
      <g transform="translate(318, 305) rotate(6)">
        <ellipse cx="0" cy="40" rx="26" ry="4.5" fill="#18181B" fillOpacity="0.06"/>
        <rect x="-24" y="8" width="48" height="32" rx="6" fill="white" stroke="#3D3580" strokeWidth="1.3" strokeOpacity="0.6"/>
        <rect x="-26" y="-3" width="52" height="13" rx="4" fill="#3D3580" fillOpacity="0.85"/>
        <line x1="0" y1="-3" x2="0" y2="40" stroke="#C4956A" strokeWidth="1.6"/>
        <line x1="-24" y1="8" x2="24" y2="8" stroke="#C4956A" strokeWidth="1.6"/>
        <path d="M-4.5 -4 Q-1.5 -12 0 -4" stroke="#C4956A" strokeWidth="1.3" strokeLinecap="round" fill="none"/>
        <path d="M0 -4 Q1.5 -12 4.5 -4" stroke="#C4956A" strokeWidth="1.3" strokeLinecap="round" fill="none"/>
      </g>

      {/* Stars / sparkles */}
      <g transform="translate(58, 64)" fill="#3D3580" fillOpacity="0.3">
        <path d="M0,-6 L1.8,-1.8 L6,0 L1.8,1.8 L0,6 L-1.8,1.8 L-6,0 L-1.8,-1.8 Z"/>
      </g>
      <g transform="translate(328, 68)" fill="#C4956A" fillOpacity="0.42">
        <path d="M0,-5 L1.5,-1.5 L5,0 L1.5,1.5 L0,5 L-1.5,1.5 L-5,0 L-1.5,-1.5 Z"/>
      </g>
      <g transform="translate(348, 200)" fill="#3D3580" fillOpacity="0.2">
        <path d="M0,-4 L1.2,-1.2 L4,0 L1.2,1.2 L0,4 L-1.2,1.2 L-4,0 L-1.2,-1.2 Z"/>
      </g>
      <g transform="translate(32, 270)" fill="#C4956A" fillOpacity="0.28">
        <path d="M0,-4 L1.2,-1.2 L4,0 L1.2,1.2 L0,4 L-1.2,1.2 L-4,0 L-1.2,-1.2 Z"/>
      </g>
      <g transform="translate(180, 52)" fill="#3D3580" fillOpacity="0.16">
        <path d="M0,-3.5 L1,-1 L3.5,0 L1,1 L0,3.5 L-1,1 L-3.5,0 L-1,-1 Z"/>
      </g>
      <g transform="translate(200, 375)" fill="#C4956A" fillOpacity="0.22">
        <path d="M0,-3.5 L1,-1 L3.5,0 L1,1 L0,3.5 L-1,1 L-3.5,0 L-1,-1 Z"/>
      </g>
    </svg>
  );
}
