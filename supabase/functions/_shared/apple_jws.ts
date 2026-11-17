// Verifies the JWS that StoreKit 2 and the App Store sign: an ES256 compact JWS
// whose header carries the signing certificate chain (x5c) up to Apple's root.
//
// Follows SignedDataVerifier in Apple's App Store Server Library, offline mode:
//   * x5c holds exactly three certificates: leaf, intermediate, root;
//   * the intermediate must be signed by a pinned Apple root (the root in the
//     header itself is never trusted), and the leaf by the intermediate;
//   * the issuers must be CAs, and leaf and intermediate must carry Apple's
//     marker extensions;
//   * every certificate must be valid at the payload's signedDate, so a
//     purchase still verifies after Apple rotates its leaf certificates;
//   * the JWS signature must verify with the leaf's P-256 key.
// Like that library with online checks off, it doesn't ask Apple's OCSP
// responder whether a certificate has been revoked.

import * as x509 from "npm:@peculiar/x509@1.14.3";
import { APPLE_ROOT_CA_G3_DER_BASE64 } from "./apple_root.ts";

x509.cryptoProvider.set(crypto);

/** On the leaf: Mac App Store and iTunes Store receipt signing. */
export const LEAF_MARKER_OID = "1.2.840.113635.100.6.11.1";
/** On the intermediate: Apple Worldwide Developer Relations CA. */
export const INTERMEDIATE_MARKER_OID = "1.2.840.113635.100.6.2.1";

export type JwsFailure =
  /** Not a compact JWS with a JSON header and payload. */
  | "malformed"
  /** Not ES256 with a three-certificate x5c chain and a P-256 leaf key. */
  | "unsupported"
  /** The chain doesn't lead to a pinned Apple root. */
  | "untrusted_chain"
  /** A certificate in the chain wasn't valid when the payload was signed. */
  | "expired_chain"
  /** The signature doesn't match the leaf certificate's key. */
  | "bad_signature";

export class JwsVerificationError extends Error {
  constructor(readonly failure: JwsFailure, message: string) {
    super(message);
    this.name = "JwsVerificationError";
  }
}

/** The roots a production JWS must chain to. Parse once and reuse. */
export function appleRootCertificates(): x509.X509Certificate[] {
  return [new x509.X509Certificate(base64ToBytes(APPLE_ROOT_CA_G3_DER_BASE64))];
}

const SEGMENT = /^[A-Za-z0-9_-]+$/;

/**
 * Checks `jws` and returns its decoded payload. Throws JwsVerificationError
 * when it isn't genuinely signed by the App Store.
 */
