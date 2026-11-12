"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Icon, Wordmark } from "../../_site/brand";
import { Sky } from "../../_site/chrome";

/* The link in a password-reset email lands here; this page hands the token to the app. */
export default function ResetPasswordPage() {
  const [status, setStatus] = useState<"redirecting" | "no-token" | "done">("redirecting");

  useEffect(() => {
    // PKCE flow (Supabase v2 default): token arrives as ?code=xxx in query string
    // Implicit flow (legacy): token arrives as #access_token=xxx in hash
    const suffix = window.location.search || window.location.hash;
    if (!suffix) {
      setStatus("no-token");
      return;
    }
    window.location.href = `gimme://reset-password${suffix}`;
    setStatus("done");
  }, []);

  return (
    <>
      <Sky />
      <main id="main" className="g-solo">
        <div className="g-solo__glow" aria-hidden="true" />
        <Link href="/" className="g-solo__logo" aria-label="Gimme, home">
          <Wordmark />
        </Link>
        <div className="g-solo__in" aria-live="polite">
          {status === "no-token" ? (
            <>
              <span className="g-solo__ic">
                <Icon name="link" />
              </span>
              <h1 className="g-solo__title" style={{ fontSize: "clamp(34px, 6vw, 52px)" }}>
                Invalid or expired reset link.
              </h1>
              <p className="g-solo__sub">Please request a new password reset from the Gimme app.</p>
            </>
          ) : (
            <>
              <span className="g-solo__ic">
                <Icon name="key" />
              </span>
              <h1 className="g-solo__title" style={{ fontSize: "clamp(34px, 6vw, 52px)" }}>
                Opening Gimme…
              </h1>
              <p className="g-solo__sub">
                If the app doesn&apos;t open automatically, make sure Gimme is installed on your device.
              </p>
            </>
          )}
        </div>
      </main>
    </>
  );
}
