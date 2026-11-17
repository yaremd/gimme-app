import Link from "next/link";
import { Icon } from "@/app/_site/brand";
import { pageMeta } from "@/app/_site/meta";
import { LegalLayout, LegalSection, CONTACT_EMAIL } from "@/components/LegalLayout";

export const metadata = pageMeta({
  title: "Contact — Gimme",
  description: "Get in touch with the Gimme team.",
  path: "/contact",
});

export default function ContactPage() {
  return (
    <LegalLayout eyebrow="Contact" title="Get in touch" subtitle="We'd love to hear from you.">
      <div className="g-cards">
        <ContactCard
          icon="mail"
          title="Email"
          description="For bugs, features, or questions"
          action={CONTACT_EMAIL}
          href={`mailto:${CONTACT_EMAIL}`}
        />
        <ContactCard
          icon="lightbulb"
          title="Feature requests"
          description="Suggest what to build next"
          action={CONTACT_EMAIL}
          href={`mailto:${CONTACT_EMAIL}?subject=Feature%20Request`}
        />
      </div>

      <LegalSection title="Response time">
        <p>
          We typically respond within 24 hours. For urgent issues (data loss, account access), please include
          &ldquo;Urgent&rdquo; in your subject line.
        </p>
      </LegalSection>

      <LegalSection title="Before you write">
        <p>
          Check our <Link href="/support">Support &amp; FAQ page</Link> &mdash; your question may already be answered
          there.
        </p>
      </LegalSection>

      <LegalSection title="Helpful details to include">
        <ul>
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
  icon: "mail" | "lightbulb";
  title: string;
  description: string;
  action: string;
  href: string;
}) {
  return (
    <a href={href} className="g-cardlink">
      <span className="g-cardlink__ic">
        <Icon name={icon} />
      </span>
      <b>{title}</b>
      <small>{description}</small>
      <span>{action}</span>
    </a>
  );
}
