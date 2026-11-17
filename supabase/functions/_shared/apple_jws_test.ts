// Run: deno test --node-modules-dir=none -A supabase/functions/
//
// The positive cases use the test PKI in apple_test_pki.ts, shaped like
// Apple's: P-384 root and intermediate, a P-256 leaf signed with SHA-384, and
// Apple's marker extensions. The real Apple root and WWDR G6 intermediate cover
// the attack that matters most: copying Apple's genuine certificates into the
// header next to a leaf the attacker signed.
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import * as x509 from "npm:@peculiar/x509@1.14.3";
import {
  appleJwsVerifier,
  appleRootCertificates,
  base64ToBytes,
  INTERMEDIATE_MARKER_OID,
  type JwsFailure,
  JwsVerificationError,
  verifyAppleJws,
} from "./apple_jws.ts";
import { APPLE_ROOT_CA_G3_SHA256 } from "./apple_root.ts";
import {
  ec,
  encodeJson,
  makeIntermediate,
  makeLeaf,
  makeRoot,
  P256,
  P384,
  signJws,
  testPki,
  toBase64,
  toBase64Url,
} from "./apple_test_pki.ts";

x509.cryptoProvider.set(crypto);

// Apple Worldwide Developer Relations Certification Authority, OU=G6: the real
// intermediate behind StoreKit 2 signatures (from the macOS keychain).
// SHA-256 BD:D4:ED:6E:74:69:1F:0C:2B:FD:01:BE:02:96:19:7A:F1:37:9E:04:18:E2:D3:00:EF:A9:C3:BE:F6:42:CA:30
const APPLE_WWDR_G6_DER_BASE64 =
  "MIIDFjCCApygAwIBAgIUIsGhRwp0c2nvU4YSycafPTjzbNcwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYw" +
  "JAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMjEwMzE3" +
  "MjAzNzEwWhcNMzYwMzE5MDAwMDAwWjB1MUQwQgYDVQQDDDtBcHBsZSBXb3JsZHdpZGUgRGV2ZWxvcGVyIFJlbGF0aW9ucyBDZXJ0aWZpY2F0" +
  "aW9uIEF1dGhvcml0eTELMAkGA1UECwwCRzYxEzARBgNVBAoMCkFwcGxlIEluYy4xCzAJBgNVBAYTAlVTMHYwEAYHKoZIzj0CAQYFK4EEACID" +
  "YgAEbsQKC94PrlWmZXnXgtxzdVJL8T0SGYngDRGpngn3N6PT8JMEb7FDi4bBmPhCnZ3/sq6PF/cGcKXWsL5vOteRhyJ45x3ASP7cOB+aao90" +
  "fcpxSv/EZFbniAbNgZGhIhpIo4H6MIH3MBIGA1UdEwEB/wQIMAYBAf8CAQAwHwYDVR0jBBgwFoAUu7DeoVgziJqkipnevr3rr9rLJKswRgYI" +
  "KwYBBQUHAQEEOjA4MDYGCCsGAQUFBzABhipodHRwOi8vb2NzcC5hcHBsZS5jb20vb2NzcDAzLWFwcGxlcm9vdGNhZzMwNwYDVR0fBDAwLjAs" +
  "oCqgKIYmaHR0cDovL2NybC5hcHBsZS5jb20vYXBwbGVyb290Y2FnMy5jcmwwHQYDVR0OBBYEFD8vlCNR01DJmig97bB85c+lkGKZMA4GA1Ud" +
  "DwEB/wQEAwIBBjAQBgoqhkiG92NkBgIBBAIFADAKBggqhkjOPQQDAwNoADBlAjBAXhSq5IyKogMCPtw490BaB677CaEGJXufQB/EqZGd6CSj" +
  "iCtOnuMTbXVXmxxcxfkCMQDTSPxarZXvNrkxU3TkUMI33yzvFVVRT4wxWJC994OsdcZ4+RGNsYDyR5gmdr0nDGg=";

const SIGNED = Date.parse("2026-11-13T10:00:00Z");

const payload = (overrides: Record<string, unknown> = {}) => ({
  transactionId: "2000000123456789",
  originalTransactionId: "2000000123456789",
  bundleId: "com.yaremchuk.app",
  productId: "com.yaremchuk.app.pro.lifetime",
  type: "Non-Consumable",
  environment: "Production",
  purchaseDate: SIGNED - 60_000,
  signedDate: SIGNED,
  ...overrides,
});

const { root, intermediate, leaf } = testPki;
const trusted = [root.cert];

async function assertFails(
  jws: string,
  failure: JwsFailure,
  messageIncludes?: string,
  roots: readonly x509.X509Certificate[] = trusted,
) {
  const error = await assertRejects(() => verifyAppleJws(jws, roots), JwsVerificationError);
  assertEquals(error.failure, failure, error.message);
  if (messageIncludes) assert(error.message.includes(messageIncludes), error.message);
}

// ── The pinned root ─────────────────────────────────────────────────────────

