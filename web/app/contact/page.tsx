import type { Metadata } from "next";
import { LegalLayout, LegalSection, CONTACT_EMAIL } from "@/components/LegalLayout";

export const metadata: Metadata = {
  title: "Contact — Gimme",
  description: "Get in touch with the Gimme team.",
};

export default function ContactPage() {
  return (
    <LegalLayout
      eyebrow="Contact"
      title="Get in touch"
      subtitle="We'd love to hear from you."
    >
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-14">
        <ContactCard
          icon={<svg width="20" height="20" viewBox="0 0 20 20" fill="none"><rect x="2" y="4" width="16" height="12" rx="2" stroke="currentColor" strokeWidth="1.2"/><path d="M2 6l8 5 8-5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round"/></svg>}
          title="Email"
          description="For bugs, features, or questions"
          action={CONTACT_EMAIL}
          href={`mailto:${CONTACT_EMAIL}`}
        />
        <ContactCard
          icon={<svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M10 18c4.418 0 8-3.582 8-8s-3.582-8-8-8-8 3.582-8 8 3.582 8 8 8z" stroke="currentColor" strokeWidth="1.2"/><path d="M7 10h6M10 7v6" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round"/></svg>}
          title="Feature requests"
          description="Suggest what to build next"
          action={CONTACT_EMAIL}
          href={`mailto:${CONTACT_EMAIL}?subject=Feature%20Request`}
        />
      </div>

      <LegalSection title="Response time">
        <p>
          We typically respond within 24 hours. For urgent issues (data loss, account
          access), please include &ldquo;Urgent&rdquo; in your subject line.
        </p>
      </LegalSection>

      <LegalSection title="Before you write">
        <p>
          Check our{" "}
          <a href="/support" style={{ color: "var(--l-accent)" }} className="hover:underline">
            Support &amp; FAQ page
          </a>{" "}
          &mdash; your question may already be answered there.
        </p>
      </LegalSection>

      <LegalSection title="Helpful details to include">
        <ul className="list-disc list-inside space-y-1.5 pl-1">
          <li>Your device model and iOS version</li>
          <li>Steps to reproduce the issue</li>
          <li>Screenshots if applicable</li>
          <li>Whether you&apos;re using Free or Pro</li>
        </ul>
      </LegalSection>
    </LegalLayout>
  );
}

function ContactCard({
  icon,
  title,
  description,
  action,
  href,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
  action: string;
  href: string;
}) {
  return (
    <a
      href={href}
      className="doppel-outer no-underline block group"
      style={{ color: "var(--l-text)" }}
    >
      <div className="doppel-inner p-6 transition-all duration-700" style={{ transitionTimingFunction: "var(--l-ease)" }}>
        <div className="w-10 h-10 rounded-xl flex items-center justify-center mb-4"
          style={{ background: "var(--l-accent-soft)", color: "var(--l-accent)" }}>
          {icon}
        </div>
        <h3 className="text-[15px] font-semibold mb-1">{title}</h3>
        <p className="text-sm mb-3" style={{ color: "var(--l-muted)" }}>{description}</p>
        <span className="text-sm font-medium" style={{ color: "var(--l-accent)" }}>{action}</span>
      </div>
    </a>
  );
}
