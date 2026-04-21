"use client";

import { useEffect, useState } from "react";

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
    <main
      style={{
        minHeight: "100dvh",
        background: "var(--l-bg)",
        color: "var(--l-text)",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: "1.5rem",
        padding: "2rem",
        fontFamily: "var(--font-outfit), system-ui, sans-serif",
        textAlign: "center",
      }}
    >
      {status === "no-token" ? (
        <>
          <p style={{ fontSize: "1.125rem", fontWeight: 600 }}>
            Invalid or expired reset link.
          </p>
          <p style={{ color: "var(--l-muted)", fontSize: "0.9rem" }}>
            Please request a new password reset from the Gimme app.
          </p>
        </>
      ) : (
        <>
          <div
            style={{
              width: 72,
              height: 72,
              borderRadius: 18,
              background: "var(--l-accent)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: 36,
            }}
          >
            🔑
          </div>
          <div>
            <p style={{ fontSize: "1.25rem", fontWeight: 700, marginBottom: "0.5rem" }}>
              Opening Gimme…
            </p>
            <p style={{ color: "var(--l-muted)", fontSize: "0.9rem" }}>
              If the app doesn&apos;t open automatically, make sure Gimme is installed on your device.
            </p>
          </div>
        </>
      )}
    </main>
  );
}
