// fetch-metadata: server-side HTML scraper for product metadata.
// Runs in Deno (Supabase Edge Runtime). No auth required — anon key is enough.

interface MetadataResult {
  title: string
  imageURL?: string
  alternativeImageURLs: string[]
  price?: string
  currency?: string
  description?: string
  brand?: string
  color?: string
  size?: string
}

// Full Chromium/Windows browser headers — Amazon and most retailers
// pass bot checks far more readily for datacenter requests that look like
// a real browser than for iOS User-Agent strings.
const BROWSER_HEADERS: Record<string, string> = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
  "Accept":
    "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
  "Accept-Language": "en-US,en;q=0.9",
  "Accept-Encoding": "gzip, deflate, br",
  "Cache-Control": "no-cache",
  "Pragma": "no-cache",
  "Sec-Ch-Ua":
    '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
  "Sec-Ch-Ua-Mobile": "?0",
  "Sec-Ch-Ua-Platform": '"Windows"',
  "Sec-Fetch-Dest": "document",
  "Sec-Fetch-Mode": "navigate",
  "Sec-Fetch-Site": "none",
  "Sec-Fetch-User": "?1",
  "Upgrade-Insecure-Requests": "1",
  // Looks like a click-through from Google search — helps with some retailers
  "Referer": "https://www.google.com/",
}

// ─── Main handler ────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
      },
    })
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405)
  }

  let targetURL: URL
  try {
    const body = await req.json()
    if (!body?.url || typeof body.url !== "string") throw new Error()
    targetURL = new URL(body.url)
    if (targetURL.protocol !== "http:" && targetURL.protocol !== "https:") throw new Error()
  } catch {
    return json({ error: "Invalid or missing url" }, 400)
  }

  try {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), 12_000)

    const res = await fetch(targetURL.href, {
      headers: BROWSER_HEADERS,
      signal: controller.signal,
      redirect: "follow",
    })
    clearTimeout(timer)

    if (!res.ok) {
      return json({ error: `Upstream returned HTTP ${res.status}` }, 502)
    }

    // Guard against huge pages (cap at 3 MB)
    const MAX = 512 * 1024 // 512 KB — all metadata lives in <head>, never needs more
    const buffer = await res.arrayBuffer()
    const slice = buffer.byteLength > MAX ? buffer.slice(0, MAX) : buffer
    const html = new TextDecoder("utf-8").decode(slice)
    const metadata = parseMetadata(html, targetURL)
    return json(metadata, 200)
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    return json({ error: msg }, 502)
  }
})

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  })
}

// ─── Metadata parsing pipeline ───────────────────────────────────────────────
//
// Priority for each field:
//   1. Amazon-specific selectors (when on amazon.*)
//   2. JSON-LD structured data
//   3. OpenGraph / Twitter meta tags
//   4. Microdata (itemprop)
//   5. HTML fallback selectors

