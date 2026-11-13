// Run: deno test --node-modules-dir=none supabase/functions/identify-product/
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  createDeviceCheckClient,
  type DeviceCheckConfig,
  InvalidDeviceToken,
  makeDeviceCheckJWT,
  pemToDer,
} from "./devicecheck.ts";

function fromBase64url(text: string): Uint8Array<ArrayBuffer> {
  const base64 = text.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(text.length / 4) * 4, "=");
  return Uint8Array.from(atob(base64), (char) => char.charCodeAt(0));
}

/** A throwaway P-256 key in the same PEM shape Apple's .p8 files use. */
async function testKey(): Promise<{ pem: string; publicKey: CryptoKey }> {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  const base64 = btoa(String.fromCharCode(...der)).match(/.{1,64}/g)!.join("\n");
  return { pem: `-----BEGIN PRIVATE KEY-----\n${base64}\n-----END PRIVATE KEY-----\n`, publicKey: pair.publicKey };
}

Deno.test("the JWT is an ES256 token Apple can verify", async () => {
  const { pem, publicKey } = await testKey();
  const config: DeviceCheckConfig = { keyId: "KEY123", teamId: "TEAM456", privateKeyPem: pem, allowDevelopment: false };
  const jwt = await makeDeviceCheckJWT(config, 1_800_000_000);

  const [header, claims, signature] = jwt.split(".");
  assertEquals(JSON.parse(new TextDecoder().decode(fromBase64url(header))), { alg: "ES256", kid: "KEY123" });
  assertEquals(JSON.parse(new TextDecoder().decode(fromBase64url(claims))), { iss: "TEAM456", iat: 1_800_000_000 });
  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    publicKey,
    fromBase64url(signature),
    new TextEncoder().encode(`${header}.${claims}`),
  );
  assert(valid);
});

Deno.test("a key pasted with literal \\n sequences still parses", async () => {
  const { pem } = await testKey();
  assertEquals(pemToDer(pem.replace(/\n/g, "\\n")), pemToDer(pem));
});

interface Captured {
  url: string;
  authorization: string | null;
  body: Record<string, unknown>;
  hasTimeout: boolean;
}

async function clientWith(responses: Array<[number, string]>, allowDevelopment = false) {
  const { pem } = await testKey();
  const captured: Captured[] = [];
  const fakeFetch = (input: string | URL | Request, init?: RequestInit) => {
    captured.push({
      url: String(input),
      authorization: new Headers(init?.headers).get("Authorization"),
      body: JSON.parse(String(init?.body)),
      hasTimeout: init?.signal instanceof AbortSignal,
    });
    const [status, text] = responses.shift()!;
    return Promise.resolve(new Response(text, { status }));
  };
  const client = createDeviceCheckClient(
    { keyId: "KEY123", teamId: "TEAM456", privateKeyPem: pem, allowDevelopment },
    fakeFetch as typeof fetch,
    () => 1_800_000_000_000,
  );
  return { client, captured };
}

Deno.test("a device Apple has never seen hasn't used its try", async () => {
  const { client, captured } = await clientWith([[200, "Failed to find bit state"]]);
  assertEquals(await client.isUsed("tok", "production"), false);
  assertEquals(captured[0].url, "https://api.devicecheck.apple.com/v1/query_two_bits");
  assertEquals(captured[0].body.device_token, "tok");
  assertEquals(captured[0].body.timestamp, 1_800_000_000_000);
  assert(typeof captured[0].body.transaction_id === "string");
  assertEquals(captured[0].authorization?.split(" ")[0], "Bearer");
  assertEquals(captured[0].authorization?.split(".").length, 3);
  assert(captured[0].hasTimeout, "calls to Apple must not hang the request");
});

Deno.test("bit0 means the try is used", async () => {
  const { client } = await clientWith([
    [200, '{"bit0":true,"bit1":false,"last_update_time":"2026-11"}'],
    [200, '{"bit0":false,"bit1":false,"last_update_time":"2026-11"}'],
  ]);
  assertEquals(await client.isUsed("tok", "production"), true);
  assertEquals(await client.isUsed("tok", "production"), false);
});

Deno.test("setUsed writes bit0 and leaves bit1 clear", async () => {
  const { client, captured } = await clientWith([[200, ""]]);
  await client.setUsed("tok", "production", true);
  assertEquals(captured[0].url, "https://api.devicecheck.apple.com/v1/update_two_bits");
  assertEquals(captured[0].body.bit0, true);
  assertEquals(captured[0].body.bit1, false);
});

Deno.test("development tokens use Apple's development server only when allowed", async () => {
  const blocked = await clientWith([[200, "Failed to find bit state"]], false);
  await blocked.client.isUsed("tok", "development");
  assertEquals(new URL(blocked.captured[0].url).host, "api.devicecheck.apple.com");

  const allowed = await clientWith([[200, "Failed to find bit state"]], true);
  await allowed.client.isUsed("tok", "development");
  assertEquals(new URL(allowed.captured[0].url).host, "api.development.devicecheck.apple.com");
});

Deno.test("a 400 is a bad token; other failures are errors", async () => {
  const { client } = await clientWith([[400, "Missing or incorrectly formatted device token payload"], [503, "unavailable"]]);
  await assertRejects(() => client.isUsed("bad", "production"), InvalidDeviceToken);
  await assertRejects(() => client.isUsed("tok", "production"), Error, "503");
});
