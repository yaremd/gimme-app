import Link from "next/link";
import { pageMeta } from "@/app/_site/meta";
import { LegalLayout, LegalSection, CONTACT_EMAIL } from "@/components/LegalLayout";

export const metadata = pageMeta({
  title: "Support — Gimme",
  description: "Get help with the Gimme wishlist app.",
  path: "/support",
});

export default function SupportPage() {
  return (
    <LegalLayout eyebrow="Support" title="Help &amp; Support" subtitle="Got a question? We're here to help.">
      <LegalSection title="Contact Us">
        <p>
          For bug reports, feature requests, or any questions about Gimme, email us at{" "}
          <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>
        </p>
        <p>We typically respond within 24 hours.</p>
      </LegalSection>

      <LegalSection title="Frequently Asked Questions">
        <div className="g-qa">
          <FAQ question="How do I share a wishlist?">
            Open any list, tap the share icon in the top right, and copy the link. Anyone with the link can view your
            list and claim items directly in their browser &mdash; no app download or account required.
          </FAQ>

          <FAQ question="How do I sync my wishlists across devices?">
            Go to Settings and sign in with your email or Apple ID. Once signed in, all your lists and items sync
            automatically across your devices.
          </FAQ>

          <FAQ question="How do I restore my Gimme Pro purchase?">
            If you reinstall the app or switch devices, go to Settings. Your Pro purchase will be restored
            automatically. If it doesn&apos;t appear, tap &ldquo;Restore Purchases&rdquo; on the upgrade screen.
          </FAQ>

          <FAQ question="How do I add Home Screen widgets?">
            Long-press on your Home Screen, tap the &ldquo;+&rdquo; button in the top left, search for
            &ldquo;Gimme&rdquo;, and choose from small, medium, or Lock Screen widgets.
          </FAQ>

          <FAQ question="How do I use the Share Extension?">
            While browsing in Safari or any app, tap the Share button and select &ldquo;Save to Gimme&rdquo;. The
            product name, image, and price will be extracted automatically.
          </FAQ>

          <FAQ question="How do I use Siri with Gimme?">
            Gimme includes 5 Siri Shortcuts. Open the Shortcuts app to find them, or say &ldquo;Hey Siri, add wish in
            Gimme&rdquo; or &ldquo;Hey Siri, wishlist total in Gimme&rdquo;.
          </FAQ>

          <FAQ question="How do I delete my account?">
            Go to Settings &rarr; Delete Account. This removes all your data from our servers. You can also email{" "}
            <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> and we&apos;ll process deletion within 30 days.
          </FAQ>

          <FAQ question="Is my data safe?">
            Yes. The App works fully offline with no tracking SDKs. If you sync, your data is protected by Row Level
            Security and stored in the EU. See our <Link href="/privacy">Privacy Policy</Link> for details.
          </FAQ>
        </div>
      </LegalSection>

      <LegalSection title="App Information">
        <dl className="g-facts">
          <dt>App</dt>
          <dd>Gimme &mdash; Wishlist &amp; Gift Ideas</dd>
          <dt>Developer</dt>
          <dd>Dmytro Yaremchuk</dd>
          <dt>Requires</dt>
          <dd>iOS 17.0 or later</dd>
        </dl>
        <p>
          <Link href="/privacy">Privacy Policy</Link> &middot; <Link href="/terms">Terms of Use</Link>
        </p>
      </LegalSection>
    </LegalLayout>
  );
}

function FAQ({ question, children }: { question: string; children: React.ReactNode }) {
  return (
    <div>
      <h3>{question}</h3>
      <p>{children}</p>
    </div>
  );
}
