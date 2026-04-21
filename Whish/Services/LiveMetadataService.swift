import Foundation

// MARK: - Redirect guard

/// Follows http/https redirects normally; converts app-scheme redirects
/// (itms-apps://, itms://) back to https:// once, then halts to prevent loops.
private final class RedirectGuardDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private var converted: Set<Int> = []
    private let lock = NSLock()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let redirectURL = request.url else { completionHandler(nil); return }
        let scheme = redirectURL.scheme ?? ""

        if scheme == "http" || scheme == "https" {
            completionHandler(request)
            return
        }

        lock.lock()
        let alreadyConverted = converted.contains(task.taskIdentifier)
        if !alreadyConverted { converted.insert(task.taskIdentifier) }
        lock.unlock()

        if !alreadyConverted,
           var comps = URLComponents(url: redirectURL, resolvingAgainstBaseURL: true) {
            comps.scheme = "https"
            if let httpsURL = comps.url {
                var newReq = request
                newReq.url = httpsURL
                completionHandler(newReq)
                return
            }
        }
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        lock.lock()
        converted.remove(task.taskIdentifier)
        lock.unlock()
    }
}

// MARK: - Service

struct LiveMetadataService: MetadataService {

    // Desktop Safari UA — avoids app-store redirects and gets full HTML
    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        let delegate = RedirectGuardDelegate()
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()

    // Pre-compiled regex cache — NSCache is thread-safe for reads/writes.
    // Patterns are compiled once on first use and reused across all fetches.
    private nonisolated(unsafe) static let regexCache = NSCache<NSString, NSRegularExpression>()

    private static func compiledRegex(for pattern: String) -> NSRegularExpression? {
        let key = pattern as NSString
        if let cached = regexCache.object(forKey: key) { return cached }
        guard let rx = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        regexCache.setObject(rx, forKey: key)
        return rx
    }

