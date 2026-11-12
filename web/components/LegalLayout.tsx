import { HandUnderline } from "@/app/_site/brand";
import { Sky, SiteFooter, SiteNav } from "@/app/_site/chrome";
import { Reveal } from "@/app/_site/reveal";

export const CONTACT_EMAIL = "hello@gimmelist.com";

/** The frame for the text pages: support, contact, privacy and terms. */
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
  // the hand-drawn underline goes under the last word of the title
  const cut = title.lastIndexOf(" ");
  const lead = cut === -1 ? "" : title.slice(0, cut + 1);
  const last = cut === -1 ? title : title.slice(cut + 1);

  return (
    <>
      <Sky />
      <SiteNav />
      <main id="main" className="g-page">
        <div className="g-page__glow" aria-hidden="true" />
        <div className="g-page__in">
          <Reveal as="header" className="g-page__head">
            <p className="g-eyebrow">{eyebrow}</p>
            <h1 className="g-page__title">
              {lead}
              <span className="g-under">
                {last}
                <HandUnderline />
              </span>
            </h1>
            {subtitle && <p className="g-page__sub">{subtitle}</p>}
          </Reveal>
          <div className="g-doc">{children}</div>
        </div>
      </main>
      <SiteFooter />
    </>
  );
}

/** One titled block of text. */
export function LegalSection({ title, children }: { title?: string; children: React.ReactNode }) {
  return (
    <section className="g-doc__sec">
      {title && <h2>{title}</h2>}
      <div className="g-doc__body">{children}</div>
    </section>
  );
}
