// Apple DeviceCheck: lets a signed-out user identify one photo per device.
//
// Apple keeps two bits per device for each developer team. We use bit0 to mean
// "free try used". The bits survive reinstalls, and neither the token nor the
// bits tell us who the person is. Setup: Apple Developer → Keys → new key with
// DeviceCheck enabled; store its Key ID, the .p8 contents and the Team ID as
// function secrets (see index.ts).

export type DeviceCheckEnvironment = "production" | "development";

export interface DeviceCheckConfig {
  keyId: string;
  teamId: string;
  /** Contents of the .p8 file (PKCS#8 PEM). Literal "\n" sequences are accepted. */
  privateKeyPem: string;
  /** Debug builds from Xcode get development tokens; honour them only when this is on. */
  allowDevelopment: boolean;
}

export interface DeviceCheckClient {
  isUsed(deviceToken: string, environment: DeviceCheckEnvironment): Promise<boolean>;
  setUsed(deviceToken: string, environment: DeviceCheckEnvironment, used: boolean): Promise<void>;
}

/** Apple rejected the device token (malformed, or from the other environment). */
export class InvalidDeviceToken extends Error {}

const HOSTS: Record<DeviceCheckEnvironment, string> = {
  production: "https://api.devicecheck.apple.com",
  development: "https://api.development.devicecheck.apple.com",
};

/** Give up on Apple after this long rather than hold the request open. */
const TIMEOUT_MS = 10_000;

export function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem
    .replace(/\\n/g, "\n")
    .replace(/-----(BEGIN|END) [A-Z ]+-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

/** ES256 JWT that authenticates us to the DeviceCheck API. */
export async function makeDeviceCheckJWT(config: DeviceCheckConfig, issuedAtSeconds: number): Promise<string> {
  const header = base64url(JSON.stringify({ alg: "ES256", kid: config.keyId }));
  const claims = base64url(JSON.stringify({ iss: config.teamId, iat: issuedAtSeconds }));
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(config.privateKeyPem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  // Web Crypto returns the raw r||s signature, which is exactly what JWS ES256 expects.
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64url(new Uint8Array(signature))}`;
}

export function createDeviceCheckClient(
  config: DeviceCheckConfig,
  fetchImpl: typeof fetch = fetch,
  nowMs: () => number = () => Date.now(),
): DeviceCheckClient {
  async function call(path: string, requested: DeviceCheckEnvironment, body: Record<string, unknown>): Promise<string> {
    const environment = requested === "development" && config.allowDevelopment ? "development" : "production";
    const jwt = await makeDeviceCheckJWT(config, Math.floor(nowMs() / 1000));
    const response = await fetchImpl(`${HOSTS[environment]}${path}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
      body: JSON.stringify({ ...body, transaction_id: crypto.randomUUID(), timestamp: nowMs() }),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    const text = await response.text();
    if (response.status === 400) throw new InvalidDeviceToken(text);
    if (!response.ok) throw new Error(`DeviceCheck ${path} returned ${response.status}: ${text}`);
    return text;
  }

  return {
    async isUsed(deviceToken, environment) {
      const text = await call("/v1/query_two_bits", environment, { device_token: deviceToken });
      // A device whose bits were never set comes back as 200 with this plain-text body.
      if (text.trim() === "" || text.includes("Failed to find bit state")) return false;
      const bits = JSON.parse(text) as { bit0?: unknown };
      return bits.bit0 === true;
    },
    async setUsed(deviceToken, environment, used) {
      await call("/v1/update_two_bits", environment, { device_token: deviceToken, bit0: used, bit1: false });
    },
  };
}