Deno.test("the pinned root is Apple Root CA - G3", async () => {
  const [apple] = appleRootCertificates();
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", apple.rawData));
  const fingerprint = [...digest].map((b) => b.toString(16).padStart(2, "0")).join("");
  assertEquals(fingerprint, APPLE_ROOT_CA_G3_SHA256);
  assertEquals(apple.subject, "CN=Apple Root CA - G3, OU=Apple Certification Authority, O=Apple Inc., C=US");
  assert(await apple.verify({ signatureOnly: true }), "self-signed");
  assertEquals(apple.getExtension(x509.BasicConstraintsExtension)?.ca, true);
});

Deno.test("Apple's real WWDR G6 intermediate chains to the pinned root", async () => {
  const [apple] = appleRootCertificates();
  const g6 = new x509.X509Certificate(base64ToBytes(APPLE_WWDR_G6_DER_BASE64));
  assertEquals(g6.issuer, apple.subject);
  assert(await g6.verify({ publicKey: apple, signatureOnly: true }));
  assert(g6.getExtension(INTERMEDIATE_MARKER_OID) !== null, "carries the WWDR marker");
  assertEquals(g6.getExtension(x509.BasicConstraintsExtension)?.ca, true);
});

// ── Accepted ────────────────────────────────────────────────────────────────

Deno.test("accepts a transaction signed through the chain", async () => {
  const body = payload();
  assertEquals(await verifyAppleJws(await signJws(body), trusted), body);
});

Deno.test("accepts a leaf that has expired since it signed", async () => {
  // Apple rotates leaf certificates; an old purchase's JWS must still verify.
  const old = await makeLeaf(
    { subject: intermediate.cert.subject, signingKey: intermediate.keys.privateKey },
    { notBefore: "2023-01-01T00:00:00Z", notAfter: "2024-01-01T00:00:00Z" },
  );
  const body = payload({ signedDate: Date.parse("2023-06-01T00:00:00Z") });
  const jws = await signJws(body, { key: old.keys.privateKey, chain: [old.cert, intermediate.cert, root.cert] });
  assertEquals(await verifyAppleJws(jws, trusted), body);
});

Deno.test("ignores the root in the header and uses the pinned one", async () => {
  const stranger = await makeRoot("CN=Someone Else, C=US");
  const jws = await signJws(payload(), { chain: [leaf.cert, intermediate.cert, stranger.cert] });
  assertEquals((await verifyAppleJws(jws, trusted)).bundleId, "com.yaremchuk.app");
});

// ── Forged chains ───────────────────────────────────────────────────────────

Deno.test("rejects a self-made chain when only Apple's root is trusted", async () => {
  await assertFails(await signJws(payload()), "untrusted_chain", "intermediate", appleRootCertificates());
});

Deno.test("rejects a forged leaf presented with Apple's genuine intermediate and root", async () => {
  const g6 = new x509.X509Certificate(base64ToBytes(APPLE_WWDR_G6_DER_BASE64));
  const [apple] = appleRootCertificates();
  const attackerKeys = await ec(P384);
  const forged = await makeLeaf({ subject: g6.subject, signingKey: attackerKeys.privateKey });
  const jws = await signJws(payload(), { key: forged.keys.privateKey, chain: [forged.cert, g6, apple] });
  // Failing at the leaf shows the real G6 passed the root check.
  await assertFails(jws, "untrusted_chain", "leaf certificate isn't issued", appleRootCertificates());
});

Deno.test("rejects an intermediate that copies Apple's names but isn't signed by Apple", async () => {
  const [apple] = appleRootCertificates();
  const fakeRoot = await makeRoot(apple.subject);
  const fakeG6 = await makeIntermediate(fakeRoot, {
    subject: "CN=Apple Worldwide Developer Relations Certification Authority, OU=G6, O=Apple Inc., C=US",
  });
  const fakeLeaf = await makeLeaf({ subject: fakeG6.cert.subject, signingKey: fakeG6.keys.privateKey });
  const jws = await signJws(payload(), { key: fakeLeaf.keys.privateKey, chain: [fakeLeaf.cert, fakeG6.cert, apple] });
  await assertFails(jws, "untrusted_chain", "intermediate", appleRootCertificates());
});

Deno.test("rejects a leaf issued by a different intermediate of the same root", async () => {
  const other = await makeIntermediate(root, { subject: "CN=Other Intermediate, C=US" });
  const otherLeaf = await makeLeaf({ subject: other.cert.subject, signingKey: other.keys.privateKey });
  const jws = await signJws(payload(), { key: otherLeaf.keys.privateKey, chain: [otherLeaf.cert, intermediate.cert, root.cert] });
  await assertFails(jws, "untrusted_chain", "leaf");
});

Deno.test("rejects an intermediate that isn't a CA", async () => {
  const notCA = await makeIntermediate(root, { ca: false });
  const childLeaf = await makeLeaf({ subject: notCA.cert.subject, signingKey: notCA.keys.privateKey });
  const jws = await signJws(payload(), { key: childLeaf.keys.privateKey, chain: [childLeaf.cert, notCA.cert, root.cert] });
  await assertFails(jws, "untrusted_chain", "CA");
});

