const APP_STORE_URL = "https://apps.apple.com/app/gimme-wishlist-gift-ideas/id0000000000"; // TODO: Replace

export function LegalLayout({
  eyebrow,
  title,
  subtitle,
  children,
}: {
  eyebrow: string;
  title: string;
  subtitle?: string;
  children: React.ReactNode;
}) {
  return (
    <main className="landing min-h-[100dvh]">
      {/* Nav */}
      <nav className="max-w-[1400px] mx-auto px-4 md:px-12 pt-5 l-anim">
        <div className="mx-auto w-full md:w-max flex items-center justify-between md:justify-center gap-8 rounded-full px-5 py-3 bg-white/60 border border-[#18181B]/[0.04] shadow-[0_2px_12px_rgba(24,24,27,0.04)]"
          style={{ backdropFilter: "blur(12px)", WebkitBackdropFilter: "blur(12px)" }}
        >
          <a href="/" className="flex items-center gap-2.5 no-underline" style={{ color: "var(--l-text)" }}>
            <img src="/app-icon.png" alt="Gimme" width={28} height={28} className="rounded-lg" />
            <span className="text-[15px] font-semibold tracking-tight">Gimme</span>
          </a>
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="group hidden sm:inline-flex items-center gap-2 rounded-full pl-4 pr-1.5 py-1.5 text-xs font-semibold l-cta no-underline"
          >
            <span>Download</span>
            <span className="l-cta-arrow w-6 h-6 rounded-full bg-white/10 flex items-center justify-center">
              <svg width="10" height="10" viewBox="0 0 10 10" fill="none"><path d="M2.5 7.5L7.5 2.5M7.5 2.5H3.5M7.5 2.5V6.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round"/></svg>
            </span>
          </a>
        </div>
      </nav>

      {/* Header */}
      <div className="max-w-2xl mx-auto px-6 md:px-12 pt-20 md:pt-28 mb-14 l-anim l-d1">
        <span className="l-eyebrow mb-5 inline-flex">{eyebrow}</span>
        <h1 className="text-3xl md:text-[2.75rem] font-bold tracking-[-0.03em] leading-[1.1] mb-3">
          {title}
        </h1>
        {subtitle && (
          <p className="text-base leading-relaxed" style={{ color: "var(--l-muted)" }}>
            {subtitle}
          </p>
        )}
      </div>

      {/* Content */}
      <div className="max-w-2xl mx-auto px-6 md:px-12 pb-20 l-anim l-d2">
        {children}
      </div>

      {/* Footer */}
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

/* Reusable section */
export function LegalSection({ title, children }: { title?: string; children: React.ReactNode }) {
  return (
    <section className="mb-10">
      {title && (
        <h2 className="text-lg font-bold tracking-tight mb-3" style={{ color: "var(--l-text)" }}>{title}</h2>
      )}
      <div className="text-[15px] leading-[1.75] space-y-3" style={{ color: "var(--l-muted)" }}>
        {children}
      </div>
    </section>
  );
}

export const CONTACT_EMAIL = "hello@gimmelist.com";