function parseMetadata(html: string, pageURL: URL): MetadataResult {
  const amazon = isAmazonURL(pageURL) ? parseAmazon(html, pageURL) : {}
  const jsonLD = parseJSONLD(html)
  const variants = parseURLVariants(pageURL)

  const title = (
    amazon.title ??
    jsonLD.name ??
    ogMeta(html, "og:title") ??
    ogMeta(html, "twitter:title") ??
    itempropContent(html, "name") ??
    htmlTitle(html) ??
    pageURL.hostname
  ).replace(/\s+/g, " ").trim()

  const priceRaw =
    amazon.price ??
    jsonLD.price ??
    ogMeta(html, "og:price:amount") ??
    ogMeta(html, "product:price:amount") ??
    itempropContent(html, "price") ??
    htmlPriceSelector(html)

  const price = priceRaw ? normalisePrice(priceRaw) : undefined

  const currency =
    amazon.currency ??
    jsonLD.priceCurrency ??
    ogMeta(html, "og:price:currency") ??
    ogMeta(html, "product:price:currency") ??
    itempropContent(html, "priceCurrency")

  const description = (
    jsonLD.description ??
    ogMeta(html, "og:description") ??
    ogMeta(html, "twitter:description") ??
    itempropContent(html, "description") ??
    metaName(html, "description")
  )?.replace(/\s+/g, " ").trim()

  const brand = (
    jsonLD.brand ??
    itempropContent(html, "brand") ??
    ogMeta(html, "product:brand") ??
    ogMeta(html, "og:site_name")
  )?.replace(/\s+/g, " ").trim()

  const color = (
    variants.color ??
    jsonLD.color ??
    itempropContent(html, "color")
  )?.replace(/\s+/g, " ").trim()

  const size = (
    variants.size ??
    jsonLD.size ??
    itempropContent(html, "size")
  )?.replace(/\s+/g, " ").trim()

  const images = collectImages(html, jsonLD, amazon, pageURL)

  return {
    title,
    imageURL: images[0],
    alternativeImageURLs: images.slice(1, 6),
    price,
    currency: currency?.toUpperCase(),
    description,
    brand,
    color,
    size,
  }
}

// ─── Amazon-specific parsing ──────────────────────────────────────────────────

function isAmazonURL(url: URL): boolean {
  return /(?:^|\.)amazon\.(com|co\.uk|de|fr|co\.jp|ca|com\.au|it|es|nl|se|pl|com\.br|com\.mx|in|ae|sa)$/.test(
    url.hostname,
  )
}

interface AmazonData {
  title?: string
  price?: string
  currency?: string
  imageURL?: string
}

function parseAmazon(html: string, _pageURL: URL): AmazonData {
  const result: AmazonData = {}

  // Title — <span id="productTitle">
  const titleM = html.match(/id="productTitle"[^>]*>([\s\S]*?)<\/span>/)
  if (titleM) {
    result.title = stripTags(titleM[1]).trim()
  }

  // Price — most reliable: the screen-reader ".a-offscreen" span
  // Amazon renders: <span class="a-offscreen">$29.99</span>
  const offscreenM = html.match(/<span[^>]*class="[^"]*a-offscreen[^"]*"[^>]*>([^<]+)<\/span>/)
  if (offscreenM) {
    const raw = offscreenM[1].trim()
    // Extract currency symbol and numeric value
    const symbolMatch = raw.match(/^([^\d\s]+)/)
    if (symbolMatch) {
      result.currency = symbolToCurrency(symbolMatch[1])
    }
    const numMatch = raw.match(/([\d,.\s]+)$/)
    if (numMatch) result.price = numMatch[1].trim()
  }

  // Price fallback — whole + fraction spans
  if (!result.price) {
    const wholeM = html.match(/<span[^>]*class="[^"]*a-price-whole[^"]*"[^>]*>([\d,]+)/)
    if (wholeM) {
      const whole = wholeM[1].replace(/[,]/g, "")
      const fracM = html.match(/<span[^>]*class="[^"]*a-price-fraction[^"]*"[^>]*>(\d+)/)
      result.price = fracM ? `${whole}.${fracM[1]}` : whole
    }
  }

  // Image — data-a-dynamic-image contains JSON: { "url": [w, h] }
  const dynImgM = html.match(/id="landingImage"[\s\S]*?data-a-dynamic-image="([^"]+)"/)
  if (dynImgM) {
    try {
      const decoded = dynImgM[1].replace(/&quot;/g, '"').replace(/&#34;/g, '"')
      const map = JSON.parse(decoded) as Record<string, [number, number]>
      const best = Object.entries(map).sort(
        (a, b) => b[1][0] * b[1][1] - a[1][0] * a[1][1],
      )[0]
      if (best) result.imageURL = best[0]
    } catch { /* ignore */ }
  }

  // Image fallback — data-old-hires
  if (!result.imageURL) {
    const hiResM = html.match(/id="landingImage"[^>]*data-old-hires="([^"]+)"/)
    if (hiResM) result.imageURL = hiResM[1]
  }

  // Image fallback — src of landing image
  if (!result.imageURL) {
    const srcM = html.match(/id="landingImage"[^>]*src="([^"]+)"/)
    if (srcM && !srcM[1].includes("data:")) result.imageURL = srcM[1]
  }

  return result
}

