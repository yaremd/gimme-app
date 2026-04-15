import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Page not found — Gimme",
};

export default function NotFound() {
  return (
    <main className="landing min-h-[100dvh] flex items-center justify-center px-6">
      <div className="text-center max-w-sm l-anim">
        <div className="w-20 h-20 rounded-[1.5rem] flex items-center justify-center mx-auto mb-6"
          style={{ background: "var(--l-accent-soft)", color: "var(--l-accent)" }}>
          <svg width="32" height="32" viewBox="0 0 32 32" fill="none">
            <path d="M16 6v12M16 22v2" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
          </svg>
        </div>
        <h1 className="text-3xl font-bold tracking-tight mb-3" style={{ color: "var(--l-text)" }}>
          Page not found
        </h1>
        <p className="text-base leading-relaxed mb-8" style={{ color: "var(--l-muted)" }}>
          The page you&apos;re looking for doesn&apos;t exist or has been moved.
        </p>
        <a
          href="/"
          className="inline-flex items-center gap-2 rounded-full px-6 py-3 text-sm font-semibold l-cta no-underline"
        >
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M10 7H4M4 7L7 4M4 7L7 10" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round"/></svg>
          Back to Gimme
        </a>
      </div>
    </main>
  );
}
