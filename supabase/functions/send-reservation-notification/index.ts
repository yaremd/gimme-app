import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5'

// --- Types ---

interface ReservationPayload {
  item_id: string
  item_title: string
  owner_id: string
  reserved_by_name: string
  list_id: string
  list_name: string
}

interface DeviceToken {
  id: string
  token: string
  platform: string
}

// --- APNs JWT signing ---

async function buildApnsJwt(): Promise<string> {
  const keyId = Deno.env.get('APNS_KEY_ID') ?? ''
  const teamId = Deno.env.get('APNS_TEAM_ID') ?? ''
  const privateKeyBase64 = Deno.env.get('APNS_PRIVATE_KEY') ?? ''

  // Decode the base64-encoded p8 key
  const privateKeyPem = new TextDecoder().decode(
    Uint8Array.from(atob(privateKeyBase64), (c) => c.charCodeAt(0))
  )

  const key = await importPKCS8(privateKeyPem, 'ES256')

  return await new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(key)
}

// --- Send a single push notification ---

async function sendPush(
  token: string,
  title: string,
  body: string,
  customData: Record<string, string>,
  apnsJwt: string,
  apnsHost: string,
  topic: string,
): Promise<{ token: string; status: number }> {
  const response = await fetch(`${apnsHost}/3/device/${token}`, {
    method: 'POST',
    headers: {
      authorization: `bearer ${apnsJwt}`,
      'apns-topic': topic,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      aps: {
        alert: { title, body },
        sound: 'default',
      },
      ...customData,
    }),
  })

  return { token, status: response.status }
}

// --- Main handler ---

Deno.serve(async (req) => {
  // Validate authorization (service role key from DB trigger)
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Parse the reservation payload from the trigger
  const payload: ReservationPayload = await req.json()
  const { item_id, item_title, owner_id, reserved_by_name, list_id, list_name } = payload

  if (!owner_id || !item_title) {
    return new Response(JSON.stringify({ error: 'Missing required fields' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Admin client to query device tokens
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  // Fetch owner's device tokens
  const { data: tokens, error: tokensError } = await supabaseAdmin
    .from('device_tokens')
    .select('id, token, platform')
    .eq('user_id', owner_id)

  if (tokensError || !tokens || tokens.length === 0) {
    return new Response(
      JSON.stringify({ message: 'No device tokens found', error: tokensError?.message }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  }

  // Build the notification
  const friendName = reserved_by_name || 'Someone'
  const title = 'Gift Reserved!'
  const body = `${friendName} reserved ${item_title} from your ${list_name} list`

  // APNs configuration
  const useSandbox = Deno.env.get('APNS_USE_SANDBOX') === 'true'
  const apnsHost = useSandbox
    ? 'https://api.sandbox.push.apple.com'
    : 'https://api.push.apple.com'
  const topic = Deno.env.get('APNS_TOPIC') ?? 'com.yaremchuk.app'

  // Sign APNs JWT
  let apnsJwt: string
  try {
    apnsJwt = await buildApnsJwt()
  } catch (err) {
    return new Response(
      JSON.stringify({ error: 'Failed to sign APNs JWT', detail: String(err) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }

  // Send to all devices
  const results = await Promise.allSettled(
    (tokens as DeviceToken[]).map((t) =>
      sendPush(t.token, title, body, { list_id, item_id }, apnsJwt, apnsHost, topic)
    )
  )

  // Clean up expired tokens (APNs returns 410 for invalid tokens)
  const expiredTokens: string[] = []
  for (const result of results) {
    if (result.status === 'fulfilled' && result.value.status === 410) {
      expiredTokens.push(result.value.token)
    }
  }

  if (expiredTokens.length > 0) {
    await supabaseAdmin
      .from('device_tokens')
      .delete()
      .eq('user_id', owner_id)
      .in('token', expiredTokens)
  }

  return new Response(
    JSON.stringify({
      sent: tokens.length,
      expired_cleaned: expiredTokens.length,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
})
