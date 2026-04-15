import type { Metadata } from "next";
import { LegalLayout, LegalSection, CONTACT_EMAIL } from "@/components/LegalLayout";

export const metadata: Metadata = {
  title: "Terms of Use — Gimme",
  description: "Terms of Use for the Gimme wishlist app.",
};

const LAST_UPDATED = "April 13, 2026";

export default function TermsPage() {
  return (
    <LegalLayout
      eyebrow="Legal"
      title="Terms of Use"
      subtitle={`Last updated: ${LAST_UPDATED}`}
    >
      <LegalSection>
        <p>
          These Terms of Use (&ldquo;Terms&rdquo;) govern your use of the Gimme mobile
          application and website at gimmelist.com (collectively, &ldquo;the Service&rdquo;),
          operated by Dmytro Yaremchuk (&ldquo;we&rdquo;, &ldquo;us&rdquo;, &ldquo;our&rdquo;).
        </p>
        <p>
          By downloading, installing, or using the Service, you agree to these Terms.
          If you do not agree, please do not use the Service.
        </p>
      </LegalSection>

      <LegalSection title="1. The Service">
        <p>
          Gimme is a personal wishlist management app that allows you to save, organize,
          and share wishlists. The Service is provided &ldquo;as is&rdquo; and
          &ldquo;as available&rdquo; without warranties of any kind.
        </p>
      </LegalSection>

      <LegalSection title="2. Accounts">
        <p>
          You may use the App without creating an account (local-only mode). If you
          create an account, you are responsible for maintaining the security of your
          credentials. You must provide accurate information and notify us promptly
          of any unauthorized use.
        </p>
      </LegalSection>

      <LegalSection title="3. Acceptable Use">
        <p>You agree not to:</p>
        <ul className="list-disc list-inside space-y-1.5 pl-1">
          <li>Use the Service for any illegal purpose</li>
          <li>Upload harmful, offensive, or infringing content</li>
          <li>Attempt to access other users&apos; data without authorization</li>
          <li>Reverse engineer, decompile, or disassemble the App</li>
          <li>Use automated tools to scrape or collect data from the Service</li>
          <li>Interfere with the Service&apos;s infrastructure or availability</li>
        </ul>
      </LegalSection>

      <LegalSection title="4. Shared Wishlists">
        <p>
          When you share a wishlist via a public link, the list name, items, prices,
          and images become visible to anyone with that link. You are responsible for
          the content you share. We reserve the right to remove shared content that
          violates these Terms.
        </p>
        <p>
          Friends who claim items on your shared list provide their name voluntarily.
          You should not use this information for purposes other than gift coordination.
        </p>
      </LegalSection>

      <LegalSection title="5. In-App Purchases">
        <p>
          Gimme Pro is available as a one-time, non-consumable in-app purchase processed
          by Apple. All purchases are subject to Apple&apos;s{" "}
          <a href="https://www.apple.com/legal/internet-services/itunes/" target="_blank"
            rel="noopener noreferrer" style={{ color: "var(--l-accent)" }} className="hover:underline">
            App Store Terms
          </a>. Refunds are handled by Apple, not by us.
        </p>
      </LegalSection>

      <LegalSection title="6. Intellectual Property">
        <p>
          The Service, including its design, code, graphics, and branding, is owned by
          Dmytro Yaremchuk and protected by copyright and intellectual property laws.
          You may not copy, modify, or distribute any part of the Service without permission.
        </p>
        <p>
          Content you create within the App (wishlist names, notes, etc.) remains yours.
          By using the sync feature, you grant us a limited license to store and transmit
          your content solely for the purpose of providing the Service.
        </p>
      </LegalSection>

      <LegalSection title="7. Termination">
        <p>
          You may stop using the Service at any time by deleting the App and, if applicable,
          requesting account deletion. We may suspend or terminate your access if you violate
          these Terms, with or without notice.
        </p>
      </LegalSection>

      <LegalSection title="8. Limitation of Liability">
        <p>
          To the maximum extent permitted by law, we shall not be liable for any indirect,
          incidental, special, consequential, or punitive damages arising from your use
          of the Service. Our total liability shall not exceed the amount you paid for
          Gimme Pro.
        </p>
      </LegalSection>

      <LegalSection title="9. Disclaimer">
        <p>
          The Service is provided without warranties of any kind, whether express or implied,
          including merchantability, fitness for a particular purpose, and non-infringement.
          We do not guarantee that the Service will be uninterrupted, error-free, or secure.
        </p>
      </LegalSection>

      <LegalSection title="10. Changes to Terms">
        <p>
          We may update these Terms from time to time. The updated version will be posted
          here with a new date. Continued use after changes constitutes acceptance of the
          revised Terms.
        </p>
      </LegalSection>

      <LegalSection title="11. Governing Law">
        <p>
          These Terms are governed by the laws of Ukraine, without regard to conflict of
          law provisions. Any disputes shall be resolved in the courts of Ukraine.
        </p>
      </LegalSection>

      <LegalSection title="12. Contact">
        <p>
          Questions about these Terms? Email us at{" "}
          <a href={`mailto:${CONTACT_EMAIL}`} style={{ color: "var(--l-accent)" }} className="hover:underline">
            {CONTACT_EMAIL}
          </a>
        </p>
      </LegalSection>
    </LegalLayout>
  );
}