Deno.test("rejects an intermediate without Apple's WWDR marker", async () => {
  const unmarked = await makeIntermediate(root, { marker: false });
  const childLeaf = await makeLeaf({ subject: unmarked.cert.subject, signingKey: unmarked.keys.privateKey });
  const jws = await signJws(payload(), { key: childLeaf.keys.privateKey, chain: [childLeaf.cert, unmarked.cert, root.cert] });
  await assertFails(jws, "untrusted_chain", "WWDR marker");
});

Deno.test("rejects a leaf without Apple's App Store signing marker", async () => {
  const unmarked = await makeLeaf(
    { subject: intermediate.cert.subject, signingKey: intermediate.keys.privateKey },
    { marker: false },
  );
  const jws = await signJws(payload(), { key: unmarked.keys.privateKey, chain: [unmarked.cert, intermediate.cert, root.cert] });
  await assertFails(jws, "untrusted_chain", "App Store signing marker");
});

Deno.test("rejects a certificate that wasn't valid when the payload was signed", async () => {
  const jws = await signJws(payload({ signedDate: Date.parse("2024-06-01T00:00:00Z") }));
  await assertFails(jws, "expired_chain");
});

// ── Signatures ──────────────────────────────────────────────────────────────

Deno.test("rejects a tampered payload", async () => {
  const [header, , signature] = (await signJws(payload())).split(".");
  const tampered = encodeJson(payload({ originalTransactionId: "1" }));
  await assertFails(`${header}.${tampered}.${signature}`, "bad_signature");
});

Deno.test("rejects a signature made with a key other than the leaf's", async () => {
  const stranger = await ec(P256);
  await assertFails(await signJws(payload(), { key: stranger.privateKey }), "bad_signature");
});

Deno.test("rejects a leaf key that isn't P-256", async () => {
  const p384Leaf = await makeLeaf(
    { subject: intermediate.cert.subject, signingKey: intermediate.keys.privateKey },
    { curve: P384 },
  );
  const header = encodeJson({ alg: "ES256", x5c: [p384Leaf.cert, intermediate.cert, root.cert].map((c) => toBase64(c.rawData)) });
  const body = encodeJson(payload());
  const fakeSignature = toBase64Url(new Uint8Array(64));
  await assertFails(`${header}.${body}.${fakeSignature}`, "unsupported", "P-256");
});

// ── Malformed input ─────────────────────────────────────────────────────────

Deno.test("rejects algorithms other than ES256", async () => {
  await assertFails(await signJws(payload(), { header: { alg: "none" } }), "unsupported");
  await assertFails(await signJws(payload(), { header: { alg: "HS256" } }), "unsupported");
});

Deno.test("rejects an x5c chain that isn't three certificates", async () => {
  await assertFails(await signJws(payload(), { chain: [leaf.cert, intermediate.cert] }), "unsupported");
  await assertFails(await signJws(payload(), { header: { x5c: undefined } }), "unsupported");
});

Deno.test("rejects an unreadable certificate", async () => {
  await assertFails(await signJws(payload(), { chain: ["bm90IGEgY2VydA==", intermediate.cert, root.cert] }), "malformed");
});

Deno.test("rejects a payload without signedDate", async () => {
  await assertFails(await signJws(payload({ signedDate: undefined })), "malformed", "signedDate");
});

Deno.test("rejects strings that aren't compact JWS", async () => {
  await assertFails("", "malformed");
  await assertFails("a.b", "malformed");
  await assertFails("a.b.c.d", "malformed");
  await assertFails("a+b.c.d", "malformed");
  await assertFails(`${encodeJson({ alg: "ES256" })}.e30.!!`, "malformed");
  await assertFails(`${toBase64Url(new TextEncoder().encode("not json"))}.e30.AAAA`, "malformed");
  await assertFails(`${encodeJson(["array"])}.e30.AAAA`, "malformed");
  // A signature that isn't valid base64url, on an otherwise good JWS.
  const [header, body] = (await signJws(payload())).split(".");
  await assertFails(`${header}.${body}.A`, "malformed");
});

// ── appleJwsVerifier ────────────────────────────────────────────────────────

Deno.test("appleJwsVerifier returns the payload, or why the JWS was refused", async () => {
  const verify = appleJwsVerifier(trusted);
  const body = payload();
  assertEquals(await verify(await signJws(body)), { ok: true, payload: body });

  const stranger = await ec(P256);
  const refused = await verify(await signJws(body, { key: stranger.privateKey }));
  assertEquals(refused.ok ? "accepted" : refused.reason, "bad_signature");

  const forged = await appleJwsVerifier(appleRootCertificates())(await signJws(body));
  assertEquals(forged.ok ? "accepted" : forged.reason, "untrusted_chain");
});
