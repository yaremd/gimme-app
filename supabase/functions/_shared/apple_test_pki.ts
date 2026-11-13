// Test only: a certificate authority shaped like Apple's, for signing JWS the
// way the App Store does. No function imports this file, so it never deploys.
//
// P-384 root and intermediate, a P-256 leaf signed with SHA-384, and Apple's
// marker extensions on the intermediate and the leaf. A JWS signed with
// `testPki` verifies when its root is the trusted one, and fails against
// Apple's real root, the way a forgery would in production.
import * as x509 from "npm:@peculiar/x509@1.14.3";
import { INTERMEDIATE_MARKER_OID, LEAF_MARKER_OID } from "./apple_jws.ts";

x509.cryptoProvider.set(crypto);

export const P384 = { name: "ECDSA", namedCurve: "P-384" } as const;
export const P256 = { name: "ECDSA", namedCurve: "P-256" } as const;
const SIGN_SHA384 = { name: "ECDSA", hash: "SHA-384" } as const;
const ASN1_NULL = new Uint8Array([0x05, 0x00]);

export const ec = (curve: typeof P384 | typeof P256) =>
  crypto.subtle.generateKey(curve, true, ["sign", "verify"]) as Promise<CryptoKeyPair>;

export interface Issuer {
  cert: x509.X509Certificate;
  keys: CryptoKeyPair;
}

export async function makeRoot(name = "CN=Test Root CA - G3, O=Test, C=US"): Promise<Issuer> {
  const keys = await ec(P384);
  const cert = await x509.X509CertificateGenerator.createSelfSigned({
    serialNumber: "01",
    name,
    notBefore: new Date("2014-01-01T00:00:00Z"),
    notAfter: new Date("2039-01-01T00:00:00Z"),
    keys,
    signingAlgorithm: SIGN_SHA384,
    extensions: [new x509.BasicConstraintsExtension(true, undefined, true)],
  });
  return { cert, keys };
}

export async function makeIntermediate(
  issuer: Issuer,
  opts: { ca?: boolean; marker?: boolean; subject?: string } = {},
): Promise<Issuer> {
  const keys = await ec(P384);
  const ca = opts.ca ?? true;
  const extensions: x509.Extension[] = [new x509.BasicConstraintsExtension(ca, ca ? 0 : undefined, true)];
  if (opts.marker ?? true) extensions.push(new x509.Extension(INTERMEDIATE_MARKER_OID, false, ASN1_NULL));
  const cert = await x509.X509CertificateGenerator.create({
    serialNumber: "02",
    subject: opts.subject ?? "CN=Test WWDR CA, OU=G6, O=Test, C=US",
    issuer: issuer.cert.subject,
    notBefore: new Date("2021-01-01T00:00:00Z"),
    notAfter: new Date("2036-01-01T00:00:00Z"),
    publicKey: keys.publicKey,
    signingKey: issuer.keys.privateKey,
    signingAlgorithm: SIGN_SHA384,
    extensions,
  });
  return { cert, keys };
}

export async function makeLeaf(
  issuer: { subject: string; signingKey: CryptoKey },
  opts: { marker?: boolean; notBefore?: string; notAfter?: string; curve?: typeof P384 | typeof P256 } = {},
): Promise<Issuer> {
  const keys = await ec(opts.curve ?? P256);
  const extensions: x509.Extension[] = [];
  if (opts.marker ?? true) extensions.push(new x509.Extension(LEAF_MARKER_OID, false, ASN1_NULL));
  const cert = await x509.X509CertificateGenerator.create({
    serialNumber: "03",
    subject: "CN=Test ECC App Store Receipt Signing, O=Test, C=US",
    issuer: issuer.subject,
    notBefore: new Date(opts.notBefore ?? "2025-01-01T00:00:00Z"),
    notAfter: new Date(opts.notAfter ?? "2027-01-01T00:00:00Z"),
    publicKey: keys.publicKey,
    signingKey: issuer.signingKey,
    signingAlgorithm: SIGN_SHA384,
    extensions,
  });
  return { cert, keys };
}

/** A root, an intermediate it issued, and a leaf the intermediate issued. */
export interface TestPki {
  root: Issuer;
  intermediate: Issuer;
  leaf: Issuer;
}

export async function makeTestPki(rootName?: string): Promise<TestPki> {
  const root = await makeRoot(rootName);
  const intermediate = await makeIntermediate(root);
  const leaf = await makeLeaf({ subject: intermediate.cert.subject, signingKey: intermediate.keys.privateKey });
  return { root, intermediate, leaf };
}

/** The PKI that `signJws` signs with unless told otherwise. */
export const testPki = await makeTestPki();

// ── JWS ─────────────────────────────────────────────────────────────────────

export function toBase64(bytes: ArrayBuffer | Uint8Array): string {
  const view = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let binary = "";
  for (const byte of view) binary += String.fromCharCode(byte);
  return btoa(binary);
}

export const toBase64Url = (bytes: ArrayBuffer | Uint8Array) =>
  toBase64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

export const encodeJson = (value: unknown) => toBase64Url(new TextEncoder().encode(JSON.stringify(value)));

/**
 * Signs `body` as an ES256 compact JWS with an x5c header, like the App Store.
 * By default the chain and key are `testPki`'s; pass `pki`, or `chain` and
 * `key`, to sign with something else.
 */
export async function signJws(
  body: unknown,
  opts: {
    pki?: TestPki;
    key?: CryptoKey;
    chain?: Array<x509.X509Certificate | string>;
    header?: Record<string, unknown>;
  } = {},
): Promise<string> {
  const pki = opts.pki ?? testPki;
  const chain = opts.chain ?? [pki.leaf.cert, pki.intermediate.cert, pki.root.cert];
  const header = {
    alg: "ES256",
    x5c: chain.map((cert) => typeof cert === "string" ? cert : toBase64(cert.rawData)),
    ...opts.header,
  };
  const signingInput = `${encodeJson(header)}.${encodeJson(body)}`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    opts.key ?? pki.leaf.keys.privateKey,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${toBase64Url(signature)}`;
}