function symbolToCurrency(symbol: string): string {
  const map: Record<string, string> = {
    "$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY", "₹": "INR",
    "A$": "AUD", "C$": "CAD", "CHF": "CHF", "kr": "SEK",
  }
  return map[symbol.trim()] ?? "USD"
}

// ─── JSON-LD ──────────────────────────────────────────────────────────────────

interface JSONLDProduct {
  name?: string
  description?: string
  price?: string
  priceCurrency?: string
  brand?: string
  color?: string
  size?: string
  images: string[]
}

const JSON_LD_RE =
  /<script[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi

function parseJSONLD(html: string): JSONLDProduct {
  const result: JSONLDProduct = { images: [] }
  const productTypes = new Set([
    "Product", "IndividualProduct", "ProductModel", "SoftwareApplication",
    "MobileApplication", "Book", "Movie", "MusicAlbum", "VideoGame",
    "Offer", "AggregateOffer",
  ])

  let m: RegExpExecArray | null
  JSON_LD_RE.lastIndex = 0
  while ((m = JSON_LD_RE.exec(html)) !== null) {
    let json: unknown
    try { json = JSON.parse(m[1]) } catch { continue }

    const objects: Record<string, unknown>[] = Array.isArray(json)
      ? (json as Record<string, unknown>[])
      : [json as Record<string, unknown>]

    for (const obj of objects) {
      extractProduct(obj, result, productTypes)
      const graph = obj["@graph"]
      if (Array.isArray(graph)) {
        for (const node of graph as Record<string, unknown>[]) {
          extractProduct(node, result, productTypes)
        }
      }
    }
  }

  return result
}

function extractProduct(
  obj: Record<string, unknown>,
  result: JSONLDProduct,
  productTypes: Set<string>,
) {
  const typeVal = obj["@type"]
  const types: string[] = Array.isArray(typeVal)
    ? (typeVal as string[])
    : typeof typeVal === "string"
    ? [typeVal]
    : []

  const isProduct = types.some((t) => productTypes.has(t))
  const hasProductSignals = obj["price"] !== undefined || obj["offers"] !== undefined
  if (!isProduct && !hasProductSignals) return

  if (!result.name && typeof obj["name"] === "string") result.name = obj["name"]
  if (!result.description && typeof obj["description"] === "string")
    result.description = obj["description"]
  if (!result.brand) {
    const b = obj["brand"]
    if (typeof b === "string") result.brand = b
    else if (b && typeof (b as Record<string, unknown>)["name"] === "string")
      result.brand = (b as Record<string, string>)["name"]
  }
  if (!result.color && typeof obj["color"] === "string") result.color = obj["color"]
  if (!result.size && typeof obj["size"] === "string") result.size = obj["size"]

  // Images
  const img = obj["image"]
  if (typeof img === "string") result.images.push(img)
  else if (Array.isArray(img))
    for (const i of img)
      if (typeof i === "string") result.images.push(i)
      else if (i && typeof (i as Record<string, unknown>)["url"] === "string")
        result.images.push((i as Record<string, string>)["url"])
  else if (img && typeof (img as Record<string, unknown>)["url"] === "string")
    result.images.push((img as Record<string, string>)["url"])

  // Price
  if (!result.price) {
    const offers = obj["offers"]
    if (offers && !Array.isArray(offers)) {
      extractPriceFrom(offers as Record<string, unknown>, result)
    } else if (Array.isArray(offers) && offers.length > 0) {
      extractPriceFrom(offers[0] as Record<string, unknown>, result)
    } else {
      extractPriceFrom(obj, result)
    }
  }
}

function extractPriceFrom(o: Record<string, unknown>, result: JSONLDProduct) {
  const p = o["price"] ?? o["lowPrice"]
  if (typeof p === "string") result.price = p
  else if (typeof p === "number") result.price = String(p)
  if (!result.priceCurrency && typeof o["priceCurrency"] === "string")
    result.priceCurrency = o["priceCurrency"]
}

// ─── Meta tag helpers ─────────────────────────────────────────────────────────

function ogMeta(html: string, property: string): string | undefined {
  const esc = property.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  const r1 = new RegExp(
    `property=["']${esc}["'][^>]*content=["']([^"'<>]+)["']`,
    "i",
  ).exec(html)
  if (r1) return decodeEntities(r1[1])
  const r2 = new RegExp(
    `content=["']([^"'<>]+)["'][^>]*property=["']${esc}["']`,
    "i",
  ).exec(html)
  if (r2) return decodeEntities(r2[1])
}

function metaName(html: string, name: string): string | undefined {
  const esc = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  const r1 = new RegExp(
    `name=["']${esc}["'][^>]*content=["']([^"'<>]+)["']`,
    "i",
  ).exec(html)
  if (r1) return decodeEntities(r1[1])
  const r2 = new RegExp(
    `content=["']([^"'<>]+)["'][^>]*name=["']${esc}["']`,
    "i",
  ).exec(html)
  if (r2) return decodeEntities(r2[1])
}

function itempropContent(html: string, itemprop: string): string | undefined {
  const esc = itemprop.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  const r1 = new RegExp(
    `itemprop=["']${esc}["'][^>]*content=["']([^"'<>]+)["']`,
    "i",
  ).exec(html)
  if (r1) return decodeEntities(r1[1])
  const r2 = new RegExp(
    `itemprop=["']${esc}["'][^>]*>([^<]{1,200})<`,
    "i",
  ).exec(html)
  if (r2) return decodeEntities(r2[1]).trim()
}

function htmlTitle(html: string): string | undefined {
  const m = /<title[^>]*>([^<]{1,300})<\/title>/i.exec(html)
  return m ? decodeEntities(m[1]).trim() : undefined
}

// ─── Price ────────────────────────────────────────────────────────────────────

function htmlPriceSelector(html: string): string | undefined {
  const patterns = [
    /class="[^"]*(?:price|Price|product-price|sale-price|current-price|offer-price)[^"]*"[^>]*>[\s$€£¥]*([0-9][0-9,.\s]*[0-9])/,
    /data-price=["']([0-9]+(?:[.,][0-9]{1,2})?)["']/,
    /<span[^>]*>[\s]*[$€£¥]\s*([0-9]{1,7}(?:[.,][0-9]{1,2})?)\s*<\/span>/,
  ]
  for (const re of patterns) {
    const m = re.exec(html)
    if (m) {
      const cleaned = m[1].replace(/,/g, ".").replace(/\s/g, "").replace(/[^0-9.]/g, "")
      const val = parseFloat(cleaned)
      if (val > 0 && val < 1_000_000) return cleaned
    }
  }
}

function normalisePrice(raw: string): string | undefined {
  let s = raw.replace(/\s/g, "")
  // Strip currency symbols
  s = s.replace(/^[^\d,.\-]+/, "")
  const lastComma = s.lastIndexOf(",")
  const lastDot = s.lastIndexOf(".")
  if (lastComma > -1 && lastDot > -1) {
    if (lastComma > lastDot) {
      // European: 1.299,99
      s = s.replace(/\./g, "").replace(",", ".")
    } else {
      // US: 1,299.99
      s = s.replace(/,/g, "")
    }
  } else if (lastComma > -1) {
    const parts = s.split(",")
    if (parts.length === 2 && parts[1].length === 2) {
      // European decimal: 19,99
      s = s.replace(",", ".")
    } else {
      s = s.replace(/,/g, "")
    }
  }
  const val = parseFloat(s)
  if (isNaN(val) || val <= 0 || val >= 1_000_000) return undefined
  return s
}

// ─── Image collection ─────────────────────────────────────────────────────────

function collectImages(
  html: string,
  jsonLD: JSONLDProduct,
  amazon: AmazonData,
  pageURL: URL,
): string[] {
  const seen = new Set<string>()
  const candidates: { url: string; score: number }[] = []

  function add(raw: string | undefined, score: number) {
    if (!raw) return
    const resolved = resolveURL(raw, pageURL)
    if (!resolved) return
    if (seen.has(resolved)) return
    if (isTrackingPixel(raw)) return
    seen.add(resolved)
    candidates.push({ url: resolved, score })
  }

  add(amazon.imageURL, 110) // Amazon hi-res wins everything
  for (const img of jsonLD.images) add(img, 100)
  add(ogMeta(html, "og:image"), 90)
  add(ogMeta(html, "twitter:image"), 80)
  add(ogMeta(html, "twitter:image:src"), 80)

  // Microdata
  for (const m of html.matchAll(/itemprop=["']image["'][^>]*(?:src|content|href)=["']([^"'<>]+)["']/gi))
    add(m[1], 70)

  // Product img tags with data-zoom / data-large (e-commerce standard)
  for (const m of html.matchAll(/<img[^>]*data-(?:zoom|large|src|hi-res|zoom-image)=["']([^"'<>]+)["']/gi))
    add(m[1], 65)

  // Product class imgs
  for (const m of html.matchAll(
    /<img[^>]*class=["'][^"']*(?:product|main|hero|primary|gallery|zoom)[^"']*["'][^>]*src=["']([^"'<>]+)["']/gi,
  ))
    add(m[1], 60)

  candidates.sort((a, b) => b.score - a.score)
  return candidates.map((c) => c.url)
}

function resolveURL(raw: string, base: URL): string | undefined {
  try {
    if (raw.startsWith("http://") || raw.startsWith("https://")) return raw
    if (raw.startsWith("//")) return "https:" + raw
    return new URL(raw, base).href
  } catch {
    return undefined
  }
}

function isTrackingPixel(raw: string): boolean {
  const l = raw.toLowerCase()
  return [
    "1x1", "pixel", "spacer", "blank", "tracking", "beacon",
    "facebook.com/tr", "doubleclick", "googleads", "analytics",
    "amazon-avatars", // Amazon reviewer profile pictures
  ].some((t) => l.includes(t)) ||
    l.endsWith(".gif") ||
    l.endsWith(".svg") || // UI icons, not product images
    l.startsWith("data:image")
}

// ─── URL variant extraction (color / size from query params) ─────────────────

function parseURLVariants(url: URL): { color?: string; size?: string } {
  const colorKeys = new Set(["color", "colour", "clr", "selectedcolor", "dwvar_color"])
  const sizeKeys = new Set(["size", "sz", "selectedsize", "dwvar_size"])
  let color: string | undefined
  let size: string | undefined
  for (const [key, val] of url.searchParams) {
    const k = key.toLowerCase()
    if (!color && colorKeys.has(k)) color = val.replace(/[-+]/g, " ").trim()
    if (!size && sizeKeys.has(k)) size = val.replace(/[-+]/g, " ").toUpperCase().trim()
  }
  return { color, size }
}

// ─── Utilities ────────────────────────────────────────────────────────────────

function stripTags(html: string): string {
  return html.replace(/<[^>]+>/g, "")
}

function decodeEntities(s: string): string {
  return s
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&nbsp;/g, "\u00A0")
    .replace(/&#x([0-9a-fA-F]+);/gi, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
}