export async function verifyAppleJws(
  jws: string,
  trustedRoots: readonly x509.X509Certificate[],
): Promise<Record<string, unknown>> {
  const parts = jws.split(".");
  if (parts.length !== 3 || !parts.every((part) => SEGMENT.test(part))) {
    throw new JwsVerificationError("malformed", "Not a compact JWS.");
  }
  const [headerPart, payloadPart, signaturePart] = parts;
  const header = decodeJsonSegment(headerPart, "header");
  const payload = decodeJsonSegment(payloadPart, "payload");

  if (header.alg !== "ES256") {
    throw new JwsVerificationError("unsupported", `Expected alg ES256, got ${JSON.stringify(header.alg)}.`);
  }
  const x5c = header.x5c;
  if (!Array.isArray(x5c) || x5c.length !== 3 || !x5c.every((cert) => typeof cert === "string")) {
    throw new JwsVerificationError("unsupported", "The x5c header must hold exactly three certificates.");
  }

  const signedDate = payload.signedDate;
  if (typeof signedDate !== "number" || !Number.isFinite(signedDate)) {
    throw new JwsVerificationError("malformed", "The payload has no signedDate.");
  }
  const effectiveTime = signedDate;

  let leaf: x509.X509Certificate;
  let intermediate: x509.X509Certificate;
  try {
    leaf = new x509.X509Certificate(base64ToBytes(x5c[0]));
    intermediate = new x509.X509Certificate(base64ToBytes(x5c[1]));
  } catch {
    throw new JwsVerificationError("malformed", "The x5c header holds an unreadable certificate.");
  }

  // The intermediate must be issued by a root we pinned, never by whatever
  // root the header brought along.
  let root: x509.X509Certificate | undefined;
  for (const candidate of trustedRoots) {
    if (intermediate.issuer === candidate.subject && await signedBy(intermediate, candidate)) {
      root = candidate;
      break;
    }
  }
  if (!root) {
    throw new JwsVerificationError("untrusted_chain", "The intermediate certificate isn't issued by a trusted Apple root.");
  }
  if (leaf.issuer !== intermediate.subject || !(await signedBy(leaf, intermediate))) {
    throw new JwsVerificationError("untrusted_chain", "The leaf certificate isn't issued by the intermediate.");
  }
  if (!isCA(root) || !isCA(intermediate)) {
    throw new JwsVerificationError("untrusted_chain", "An issuing certificate isn't a CA.");
  }
  if (!intermediate.getExtension(INTERMEDIATE_MARKER_OID)) {
    throw new JwsVerificationError("untrusted_chain", "The intermediate certificate lacks Apple's WWDR marker.");
  }
  if (!leaf.getExtension(LEAF_MARKER_OID)) {
    throw new JwsVerificationError("untrusted_chain", "The leaf certificate lacks Apple's App Store signing marker.");
  }
  for (const cert of [leaf, intermediate, root]) {
    if (effectiveTime < cert.notBefore.getTime() || effectiveTime > cert.notAfter.getTime()) {
      throw new JwsVerificationError("expired_chain", `"${cert.subject}" wasn't valid when the payload was signed.`);
    }
  }

  // ES256: ECDSA over P-256 with SHA-256, signature as raw r || s.
  let signature: Uint8Array<ArrayBuffer>;
  try {
    signature = base64UrlToBytes(signaturePart);
  } catch {
    throw new JwsVerificationError("malformed", "The JWS signature isn't base64url-encoded.");
  }
  if (signature.length !== 64) {
    throw new JwsVerificationError("bad_signature", "An ES256 signature is 64 bytes.");
  }
  let key: CryptoKey;
  try {
    key = await crypto.subtle.importKey(
      "spki",
      leaf.publicKey.rawData,
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["verify"],
    );
  } catch {
    throw new JwsVerificationError("unsupported", "The leaf certificate's key isn't a P-256 key.");
  }
  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    signature,
    new TextEncoder().encode(`${headerPart}.${payloadPart}`),
  );
  if (!valid) {
    throw new JwsVerificationError("bad_signature", "The JWS signature doesn't verify.");
  }
  return payload;
}

/** verifyAppleJws's verdict as a value: the payload, or why the JWS was refused. */
export type VerifyResult =
  | { ok: true; payload: Record<string, unknown> }
  | { ok: false; reason: JwsFailure; detail: string };

/**
 * verifyAppleJws against `trustedRoots`, in the shape the functions' `Deps`
 * take: a JWS that fails verification comes back as `{ ok: false }`, and only
 * an unexpected error throws.
 */
export function appleJwsVerifier(trustedRoots: readonly x509.X509Certificate[]) {
  return async (jws: string): Promise<VerifyResult> => {
    try {
      return { ok: true, payload: await verifyAppleJws(jws, trustedRoots) };
    } catch (error) {
      if (error instanceof JwsVerificationError) {
        return { ok: false, reason: error.failure, detail: error.message };
      }
      throw error;
    }
  };
}

async function signedBy(cert: x509.X509Certificate, issuer: x509.X509Certificate): Promise<boolean> {
  try {
    return await cert.verify({ publicKey: issuer, signatureOnly: true });
  } catch {
    return false;
  }
}

function isCA(cert: x509.X509Certificate): boolean {
  return cert.getExtension(x509.BasicConstraintsExtension)?.ca === true;
}

function decodeJsonSegment(segment: string, name: string): Record<string, unknown> {
  let value: unknown;
  try {
    value = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(base64UrlToBytes(segment)));
  } catch {
    throw new JwsVerificationError("malformed", `The JWS ${name} isn't base64url-encoded JSON.`);
  }
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new JwsVerificationError("malformed", `The JWS ${name} isn't a JSON object.`);
  }
  return value as Record<string, unknown>;
}

export function base64ToBytes(base64: string): Uint8Array<ArrayBuffer> {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

export function base64UrlToBytes(base64url: string): Uint8Array<ArrayBuffer> {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/");
  return base64ToBytes(base64 + "===".slice((base64.length + 3) % 4));
}
