import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Case Study — Gimme Wishlist & Gifting App",
  description:
    "From personal frustration to production iOS app. The story of how design decisions became engineering decisions.",
  openGraph: {
    title: "Case Study — Gimme Wishlist & Gifting App",
    description:
      "From personal frustration to production iOS app. The story of how design decisions became engineering decisions.",
    type: "article",
  },
  twitter: {
    card: "summary_large_image",
    title: "Case Study — Gimme Wishlist & Gifting App",
    description:
      "From personal frustration to production iOS app. The story of how design decisions became engineering decisions.",
  },
};

/* ─────────────────────────────────────────────
   Page
───────────────────────────────────────────── */
export default function CaseStudy() {
  return (
    <main className="landing min-h-[100dvh] overflow-x-hidden">
      {/* ── Nav ── */}
      <nav className="max-w-[1400px] mx-auto px-4 md:px-12 pt-5 l-anim">
        <div
          className="w-full flex items-center justify-between rounded-full px-5 py-3 bg-white/60 border border-[#18181B]/[0.04] shadow-[0_2px_12px_rgba(24,24,27,0.04)]"
          style={{ backdropFilter: "blur(12px)", WebkitBackdropFilter: "blur(12px)" }}
        >
          <Link
            href="/"
            className="flex items-center gap-2.5 no-underline"
            style={{ color: "var(--l-text)" }}
          >
            <img src="/app-icon.png" alt="Gimme" width={28} height={28} className="rounded-lg" />
            <span className="text-[15px] font-semibold tracking-tight">Gimme</span>
          </Link>
          <Link
            href="/"
            className="text-sm font-medium no-underline hover:opacity-60 transition-opacity flex items-center gap-1.5"
            style={{ color: "var(--l-muted)" }}
          >
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
              <path d="M9 2L4 7l5 5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            Back
          </Link>
        </div>
      </nav>

      {/* ── Hero ── */}
      <header className="max-w-[760px] mx-auto px-6 md:px-8 pt-20 md:pt-32 pb-0">
        <div className="l-anim l-d1 mb-6">
          <span className="l-eyebrow">Case Study</span>
        </div>
        <h1 className="text-[clamp(2.4rem,6vw,4rem)] font-bold tracking-[-0.04em] leading-[1.03] mb-6 l-anim l-d2">
          Gimme &mdash; Wishlist<br />& Gifting App
        </h1>
        <p
          className="text-lg md:text-xl leading-[1.75] max-w-[560px] mb-10 l-anim l-d3"
          style={{ color: "var(--l-muted)" }}
        >
          From personal frustration to production iOS app. The story of how
          design decisions became engineering decisions.
        </p>

        {/* Metadata chips */}
        <div className="flex flex-wrap gap-2 mb-12 l-anim l-d4">
          <MetaChip label="Role" value="UX · iOS · AI Systems" />
          <MetaChip label="Platform" value="iOS 17 · Web · Supabase" />
          <MetaChip label="Stack" value="Swift 6 · Next.js 15 · Vercel" />
          <MetaChip label="Status" value="Production-ready" />
        </div>

        {/* Stats strip */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-16 l-anim l-d5">
          <StatCard n="67" label="Swift source files" />
          <StatCard n="15" label="Production features" />
          <StatCard n="$4.99" label="Lifetime Pro price" />
          <StatCard n="0" label="Accounts for gifters" />
        </div>
      </header>

      {/* ── Article body ── */}
      <div
        className="max-w-[760px] mx-auto px-6 md:px-8 border-t pb-8"
        style={{ borderColor: "var(--l-border)" }}
      >
        {/* 01 */}
        <Section number="01" eyebrow="Origin" title="The Problem">
          <Lede>
            Every time I saw something I liked &mdash; scrolling through Instagram, browsing a random store, reading a newsletter &mdash; I had no good place to put it.
          </Lede>
          <P>
            The origin story of Gimme is a personal frustration with three distinct failure modes that no existing tool addressed together.
          </P>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-3 my-8">
            <DarkCard n="01" title="Discovery is lost">
              Notes app graveyards. Screenshot folders with no context. Bookmarks forgotten.
              No frictionless way to capture a wish without leaving your current app.
            </DarkCard>
            <DarkCard n="02" title="Sharing is awkward">
              When someone asks what you want &mdash; you blank out, or send one link.
              No living, shareable place with priority and context.
            </DarkCard>
            <DarkCard n="03" title="Gifting is broken">
              Perfect gift idea saved in a random note, forgotten by December.
              Duplicate gifts, missed wishes, no coordination.
            </DarkCard>
          </div>

          <P>Existing tools all broke in specific ways:</P>

          <DataTable
            headers={["Tool", "Where it broke"]}
            rows={[
              ["Amazon Wish List", "Locked to one retailer"],
              ["Pinterest", "Inspiration boards, not purchase intent"],
              ["iOS Reminders", "Too generic, no product context"],
              ["Giftster / Elfster", "Cluttered UI, no smart capture"],
              ["Notes app", "A graveyard — nothing ever acted on"],
            ]}
          />

          <Callout>
            None solved all three failure modes. None combined frictionless capture,
            rich product context, and a social coordination layer.
          </Callout>
        </Section>

        {/* 02 */}
        <Section number="02" eyebrow="Research" title="Discovery">
          <P>Before building, I mapped the problem space across three dimensions:</P>

          <ol className="space-y-6 my-8 pl-0 list-none">
            {[
              {
                heading: "Behavioral mapping",
                body: "70% of item discovery happens on mobile, inside another app. The gap between \u201cI want this\u201d and opening a dedicated app is where saves die. Context is critical \u2014 why I saved something matters as much as what.",
              },
              {
                heading: "Competitive audit",
                body: "6 tools evaluated. The consistent gap: every tool made saving feel like work, and none had social infrastructure for gift coordination.",
              },
              {
                heading: "Platform capability audit",
                body: "Share Extension, WidgetKit, Siri Shortcuts, Spotlight, Universal Links, Realtime push — capabilities no web app can replicate at the same quality level.",
              },
              {
                heading: "The social contract of gifting",
                body: "The awkwardness of knowing what someone got you. The etiquette of claiming. The problem of duplicates. The desire for surprise to be preserved.",
              },
            ].map((item, i) => (
              <li key={i} className="flex gap-5 items-start">
                <span
                  className="text-xs font-bold tabular-nums pt-0.5 shrink-0 w-5"
                  style={{ color: "var(--l-accent)", opacity: 0.5 }}
                >
                  {String(i + 1).padStart(2, "0")}
                </span>
                <div>
                  <p className="text-[15px] font-semibold mb-1">{item.heading}</p>
                  <p className="text-sm leading-relaxed" style={{ color: "var(--l-muted)" }}>{item.body}</p>
                </div>
              </li>
            ))}
          </ol>

          <Callout>
            The problem wasn&apos;t a missing database. It was capture friction and zero social
            infrastructure. Every existing tool treated saving as the product. The real product
            is the moment of discovery and the moment of gifting.
          </Callout>
        </Section>

        {/* 03 */}
        <Section number="03" eyebrow="Framing" title="Problem Definition">
          <PullQuote>
            Build the simplest possible path from &ldquo;I want this&rdquo; to &ldquo;someone got it for me&rdquo; &mdash;
            and from &ldquo;I want to give them something good&rdquo; to &ldquo;I got the right thing without
            duplicating anyone else.&rdquo;
          </PullQuote>

          <P>This framing produced three non-negotiable design principles:</P>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-3 my-8">
            <DarkCard n="1" title="Zero-friction capture">
              Saving an item should never require leaving the app you&apos;re in.
              Under 10 seconds from discovery to saved.
            </DarkCard>
            <DarkCard n="2" title="Rich by default">
              When you save a link, the app does the work. Title, image, price,
              currency — extracted automatically. The user is not a data entry clerk.
            </DarkCard>
            <DarkCard n="3" title="Invisible coordination">
              Gifters should see and claim gifts without creating accounts.
              The social layer should feel effortless.
            </DarkCard>
          </div>
        </Section>

        {/* 04 */}
        <Section number="04" eyebrow="Structure" title="Information Architecture">
          <P>
            The core hierarchy is deliberate: <strong>Lists → Items</strong>. But the
            structure decisions were not obvious.
          </P>

          <dl className="my-8 space-y-0 divide-y" style={{ borderColor: "var(--l-border)" }}>
            {[
              {
                term: "Why multiple lists, not one",
                body: '"Birthday," "Home," "Tech," "For Mom" — context is everything. A flat list collapses intent.',
              },
              {
                term: "Why the list is the unit of sharing",
                body: "You share occasions, not individual items. Sharing a list maps to how gifting actually works.",
              },
              {
                term: "Why priority is a first-class field",
                body: "High / Medium / Low tells a gifter what matters most. A flat list communicates nothing about intent.",
              },
              {
                term: "Navigation philosophy",
                body: "Flat, sheet-based. One deep push: Home → List → Item. No tab bars. Everything within two taps.",
              },
            ].map((d) => (
              <div key={d.term} className="py-5 grid grid-cols-1 md:grid-cols-5 gap-2 md:gap-6">
                <dt
                  className="text-[13px] font-semibold md:col-span-2 pt-0.5"
                  style={{ color: "var(--l-accent)" }}
                >
                  {d.term}
                </dt>
                <dd
                  className="text-sm leading-relaxed md:col-span-3 m-0"
                  style={{ color: "var(--l-muted)" }}
                >
                  {d.body}
                </dd>
              </div>
            ))}
          </dl>

          <P>The three-state item model resolves the gift-surprise problem:</P>
          <DataTable
            headers={["State", "Meaning"]}
            rows={[
              ["Wanted", "Default — on your wishlist"],
              ["Purchased", "You bought it yourself"],
              ["Reserved by friend", "Someone is getting it for you — you see the name, not the item"],
            ]}
          />
        </Section>

        {/* 05 */}
        <Section number="05" eyebrow="Key Innovation" title="The Capture Problem">
          <Lede>The most important UX decision in the project.</Lede>

          <P>
            The fundamental insight:{" "}
            <strong>the moment of discovery happens in another app.</strong> If saving
            requires switching to Gimme and manually pasting a URL, most saves will never happen.
          </P>

          <H3>Solution 1 — iOS Share Extension</H3>
          <P>
            &ldquo;Save to Gimme&rdquo; appears in any app&apos;s share sheet. One tap. URL handed off, app
            opens pre-filled. This required a separate app extension target (GimmeShare) sharing
            data via App Groups — the main app detects a pending URL on foreground activation and
            opens Add Item pre-filled.
          </P>
          <P style={{ color: "var(--l-muted)" }}>
            The UX payoff: the user never leaves the context they&apos;re in. Safari, Instagram,
            Amazon — the save mechanism is identical everywhere.
          </P>

          <H3>Solution 2 — The Metadata Extraction Pipeline</H3>
          <P>
            Once a URL arrives, the user shouldn&apos;t type anything. This is the{" "}
            <strong>AI engineering layer</strong> of the project — an intelligent multi-strategy
            parsing system that produces structured product data from unstructured HTML.
          </P>

          <DataTable
            headers={["Strategy", "Why"]}
            rows={[
              ["JSON-LD structured data", "Most reliable — used by major retailers (ASOS, IKEA, Apple)"],
              ["Open Graph meta tags", "Universal fallback — supported by most modern sites"],
              ["Microdata", "Schema.org product markup"],
              ["HTML selector heuristics", "Last resort — targets common class/ID patterns"],
            ]}
          />

          <P className="mt-7">What gets extracted automatically:</P>
          <ul className="mt-3 mb-8 space-y-2 pl-0 list-none">
            {[
              "Product title and description",
              "Images — scored and ranked, not just the first one found",
              "Price and currency (ISO code)",
              "Product variants: color, size from URL params + structured data",
              "Brand name",
            ].map((item) => (
              <CheckItem key={item} text={item} />
            ))}
          </ul>

          <Callout>
            Saving from ASOS, Apple, IKEA, Etsy, or any random shop all feel identical to the
            user — instant, rich, effortless. The complexity is entirely hidden. That invisibility
            is the design success.
          </Callout>
        </Section>

        {/* 06 */}
        <Section number="06" eyebrow="Social Design" title="The Social Layer">
          <Lede>The hardest design problem: gift coordination without accounts.</Lede>

          <P>
            Asking a friend to create an account to see your wishlist kills the sharing loop
            instantly. This was a non-negotiable constraint.
          </P>

          <ol className="my-8 space-y-3 pl-0 list-none">
            {[
              "Each list generates an encrypted share token",
              "Token produces a public URL on a Next.js / Vercel web app",
              "Anyone with the link views items and claims them — name only, no account required",
              "Claiming triggers a Supabase Realtime update + push notification to the list owner",
              "Owner sees \u201creserved by [name]\u201d — but not which item (preserves surprise)",
              "Supabase RPC functions handle atomic claim / unclaim operations",
            ].map((step, i) => (
              <li key={i} className="flex gap-4 items-start">
                <span
                  className="w-6 h-6 rounded-full flex items-center justify-center text-[11px] font-bold shrink-0 mt-0.5"
                  style={{ background: "var(--l-accent-soft)", color: "var(--l-accent)" }}
                >
                  {i + 1}
                </span>
                <p className="text-sm leading-relaxed" style={{ color: "var(--l-muted)" }}>{step}</p>
              </li>
            ))}
          </ol>

          <PullQuote>
            The design surfaces &ldquo;someone claimed something&rdquo; &mdash; without &ldquo;someone claimed the
            AirPods.&rdquo; Coordination without spoiling the surprise.
          </PullQuote>

          <P>
            The web share page generates dynamic OG images per list (1200&times;630) — rich
            previews in iMessage, Slack, and Twitter. Universal Links mean the share URL opens
            directly in the app if installed. No friction for returning users.
          </P>
        </Section>

        {/* 07 */}
        <Section number="07" eyebrow="Platform" title="Ambient Access">
          <P>
            A wishlist that only exists behind an app icon has weak recall. Gimme extends its
            presence to where the user already looks.
          </P>

          <DataTable
            headers={["Surface", "What it shows"]}
            rows={[
              ["Lock Screen widget", "Top-priority item, visible without unlocking"],
              ["Small home screen widget", "Quick glance at most urgent wish"],
              ["Medium home screen widget", "List overview with top 3 items"],
              ["Siri — \u201cWhat\u2019s on my birthday list?\u201d", "Voice readout of current list"],
              ["Siri — \u201cAdd AirPods to my tech list\u201d", "Voice capture without opening the app"],
              ["Siri — \u201cHow much is left?\u201d", "Total remaining value, spoken aloud"],
              ["Spotlight Search", "Every list and item indexed — find anything from iOS search"],
            ]}
          />

          <Callout>
            Widgets and Siri make the wishlist ambient. Passive visibility reinforces that the
            list is alive — creating a habit loop without requiring deliberate app opens.
          </Callout>
        </Section>

        {/* 08 */}
        <Section number="08" eyebrow="Visual Language" title="Design System">
          <P>
            Built code-first in{" "}
            <code
              className="text-[13px] font-mono px-1.5 py-0.5 rounded-md"
              style={{ background: "var(--l-surface)", color: "var(--l-text)" }}
            >
              Theme.swift
            </code>
            , not designed in Figma first. Every token is intentional.
          </P>

          <dl className="my-8 space-y-0 divide-y" style={{ borderColor: "var(--l-border)" }}>
            {[
              {
                term: "SF Pro Rounded",
                body: "Warmer than default SF Pro. Creates a personal, less utilitarian feel for something that is about wants and wishes.",
              },
              {
                term: "Accent color #6C63FF",
                body: "Soft purple — aspirational without being aggressive. Associated with desire, creativity, premium. Consistent across iOS and web.",
              },
              {
                term: "10 preset list colors",
                body: "Personalization that is fast and foolproof. No free-form color picker = no bad color choices.",
              },
              {
                term: "Spring physics animations",
                body: "All state transitions feel physical. Matched geometry on the emoji/color picker overlays creates spatial continuity — never teleporting.",
              },
              {
                term: "WCAG enforcement in code",
                body: "3:1 for glows, 4.5:1 for text. Accessibility checked at the design-system level, not audited after the fact.",
              },
            ].map((d) => (
              <div key={d.term} className="py-5 grid grid-cols-1 md:grid-cols-5 gap-2 md:gap-6">
                <dt
                  className="text-[13px] font-semibold md:col-span-2 pt-0.5"
                  style={{ color: "var(--l-accent)" }}
                >
                  {d.term}
                </dt>
                <dd
                  className="text-sm leading-relaxed md:col-span-3 m-0"
                  style={{ color: "var(--l-muted)" }}
                >
                  {d.body}
                </dd>
              </div>
            ))}
          </dl>

          <div className="grid grid-cols-2 gap-4 my-8">
            <DataTable
              caption="Spacing tokens"
              headers={["Token", "Value"]}
              rows={[["xs", "4pt"], ["sm", "8pt"], ["md", "12pt"], ["lg", "16pt"], ["xl", "24pt"]]}
            />
            <DataTable
              caption="Corner radii"
              headers={["Surface", "Radius"]}
              rows={[["Card", "20pt"], ["Sheet", "28pt"], ["Button", "14pt"], ["Badge", "8pt"]]}
            />
          </div>
        </Section>

        {/* 09 */}
        <Section number="09" eyebrow="Business" title="Monetization Design">
          <P>The free tier is deliberately generous — a strategic product decision, not a constraint.</P>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 my-8">
            <div className="doppel-outer">
              <div className="doppel-inner p-6 md:p-8">
                <p className="text-sm font-semibold mb-1" style={{ color: "var(--l-muted)" }}>
                  Free
                </p>
                <p className="text-3xl font-bold tracking-[-0.03em] mb-6">$0</p>
                <ul className="space-y-2.5">
                  {["Unlimited lists and items", "Cloud sync", "2 shared lists", "Widgets", "Siri Shortcuts"].map(
                    (f) => <PricingRow key={f} text={f} />
                  )}
                </ul>
              </div>
            </div>
            <div className="doppel-outer-dark">
              <div className="doppel-inner-dark p-6 md:p-8 relative overflow-hidden">
                <div className="absolute top-4 right-4 text-[10px] font-semibold uppercase tracking-[0.15em] rounded-full px-2.5 py-1 bg-white/10 border border-white/[0.06]">
                  Lifetime
                </div>
                <p className="text-sm font-semibold mb-1 text-white/50">Gimme Pro</p>
                <p className="text-3xl font-bold tracking-[-0.03em] mb-6">$4.99</p>
                <ul className="space-y-2.5">
                  {["Everything in Free", "Unlimited shared lists", "Stats dashboard", "All future features"].map(
                    (f) => <PricingRow key={f} text={f} light />
                  )}
                </ul>
              </div>
            </div>
          </div>

          <dl className="space-y-0 divide-y" style={{ borderColor: "var(--l-border)" }}>
            <div className="py-5">
              <dt className="text-[13px] font-semibold mb-1.5">Why cap at 2 shared lists, not 0</dt>
              <dd className="text-sm leading-relaxed m-0" style={{ color: "var(--l-muted)" }}>
                Sharing is the viral acquisition mechanic. Every shared list is a public landing page seen by people who don&apos;t have the app. Capping after the value is felt — not before — converts users, it doesn&apos;t frustrate them.
              </dd>
            </div>
            <div className="py-5">
              <dt className="text-[13px] font-semibold mb-1.5">Why lifetime, not subscription</dt>
              <dd className="text-sm leading-relaxed m-0" style={{ color: "var(--l-muted)" }}>
                For a utility app, recurring charges feel disproportionate. A single purchase builds trust and removes the reason to delete the app when a subscription tier feels underused.
              </dd>
            </div>
          </dl>
        </Section>

        {/* 10 */}
        <Section number="10" eyebrow="Engineering" title="Technical Architecture as UX">
          <Lede>Every major technical decision was made in service of the user experience.</Lede>

          <DataTable
            headers={["Technical Decision", "UX Outcome"]}
            rows={[
              ["SwiftData + local-first", "App is instant. Works offline. No loading spinners for your own data."],
              ["Supabase Realtime", "Friend claims appear live on share page — no refresh needed"],
              ["App Groups (Share Extension ↔ App)", "Save from any app without the user noticing a handoff"],
              ["Edge Functions for push", "Friend claims trigger instant notification — closes the feedback loop"],
              ["Vercel OG image generation", "Share links have rich previews in iMessage, Twitter, Slack"],
              ["Universal Links (AASA)", "Share links open directly in the app if installed"],
              ["StoreKit 2", "Purchase is 2 taps, receipt-backed, auto-restored"],
              ["30s sync throttle", "Sync is silent and automatic — user never thinks about it"],
              ["Background ModelContext", "Sync never blocks the UI thread"],
              ["PKCE + SHA256 nonce", "Apple Sign In is secure by default, not bolted on"],
            ]}
          />
        </Section>

        {/* 11 */}
        <Section number="11" eyebrow="Scope" title="What&apos;s Built">
          <P>All of the following is production-grade and fully implemented:</P>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-2 my-8">
            {[
              "Multi-list management — emoji, color, pin, archive",
              "Rich item capture — URL, image, price, priority",
              "Metadata extraction — auto-fill from any URL",
              "Cloud sync — bidirectional, offline-first",
              "Social sharing — public links, friend claiming",
              "Push notifications — APNs via Edge Function",
              "Widgets — small, medium, lock screen",
              "Siri Shortcuts — 5 intents",
              "Spotlight Search — every list and item indexed",
              "Share Extension — one tap from any app",
              "Stats dashboard — donut chart, 9 currencies",
              "Auth — Apple Sign In + email, guest mode",
              "StoreKit 2 — lifetime Pro purchase",
              "Onboarding — 3-page animated tutorial",
              "Web — marketing site + dynamic share pages",
              "Design system — tokens, dark/light, WCAG",
            ].map((f) => (
              <CheckItem key={f} text={f} />
            ))}
          </div>
        </Section>

        {/* 12 */}
        <Section number="12" eyebrow="Roadmap" title="What&apos;s Next">
          <DataTable
            headers={["Priority", "Feature", "Strategic Reason"]}
            rows={[
              ["P1", "Web share page polish", "#1 viral acquisition surface — every list is a public landing page"],
              ["P2", "Smart Event Engine", "Proactive birthday/occasion reminders — turns app from reactive to proactive"],
              ["P3", "In-list sections & tags", "Power user organization"],
              ["P3", "Split-the-gift contributions", "Group gifting without Venmo spreadsheets"],
              ["P4", "Price drop tracking (Pro)", "Creates daily app opens, justifies Pro upgrade"],
            ]}
          />
        </Section>

        {/* 13 */}
        <Section number="13" eyebrow="Reflection" title="Key Learnings">
          <div className="space-y-4 my-8">
            <LearningCard title="Engineering is design">
              The Share Extension, the metadata pipeline, the Realtime claims, the local-first sync — none
              of these are visible in the UI. All of them are felt in the experience. The best UX decisions
              in this project were technical decisions.
            </LearningCard>
            <LearningCard title="Graceful degradation as design principle">
              The metadata pipeline is the most technically complex part of the product and the least visible.
              That invisibility is the design success. When the intelligence works, the user sees a perfect
              card. When it doesn&apos;t, they fill in an empty field. Both outcomes are acceptable.
            </LearningCard>
            <LearningCard title="Remove every barrier from the social loop">
              Removing account creation from the gifter flow was the single highest-leverage decision for
              shareability. The product only works if the social loop closes — and that required making the
              receiving end feel as polished as the sending end.
            </LearningCard>
          </div>
        </Section>
      </div>

      {/* ── Bottom CTA ── */}
      <section className="max-w-[760px] mx-auto px-6 md:px-8 py-24 md:py-32 text-center">
        <p className="l-eyebrow inline-flex mb-6">See the app</p>
        <h2 className="text-3xl md:text-4xl font-bold tracking-[-0.04em] leading-[1.05] mb-4">
          Download Gimme
        </h2>
        <p className="text-base mb-8" style={{ color: "var(--l-muted)" }}>
          Create your first wishlist in seconds.
        </p>
        <a
          href="https://apps.apple.com/app/gimme-wishlist-gift-ideas/id6762543923"
          target="_blank"
          rel="noopener noreferrer"
          className="group inline-flex items-center gap-3 rounded-full pl-6 pr-2 py-2 text-[15px] font-semibold l-cta no-underline"
        >
          <svg width="14" height="18" viewBox="0 0 16 20" fill="currentColor" className="shrink-0">
            <path d="M11.86 10.36c-.03-2.3 1.88-3.4 1.97-3.46-1.07-1.57-2.74-1.78-3.34-1.81-1.42-.14-2.77.84-3.49.84s-1.83-.82-3.01-.8c-1.55.03-2.98.9-3.78 2.29-1.61 2.79-.41 6.93 1.16 9.19.77 1.11 1.68 2.36 2.88 2.31 1.16-.05 1.6-.75 3-.75s1.79.75 3.01.73c1.24-.03 2.04-1.13 2.8-2.24.88-1.29 1.24-2.53 1.27-2.6-.03-.01-2.44-.94-2.47-3.7zM9.53 3.5c.64-.77 1.07-1.85.95-2.92-.92.04-2.03.61-2.69 1.38-.59.68-1.11 1.77-.97 2.82 1.02.08 2.07-.52 2.71-1.28z" />
          </svg>
          <span>Download on the App Store</span>
          <span className="l-cta-arrow w-8 h-8 rounded-full bg-white/10 flex items-center justify-center ml-1">
            <svg width="11" height="11" viewBox="0 0 12 12" fill="none">
              <path d="M3 9L9 3M9 3H4.5M9 3V7.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
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

/* ─────────────────────────────────────────────
   Layout primitives
───────────────────────────────────────────── */

function Section({
  number,
  eyebrow,
  title,
  children,
}: {
  number: string;
  eyebrow: string;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="relative pt-20 pb-4">
      {/* Decorative number */}
      <span
        aria-hidden="true"
        className="absolute -top-3 -left-2 text-[7rem] md:text-[9rem] font-bold leading-none select-none pointer-events-none tabular-nums"
        style={{ color: "var(--l-accent)", opacity: 0.04, letterSpacing: "-0.05em" }}
      >
        {number}
      </span>
      <div className="relative">
        <span className="l-eyebrow mb-4 inline-flex">{eyebrow}</span>
        <h2 className="text-2xl md:text-[2rem] font-bold tracking-[-0.03em] leading-[1.1] mb-8">
          {title}
        </h2>
        {children}
      </div>
      {/* Bottom divider */}
      <div className="mt-16 border-b" style={{ borderColor: "var(--l-border)" }} />
    </section>
  );
}

function Lede({ children }: { children: React.ReactNode }) {
  return (
    <p className="text-lg md:text-xl leading-[1.7] font-medium mb-6" style={{ color: "var(--l-text)" }}>
      {children}
    </p>
  );
}

function P({
  children,
  className,
  style,
}: {
  children: React.ReactNode;
  className?: string;
  style?: React.CSSProperties;
}) {
  return (
    <p
      className={`text-[15px] leading-[1.75] mb-5 ${className ?? ""}`}
      style={{ color: "var(--l-muted)", ...style }}
    >
      {children}
    </p>
  );
}

function H3({ children }: { children: React.ReactNode }) {
  return (
    <h3 className="text-[17px] font-semibold tracking-tight mt-8 mb-3">{children}</h3>
  );
}

function PullQuote({ children }: { children: React.ReactNode }) {
  return (
    <blockquote
      className="my-8 pl-5 border-l-2 text-base md:text-lg leading-[1.7] italic"
      style={{ borderColor: "var(--l-accent)", color: "var(--l-text)", opacity: 0.75 }}
    >
      {children}
    </blockquote>
  );
}

function Callout({ children }: { children: React.ReactNode }) {
  return (
    <div className="my-8 doppel-outer-dark">
      <div className="doppel-inner-dark px-6 py-5">
        <p className="text-sm leading-relaxed text-white/70">{children}</p>
      </div>
    </div>
  );
}

/* ─────────────────────────────────────────────
   Data components
───────────────────────────────────────────── */

function DataTable({
  headers,
  rows,
  caption,
}: {
  headers: string[];
  rows: string[][];
  caption?: string;
}) {
  return (
    <div className="my-6 overflow-x-auto rounded-xl border" style={{ borderColor: "var(--l-border)" }}>
      {caption && (
        <p
          className="text-[11px] font-semibold uppercase tracking-widest px-4 pt-3 pb-1"
          style={{ color: "var(--l-muted)", opacity: 0.6 }}
        >
          {caption}
        </p>
      )}
      <table className="w-full text-sm border-collapse">
        <thead>
          <tr style={{ background: "var(--l-surface)" }}>
            {headers.map((h) => (
              <th
                key={h}
                className="text-left px-4 py-3 text-[11px] font-semibold uppercase tracking-wider border-b"
                style={{ color: "var(--l-muted)", borderColor: "var(--l-border)" }}
              >
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr
              key={i}
              className="transition-colors"
              style={{
                background: i % 2 === 0 ? "transparent" : "var(--l-surface)",
              }}
            >
              {row.map((cell, j) => (
                <td
                  key={j}
                  className="px-4 py-3 border-b align-top"
                  style={{
                    borderColor: "var(--l-border)",
                    color: j === 0 ? "var(--l-text)" : "var(--l-muted)",
                    fontWeight: j === 0 ? 500 : 400,
                    borderBottomWidth: i === rows.length - 1 ? 0 : 1,
                  }}
                >
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function CheckItem({ text }: { text: string }) {
  return (
    <li className="flex items-start gap-3 text-sm" style={{ color: "var(--l-muted)" }}>
      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" className="shrink-0 mt-0.5">
        <path d="M3 7.5l2.5 2.5L11 4" stroke="var(--l-accent)" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      {text}
    </li>
  );
}

function DarkCard({
  n,
  title,
  children,
}: {
  n: string;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="doppel-outer-dark">
      <div className="doppel-inner-dark p-5">
        <p
          className="text-[10px] font-bold uppercase tracking-[0.2em] mb-3"
          style={{ color: "rgba(255,255,255,0.25)" }}
        >
          {n}
        </p>
        <p className="text-[15px] font-semibold mb-2">{title}</p>
        <p className="text-[13px] leading-relaxed" style={{ color: "rgba(255,255,255,0.45)" }}>
          {children}
        </p>
      </div>
    </div>
  );
}

function LearningCard({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="doppel-outer">
      <div className="doppel-inner px-6 py-5">
        <p className="text-[15px] font-semibold mb-2">{title}</p>
        <p className="text-sm leading-relaxed" style={{ color: "var(--l-muted)" }}>
          {children}
        </p>
      </div>
    </div>
  );
}

function MetaChip({ label, value }: { label: string; value: string }) {
  return (
    <span
      className="inline-flex items-center gap-1.5 text-[12px] rounded-full px-3 py-1.5 border"
      style={{
        background: "var(--l-surface)",
        borderColor: "var(--l-border)",
        color: "var(--l-muted)",
      }}
    >
      <span className="font-semibold" style={{ color: "var(--l-text)" }}>{label}</span>
      <span style={{ opacity: 0.4 }}>·</span>
      {value}
    </span>
  );
}

function StatCard({ n, label }: { n: string; label: string }) {
  return (
    <div className="doppel-outer">
      <div className="doppel-inner px-5 py-4">
        <p className="text-2xl md:text-3xl font-bold tracking-[-0.03em] tabular-nums mb-0.5">
          {n}
        </p>
        <p className="text-[11px] leading-snug" style={{ color: "var(--l-muted)" }}>
          {label}
        </p>
      </div>
    </div>
  );
}

function PricingRow({ text, light }: { text: string; light?: boolean }) {
  return (
    <li className="flex items-center gap-3 text-sm">
      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" className="shrink-0">
        <path
          d="M3 7.5l2.5 2.5L11 4"
          stroke={light ? "rgba(255,255,255,0.35)" : "var(--l-accent)"}
          strokeWidth="1.2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
      <span style={{ opacity: light ? 0.7 : 1 }}>{text}</span>
    </li>
  );
}