    // Stable patterns pre-compiled as statics — zero runtime cost after first use.
    private static let jsonLDRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(
            pattern: #"<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#,
            options: .caseInsensitive
        )
    }()

    func fetch(url: URL) async throws -> ItemMetadata {
        let sp = Perf.begin("metadata-fetch")
        defer { Perf.end("metadata-fetch", sp) }
        // Edge function runs server-side with full browser headers, bypassing
        // Amazon's and other retailers' mobile/bot detection.
        do {
            return try await fetchViaEdgeFunction(url: url)
        } catch {
            // Amazon always blocks direct iOS requests — don't waste time on fallback.
            if Self.isAmazonURL(url) { throw error }
        }
        return try await fetchDirectly(url: url)
    }

    // MARK: - Edge Function fetch

    private static let edgeFunctionURL = URL(
        string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/fetch-metadata"
    )!

    private static func isAmazonURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("amazon.")
    }

    private func fetchViaEdgeFunction(url: URL) async throws -> ItemMetadata {
        var request = URLRequest(url: Self.edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        request.httpBody = try JSONSerialization.data(withJSONObject: ["url": url.absoluteString])

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                ?? "HTTP \(http.statusCode)"
            throw MetadataError.fetchFailed(msg)
        }

        let dto = try JSONDecoder().decode(MetadataDTO.self, from: data)
        return ItemMetadata(
            title: dto.title ?? "Unknown Item",
            imageURL: dto.imageURL.flatMap { URL(string: $0) },
            alternativeImageURLs: (dto.alternativeImageURLs ?? []).compactMap { URL(string: $0) },
            price: dto.price.flatMap { parseDecimal($0) },
            currency: dto.currency,
            description: dto.description,
            brand: dto.brand,
            color: dto.color,
            size: dto.size
        )
    }

    private struct MetadataDTO: Decodable {
        let title: String?
        let imageURL: String?
        let alternativeImageURLs: [String]?
        let price: String?
        let currency: String?
        let description: String?
        let brand: String?
        let color: String?
        let size: String?
    }

    // MARK: - Direct fetch (fallback for non-Amazon URLs)

    private func fetchDirectly(url: URL) async throws -> ItemMetadata {
        let safeURL: URL
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let rebuilt = comps.url {
            safeURL = rebuilt
        } else {
            safeURL = url
        }

        var request = URLRequest(url: safeURL)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                         forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await Self.session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<400).contains(http.statusCode) {
            throw MetadataError.fetchFailed("Server returned HTTP \(http.statusCode).")
        }

        // All metadata lives in <head> — truncate large pages rather than refusing.
        let maxBytes = 512 * 1024
        let slice = data.count > maxBytes ? data.prefix(maxBytes) : data

        guard let html = String(data: slice, encoding: .utf8)
                      ?? String(data: slice, encoding: .isoLatin1),
              !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MetadataError.noDataFound
        }

        return parse(html: html, pageURL: url)
    }

    // MARK: - Multi-strategy parsing pipeline
    //
    // Priority order for each field:
    //   1. JSON-LD structured data (most reliable when present)
    //   2. OpenGraph / Twitter meta tags
    //   3. HTML-specific selectors (microdata, itemprop, common CSS patterns)
    //   4. <title> / fallback

    private func parse(html: String, pageURL: URL) -> ItemMetadata {
        let jsonLD = parseJSONLD(html)
        let urlVariants = parseURLVariants(pageURL)

        // ── Title ──
        let title = (
            jsonLD.name
            ?? ogMeta(html, property: "og:title")
            ?? ogMeta(html, property: "twitter:title")
            ?? itempropContent(html, itemprop: "name")
            ?? htmlTitle(html)
            ?? pageURL.host
            ?? "Unknown Item"
        ).htmlDecoded.trimmed

        // ── Images ──
        let allImages = collectImages(html: html, jsonLD: jsonLD, pageURL: pageURL)
        let primaryImage = allImages.first
        let alternativeImages = Array(allImages.dropFirst().prefix(5))

        // ── Price ──
        let priceRaw = jsonLD.price
            ?? ogMeta(html, property: "og:price:amount")
            ?? ogMeta(html, property: "product:price:amount")
            ?? itempropContent(html, itemprop: "price")
            ?? htmlPriceSelector(html)
        let price: Decimal? = priceRaw.flatMap(parseDecimal)

        // ── Currency ──
        let currency = jsonLD.priceCurrency
            ?? ogMeta(html, property: "og:price:currency")
            ?? ogMeta(html, property: "product:price:currency")
            ?? itempropContent(html, itemprop: "priceCurrency")

        // ── Description ──
        let description = (
            jsonLD.description
            ?? ogMeta(html, property: "og:description")
            ?? ogMeta(html, property: "twitter:description")
            ?? itempropContent(html, itemprop: "description")
            ?? metaName(html, name: "description")
        )?.htmlDecoded.trimmed

        // ── Brand ──
        let brand = (
            jsonLD.brand
            ?? itempropContent(html, itemprop: "brand")
            ?? ogMeta(html, property: "product:brand")
            ?? ogMeta(html, property: "og:site_name")
        )?.htmlDecoded.trimmed

        // ── Color / Size from URL query params or structured data ──
        let color = (
            urlVariants.color
            ?? jsonLD.color
            ?? itempropContent(html, itemprop: "color")
        )?.htmlDecoded.trimmed

        let size = (
            urlVariants.size
            ?? jsonLD.size
            ?? itempropContent(html, itemprop: "size")
        )?.htmlDecoded.trimmed

        return ItemMetadata(
            title: title,
            imageURL: primaryImage,
            alternativeImageURLs: alternativeImages,
            price: price,
            currency: currency,
            description: description,
            brand: brand,
            color: color,
            size: size
        )
    }

    // MARK: - JSON-LD extraction

    private struct JSONLDProduct {
        var name: String?
        var description: String?
        var price: String?
        var priceCurrency: String?
        var brand: String?
        var color: String?
        var size: String?
        var images: [String] = []
    }

    private func parseJSONLD(_ html: String) -> JSONLDProduct {
        var result = JSONLDProduct()

        let nsHTML = html as NSString
        let matches = Self.jsonLDRegex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let jsonString = nsHTML.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }

            // JSON-LD can be a single object or an array
            let objects: [[String: Any]]
            if let array = json as? [[String: Any]] {
                objects = array
            } else if let dict = json as? [String: Any] {
                objects = [dict]
            } else {
                continue
            }

            for obj in objects {
                extractJSONLDProduct(from: obj, into: &result)
                // Also check @graph array
                if let graph = obj["@graph"] as? [[String: Any]] {
                    for node in graph {
                        extractJSONLDProduct(from: node, into: &result)
                    }
                }
            }
        }

        return result
    }

    private func extractJSONLDProduct(from obj: [String: Any], into result: inout JSONLDProduct) {
        let typeValue = obj["@type"]
        let types: [String]
        if let str = typeValue as? String {
            types = [str]
        } else if let arr = typeValue as? [String] {
            types = arr
        } else {
            types = []
        }

        // Only extract from Product-like types
        let productTypes: Set<String> = [
            "Product", "IndividualProduct", "ProductModel",
            "SoftwareApplication", "MobileApplication",
            "Book", "Movie", "MusicAlbum", "VideoGame",
            "Offer", "AggregateOffer"
        ]
        let isProduct = types.contains(where: { productTypes.contains($0) })
        // Also extract if no type (some pages have untyped JSON-LD with product data)
        let hasProductSignals = obj["price"] != nil || obj["offers"] != nil
        guard isProduct || hasProductSignals else { return }

        if result.name == nil, let name = obj["name"] as? String {
            result.name = name
        }
        if result.description == nil, let desc = obj["description"] as? String {
            result.description = desc
        }
        if result.brand == nil {
            if let brand = obj["brand"] as? [String: Any], let name = brand["name"] as? String {
                result.brand = name
            } else if let brand = obj["brand"] as? String {
                result.brand = brand
            }
        }
        if result.color == nil {
            result.color = obj["color"] as? String
        }
        if result.size == nil {
            result.size = obj["size"] as? String
        }

        // Images
        if let image = obj["image"] as? String {
            result.images.append(image)
        } else if let image = obj["image"] as? [String: Any], let url = image["url"] as? String {
            result.images.append(url)
        } else if let images = obj["image"] as? [String] {
            result.images.append(contentsOf: images)
        } else if let images = obj["image"] as? [[String: Any]] {
            for img in images {
                if let url = img["url"] as? String { result.images.append(url) }
            }
        }

        // Price: check offers first, then direct price
        if result.price == nil {
            if let offers = obj["offers"] as? [String: Any] {
                extractPrice(from: offers, into: &result)
            } else if let offers = obj["offers"] as? [[String: Any]], let first = offers.first {
                extractPrice(from: first, into: &result)
            } else {
                extractPrice(from: obj, into: &result)
            }
        }
    }

    private func extractPrice(from offer: [String: Any], into result: inout JSONLDProduct) {
        if let p = offer["price"] as? String {
            result.price = p
        } else if let p = offer["price"] as? NSNumber {
            result.price = p.stringValue
        } else if let p = offer["lowPrice"] as? String {
            result.price = p
        } else if let p = offer["lowPrice"] as? NSNumber {
            result.price = p.stringValue
        }
        if result.priceCurrency == nil {
            result.priceCurrency = offer["priceCurrency"] as? String
        }
    }

    // MARK: - Image collection (deduplicated, scored)

    private func collectImages(html: String, jsonLD: JSONLDProduct, pageURL: URL) -> [URL] {
        var candidates: [(url: URL, score: Int)] = []
        var seen = Set<String>()

        func add(_ raw: String?, score: Int) {
            guard let raw, !raw.isEmpty else { return }
            guard let url = resolveURL(raw, base: pageURL) else { return }
            let key = url.absoluteString
            if seen.contains(key) { return }
            // Skip tiny tracking pixels and icons
            if isLikelyTrackingPixel(raw) { return }
            seen.insert(key)
            candidates.append((url, score))
        }

        // JSON-LD images (highest priority)
        for img in jsonLD.images { add(img, score: 100) }

        // OpenGraph image
        add(ogMeta(html, property: "og:image"), score: 90)
        // Additional OG images
        for img in ogMetaAll(html, property: "og:image") { add(img, score: 85) }

        // Twitter image
        add(ogMeta(html, property: "twitter:image"), score: 80)
        add(ogMeta(html, property: "twitter:image:src"), score: 80)

        // Microdata product images
        for img in itempropImages(html) { add(img, score: 70) }

        // High-resolution <img> tags with product-like attributes
        for img in productImgTags(html) { add(img, score: 60) }

        candidates.sort { $0.score > $1.score }
        return candidates.map(\.url)
    }

    private func isLikelyTrackingPixel(_ raw: String) -> Bool {
        let lower = raw.lowercased()
        let trackers = ["1x1", "pixel", "spacer", "blank", "tracking", "beacon",
                        ".gif", "data:image", "facebook.com/tr", "doubleclick",
                        "googleads", "analytics"]
        return trackers.contains(where: { lower.contains($0) })
    }

    private func resolveURL(_ raw: String, base: URL) -> URL? {
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return URL(string: raw)
        }
        if raw.hasPrefix("//") {
            return URL(string: "https:" + raw)
        }
        return URL(string: raw, relativeTo: base)?.absoluteURL
    }

    // MARK: - URL variant extraction (color / size from query params)

    private struct URLVariants {
        var color: String?
        var size: String?
    }

    private func parseURLVariants(_ url: URL) -> URLVariants {
        var result = URLVariants()
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let items = comps.queryItems else { return result }

        let colorKeys: Set<String> = ["color", "colour", "clr", "selectedcolor",
                                       "dwvar_color", "selected_color", "colorid"]
        let sizeKeys: Set<String> = ["size", "sz", "selectedsize",
                                      "dwvar_size", "selected_size", "sizeid"]

        for item in items {
            let key = item.name.lowercased()
            if result.color == nil && colorKeys.contains(key) {
                result.color = item.value?.removingPercentEncoding?
                    .replacingOccurrences(of: "+", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .localizedCapitalized
            }
            if result.size == nil && sizeKeys.contains(key) {
                result.size = item.value?.removingPercentEncoding?
                    .replacingOccurrences(of: "+", with: " ")
                    .uppercased()
            }
        }

        // Also check path segments: /color/blue or /size/xl patterns
        let pathComponents = url.pathComponents.map { $0.lowercased() }
        for (i, segment) in pathComponents.enumerated() {
            guard i + 1 < pathComponents.count else { continue }
            let next = pathComponents[i + 1]
            if result.color == nil && colorKeys.contains(segment) {
                result.color = next.replacingOccurrences(of: "-", with: " ").localizedCapitalized
            }
            if result.size == nil && sizeKeys.contains(segment) {
                result.size = next.uppercased()
            }
        }

        return result
    }

    // MARK: - HTML tag extraction helpers

    /// Matches <meta property="KEY" content="VALUE"> in either attribute order.
    private func ogMeta(_ html: String, property: String) -> String? {
        let key = NSRegularExpression.escapedPattern(for: property)
        return extractMeta(html, pattern: "property=[\"']\(key)[\"'][^>]*content=[\"']([^\"'<>]+)[\"']")
            ?? extractMeta(html, pattern: "content=[\"']([^\"'<>]+)[\"'][^>]*property=[\"']\(key)[\"']")
    }

    /// All values for a repeated OG property (e.g. multiple og:image tags).
    private func ogMetaAll(_ html: String, property: String) -> [String] {
        let key = NSRegularExpression.escapedPattern(for: property)
        let pattern1 = "property=[\"']\(key)[\"'][^>]*content=[\"']([^\"'<>]+)[\"']"
        let pattern2 = "content=[\"']([^\"'<>]+)[\"'][^>]*property=[\"']\(key)[\"']"
        return extractMetaAll(html, pattern: pattern1) + extractMetaAll(html, pattern: pattern2)
    }

    /// Matches <meta name="KEY" content="VALUE">
    private func metaName(_ html: String, name: String) -> String? {
        let key = NSRegularExpression.escapedPattern(for: name)
        return extractMeta(html, pattern: "name=[\"']\(key)[\"'][^>]*content=[\"']([^\"'<>]+)[\"']")
            ?? extractMeta(html, pattern: "content=[\"']([^\"'<>]+)[\"'][^>]*name=[\"']\(key)[\"']")
    }

    /// Matches <* itemprop="KEY" content="VALUE"> or <* itemprop="KEY">VALUE</*>
    private func itempropContent(_ html: String, itemprop: String) -> String? {
        let key = NSRegularExpression.escapedPattern(for: itemprop)
        return extractMeta(html, pattern: "itemprop=[\"']\(key)[\"'][^>]*content=[\"']([^\"'<>]+)[\"']")
            ?? extractMeta(html, pattern: "itemprop=[\"']\(key)[\"'][^>]*>([^<]{1,200})<")
    }

    /// Finds <img itemprop="image" src="..."> or <* itemprop="image" content="...">.
    private func itempropImages(_ html: String) -> [String] {
        var results: [String] = []
        // content attribute
        results.append(contentsOf: extractMetaAll(html,
            pattern: #"itemprop=["']image["'][^>]*content=["']([^"'<>]+)["']"#))
        // src attribute
        results.append(contentsOf: extractMetaAll(html,
            pattern: #"itemprop=["']image["'][^>]*src=["']([^"'<>]+)["']"#))
        // href attribute (for <link itemprop="image">)
        results.append(contentsOf: extractMetaAll(html,
            pattern: #"itemprop=["']image["'][^>]*href=["']([^"'<>]+)["']"#))
        return results
    }

    /// Finds <img> tags that look like product images (large, within product containers).
    private func productImgTags(_ html: String) -> [String] {
        // Match img tags with product-related classes/ids and src attributes
        let patterns: [String] = [
            // Images with product-related class names
            #"<img[^>]*class=["'][^"']*(?:product|main|hero|primary|gallery|zoom)[^"']*["'][^>]*src=["']([^"'<>]+)["']"#,
            #"<img[^>]*src=["']([^"'<>]+)["'][^>]*class=["'][^"']*(?:product|main|hero|primary|gallery|zoom)[^"']*["']"#,
            // Images with data-zoom or data-large (common on e-commerce sites)
            #"<img[^>]*data-(?:zoom|large|src|hi-res|zoom-image)=["']([^"'<>]+)["']"#,
        ]
        var results: [String] = []
        for pattern in patterns {
            results.append(contentsOf: extractMetaAll(html, pattern: pattern).prefix(4))
        }
        return results
    }

    /// Finds a price in common HTML selectors (fallback when meta/JSON-LD missing).
    private func htmlPriceSelector(_ html: String) -> String? {
        let patterns: [String] = [
            // Common price selectors
            #"class=["'][^"']*(?:price|Price|product-price|sale-price|current-price|offer-price)[^"']*["'][^>]*>[\s$€£¥]*([0-9][0-9,.\s]*[0-9])"#,
            // data-price attribute
            #"data-price=["']([0-9]+(?:[.,][0-9]{1,2})?)["']"#,
            // Inline price patterns: $XX.XX or €XX,XX
            #"<span[^>]*>[\s]*[$€£¥]\s*([0-9]{1,7}(?:[.,][0-9]{1,2})?)\s*</span>"#,
        ]
        for pattern in patterns {
            if let price = extractMeta(html, pattern: pattern) {
                // Sanity check: price should be a reasonable number
                let cleaned = price.replacingOccurrences(of: ",", with: ".")
                    .replacingOccurrences(of: " ", with: "")
                    .filter { "0123456789.".contains($0) }
                if let value = Double(cleaned), value > 0, value < 1_000_000 {
                    return cleaned
                }
            }
        }
        return nil
    }

    private func htmlTitle(_ html: String) -> String? {
        extractMeta(html, pattern: "<title[^>]*>([^<]{1,200})</title>")
    }

    // MARK: - Regex utilities

    private func extractMeta(_ html: String, pattern: String) -> String? {
        guard let regex = Self.compiledRegex(for: pattern) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: html) else { return nil }
        let value = String(html[captureRange])
        return value.isEmpty ? nil : value
    }

    private func extractMetaAll(_ html: String, pattern: String) -> [String] {
        guard let regex = Self.compiledRegex(for: pattern) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        var results: [String] = []
        for match in matches where match.numberOfRanges > 1 {
            if let captureRange = Range(match.range(at: 1), in: html) {
                let value = String(html[captureRange])
                if !value.isEmpty { results.append(value) }
            }
        }
        return results
    }

    // MARK: - Decimal parsing

    private func parseDecimal(_ raw: String) -> Decimal? {
        // Handle different number formats: "1,299.99", "1.299,99", "1299.99"
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.filter { "0123456789.,".contains($0) }

        // Detect European format (comma as decimal): "19,99" or "1.299,99"
        if let lastComma = cleaned.lastIndex(of: ","),
           let lastDot = cleaned.lastIndex(of: ".") {
            if lastComma > lastDot {
                // European: 1.299,99 → 1299.99
                cleaned = cleaned.replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            } else {
                // US: 1,299.99 → 1299.99
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        } else if cleaned.contains(",") {
            // Only commas: could be "1,299" (thousands) or "19,99" (European decimal)
            let parts = cleaned.components(separatedBy: ",")
            if let last = parts.last, last.count == 2, parts.count == 2 {
                // Likely European decimal: "19,99"
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                // Likely thousands separator: "1,299"
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        }

        return Decimal(string: cleaned)
    }
}

// MARK: - HTML entity decoding

// Compiled once — reused for every htmlDecoded call across the app session.
private let numericEntityRegex: NSRegularExpression = {
    // swiftlint:disable:next force_try
    try! NSRegularExpression(pattern: "&#([0-9]{1,6});")
}()

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var htmlDecoded: String {
        var s = self
        let namedEntities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&nbsp;", "\u{00A0}"), ("&ndash;", "\u{2013}"), ("&mdash;", "\u{2014}"),
            ("&lsquo;", "\u{2018}"), ("&rsquo;", "\u{2019}"),
            ("&ldquo;", "\u{201C}"), ("&rdquo;", "\u{201D}"),
        ]
        for (entity, char) in namedEntities {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        // Numeric decimal entities &#123; — regex compiled once at module load.
        let ns = s as NSString
        var result = ""
        var lastEnd = 0
        let matches = numericEntityRegex.matches(in: s, range: NSRange(s.startIndex..., in: s))
        for m in matches {
            let range = Range(m.range, in: s)!
            result += s[s.index(s.startIndex, offsetBy: lastEnd)..<range.lowerBound]
            if let codeRange = Range(m.range(at: 1), in: s),
               let code = UInt32(s[codeRange]),
               let scalar = Unicode.Scalar(code) {
                result += String(scalar)
            } else {
                result += ns.substring(with: m.range)
            }
            lastEnd = s.distance(from: s.startIndex, to: range.upperBound)
        }
        if !matches.isEmpty {
            result += s[s.index(s.startIndex, offsetBy: lastEnd)...]
            s = result
        }
        return s
    }
}
