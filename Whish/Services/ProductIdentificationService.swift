import DeviceCheck
import Foundation
import Supabase

// MARK: - Result

/// What the identify-product Edge Function found in a photo.
struct ProductIdentification: Codable, Sendable, Equatable {

    enum Status: String, Codable, Sendable {
        case identified
        case similar
        case unclear
        case notAProduct = "not_a_product"

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            // Unknown future values degrade to "unclear" instead of failing the whole response.
            self = Status(rawValue: raw) ?? .unclear
        }
    }

    struct PriceEstimate: Codable, Sendable, Equatable {
        let low: Decimal
        let high: Decimal
        let currency: String

        /// Midpoint rounded to a whole amount, for filling the price field.
        var midpoint: Decimal {
            var mid = (low + high) / 2
            var rounded = Decimal()
            NSDecimalRound(&rounded, &mid, 0, .plain)
            return rounded
        }

        /// "$120–$140", or "$120" when the range is a single value, in the user's locale.
        var rangeText: String { rangeText(locale: .current) }

        func rangeText(locale: Locale) -> String {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .currency
            formatter.currencyCode = currency
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
            if currency == "USD" { formatter.currencySymbol = "$" }
            let lowText = formatter.string(from: low as NSDecimalNumber) ?? "\(low)"
            guard high != low else { return lowText }
            let highText = formatter.string(from: high as NSDecimalNumber) ?? "\(high)"
            return "\(lowText)–\(highText)"
        }
    }

    let status: Status
    let title: String
    let brand: String?
    let model: String?
    let color: String?
    let category: String
    let description: String
    let estimatedPrice: PriceEstimate?
    let searchQuery: String
    let confidence: Double

    var foundProduct: Bool { status == .identified || status == .similar }

    /// Google Shopping search for the item, so the user can find a buyable link.
    var shoppingSearchURL: URL? {
        let query = searchQuery.isEmpty ? title : searchQuery
        guard !query.isEmpty else { return nil }
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: "tbm", value: "shop"),
            URLQueryItem(name: "q", value: query),
        ]
        return components?.url
    }
}

/// The caller's monthly allowance, returned with every response.
struct IdentifyUsage: Codable, Sendable, Equatable {
    let used: Int
    let limit: Int
    let remaining: Int
    /// When the allowance resets (start of next month, UTC).
    let periodEnd: Date
}

struct ProductIdentificationResponse: Decodable, Sendable, Equatable {
    let result: ProductIdentification
    /// Signed-in requests only.
    let usage: IdentifyUsage?
    /// True when this was a signed-out user's one free try.
    var trial: Bool? = nil
    /// Present when a specific product was identified: pass it to `findOffers` for the
    /// photo's one shop search. Expires 15 minutes after the identification.
    var offersToken: String? = nil
}

/// A shop selling the identified product. The price was read from the shop's own
/// page, not taken from search results.
struct ShopOffer: Codable, Sendable, Equatable, Identifiable {
    let store: String
    let url: URL
    /// The page's own title, when the link reader found one.
    let title: String?
    let price: Decimal
    let currency: String
    /// The cheapest of the offers found.
    let best: Bool

    var id: URL { url }

    init(store: String, url: URL, title: String?, price: Decimal, currency: String, best: Bool) {
        self.store = store
        self.url = url
        self.title = title
        self.price = price
        self.currency = currency
        self.best = best
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        store = try container.decode(String.self, forKey: .store)
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        // JSON numbers can arrive with binary noise (114.98999…); prices have cents at most.
        var raw = try container.decode(Decimal.self, forKey: .price)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 2, .plain)
        price = rounded
        currency = try container.decode(String.self, forKey: .currency)
        best = try container.decodeIfPresent(Bool.self, forKey: .best) ?? false
    }

    /// The price as the form's price field holds it, e.g. "114.99".
    var priceInput: String { "\(price)" }

    /// "£114.99" in the user's locale; whole amounts drop the decimals.
    var priceText: String { priceText(locale: .current) }

    func priceText(locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        if currency == "USD" { formatter.currencySymbol = "$" }
        var value = price
        var whole = Decimal()
        NSDecimalRound(&whole, &value, 0, .plain)
        let digits = whole == price ? 0 : 2
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: price as NSDecimalNumber) ?? "\(currency) \(price)"
    }
}

// MARK: - Errors

enum ProductIdentificationError: LocalizedError, Equatable {
    case notSignedIn
    /// A signed-out user already used this device's free try.
    case trialUsed
    case quotaExceeded(IdentifyUsage?)
    case notConfigured
    case busy
    case imageTooLarge
    case invalidImage
    case refused
    case network
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:   return "Sign in to identify photos."
        case .trialUsed:     return "You've used your free try. Sign in to keep identifying photos."
        case .quotaExceeded: return "You've used all your photo identifications for this month."
        case .notConfigured: return "Photo identification isn't available yet."
        case .busy:          return "Photo identification is busy right now. Try again later."
        case .imageTooLarge: return "That photo is too large. Try a smaller one."
        case .invalidImage:  return "Couldn't read this photo. Try another one."
        case .refused:       return "Couldn't identify this photo. Try another one."
        case .network:       return "You're offline or the connection dropped. Try again."
        case .server(let message): return message
        }
    }

    /// Whether tapping "Try again" can help.
    var isRetryable: Bool {
        switch self {
        case .network, .server, .busy: return true
        default: return false
        }
    }
}

// MARK: - Service

protocol ProductIdentificationService: Sendable {
    /// Whether the user has to be signed in (the live service sends their access token).
    var requiresSignIn: Bool { get }
    /// Whether a signed-out user can still use this device's one free try.
    var offersTrial: Bool { get }
    func identify(imageData: Data, currency: String) async throws -> ProductIdentificationResponse
    /// Shops selling an identified product, cheapest first, with prices in `currency`
    /// from shops in `country` (ISO 3166 code). Empty when none could be confirmed.
    func findOffers(token: String, country: String?, currency: String) async throws -> [ShopOffer]
}

extension ProductIdentificationService {
    var requiresSignIn: Bool { true }
    var offersTrial: Bool { false }
    func findOffers(token: String, country: String?, currency: String) async throws -> [ShopOffer] { [] }
}

enum ProductIdentifier {
    /// The service the app should use. Debug builds launched with
    /// `-mockIdentify <scenario>` get canned results instead (see `MockProductIdentificationService`).
    static func makeService() -> any ProductIdentificationService {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "mockIdentify"),
           let scenario = MockProductIdentificationService.Scenario(rawValue: raw) {
            return MockProductIdentificationService(scenario: scenario)
        }
        #endif
        return LiveProductIdentificationService()
    }
}

/// Calls the identify-product Edge Function with the signed-in user's token.
struct LiveProductIdentificationService: ProductIdentificationService {

    static let endpoint = URL(
        string: "\(SupabaseConfig.projectURL.absoluteString)/functions/v1/identify-product"
    )!

    /// Long edge of the photo sent for identification. Matches the 1200 px photos
    /// Gimme already stores, which keeps each request around 1–2k image tokens.
    static let maxDimension: CGFloat = 1200

    /// Set once this device's free try is spent. A hint only: Apple DeviceCheck,
    /// checked by the server, is what actually enforces one try per device.
    static let trialUsedKey = "photoIdentifyTrialUsed"

    /// DeviceCheck tokens from Xcode builds are only valid on Apple's development server.
    private static var deviceCheckEnvironment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }

    /// DeviceCheck isn't available in the Simulator, so there's no free try there.
    var offersTrial: Bool {
        DCDevice.current.isSupported && !UserDefaults.standard.bool(forKey: Self.trialUsedKey)
    }

    func identify(imageData: Data, currency: String) async throws -> ProductIdentificationResponse {
        let session = try? await supabase.auth.session
        var deviceToken: String?
        if session == nil {
            // Signed out: this is the free try, proven with a DeviceCheck token.
            guard offersTrial, let token = try? await DCDevice.current.generateToken() else {
                throw ProductIdentificationError.notSignedIn
            }
            deviceToken = token.base64EncodedString()
        }
        guard let jpeg = ImageCompressor.compress(imageData, maxDimension: Self.maxDimension, quality: 0.8) else {
            throw ProductIdentificationError.invalidImage
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(RequestBody(
            image: jpeg.base64EncodedString(),
            mediaType: "image/jpeg",
            currency: currency,
            deviceToken: deviceToken,
            deviceCheckEnvironment: deviceToken == nil ? nil : Self.deviceCheckEnvironment
        ))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ProductIdentificationError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        do {
            let decoded = try IdentifyResponseDecoder.decode(status: status, data: data)
            if decoded.trial == true { Self.markTrialUsed() }
            return decoded
        } catch let error as ProductIdentificationError {
            if deviceToken != nil && Self.spendsFreeTry(error) { Self.markTrialUsed() }
            throw error
        }
    }

    /// Whether a signed-out request that failed with `error` still used up the free try.
    /// The server keeps the try spent after a refusal (the model call was paid for) and
    /// gives it back after failures it caused, like an outage or unreadable output.
    static func spendsFreeTry(_ error: ProductIdentificationError) -> Bool {
        error == .trialUsed || error == .refused
    }

    private static func markTrialUsed() {
        UserDefaults.standard.set(true, forKey: trialUsedKey)
    }

    /// The token is the credential, so this works signed out too (after the free try).
    func findOffers(token: String, country: String?, currency: String) async throws -> [ShopOffer] {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        // A web search plus a look at each shop's page; the server gives up within ~2 minutes.
        request.timeoutInterval = 140
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(OffersRequestBody(
            offersToken: token, country: country, currency: currency
        ))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ProductIdentificationError.network
        }
        return try OffersResponseDecoder.decode(status: (response as? HTTPURLResponse)?.statusCode ?? 0, data: data)
    }

    private struct RequestBody: Encodable {
        let image: String
        let mediaType: String
        let currency: String
        let deviceToken: String?
        let deviceCheckEnvironment: String?
    }

    private struct OffersRequestBody: Encodable {
        let offersToken: String
        let country: String?
        let currency: String
    }
}

/// Turns a shop search response into offers or an error.
enum OffersResponseDecoder {

    private struct Body: Decodable {
        let offers: [ShopOffer]
    }

    private struct FailureBody: Decodable {
        let code: String?
        let error: String?
    }

    static func decode(status: Int, data: Data) throws -> [ShopOffer] {
        guard (200..<300).contains(status) else {
            let failure = try? JSONDecoder().decode(FailureBody.self, from: data)
            throw ProductIdentificationError.server(failure?.error ?? "Couldn't search shops (\(status)).")
        }
        do {
            return try JSONDecoder().decode(Body.self, from: data).offers
        } catch {
            throw ProductIdentificationError.server("Couldn't read the shops.")
        }
    }
}

/// Turns an Edge Function response into a result or a typed error.
enum IdentifyResponseDecoder {

    private struct FailureBody: Decodable {
        let code: String?
        let error: String?
        let usage: IdentifyUsage?
    }

    static func decode(status: Int, data: Data) throws -> ProductIdentificationResponse {
        let decoder = makeDecoder()
        if (200..<300).contains(status) {
            do {
                return try decoder.decode(ProductIdentificationResponse.self, from: data)
            } catch {
                throw ProductIdentificationError.server("Couldn't read the result. Try again.")
            }
        }

        let failure = try? decoder.decode(FailureBody.self, from: data)
        switch failure?.code {
        case "unauthorized":    throw ProductIdentificationError.notSignedIn
        case "trial_used":      throw ProductIdentificationError.trialUsed
        case "quota_exceeded":  throw ProductIdentificationError.quotaExceeded(failure?.usage)
        case "not_configured":  throw ProductIdentificationError.notConfigured
        case "busy":            throw ProductIdentificationError.busy
        case "image_too_large": throw ProductIdentificationError.imageTooLarge
        case "bad_request":     throw ProductIdentificationError.invalidImage
        case "refused":         throw ProductIdentificationError.refused
        default:
            if status == 401 { throw ProductIdentificationError.notSignedIn }
            throw ProductIdentificationError.server(failure?.error ?? "Something went wrong (\(status)). Try again.")
        }
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Bad date: \(raw)"))
        }
        return decoder
    }
}

// MARK: - Form pre-fill

/// How an identification fills the Add Item form. Like product-URL metadata,
/// it only fills fields the user hasn't typed into.
struct IdentifyPrefill: Equatable {
    var title: String?
    var notes: String?
    var brand: String?
    var color: String?

    static func make(from result: ProductIdentification, currentTitle: String, currentNotes: String) -> IdentifyPrefill {
        guard result.foundProduct else { return IdentifyPrefill() }
        let titleIsEmpty = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let notesAreEmpty = currentNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let description = result.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return IdentifyPrefill(
            title: titleIsEmpty && !result.title.isEmpty ? result.title : nil,
            notes: notesAreEmpty && !description.isEmpty ? description : nil,
            brand: result.brand,
            color: result.color
        )
    }
}

// MARK: - Mock (debug builds only)

#if DEBUG
/// Canned results for previews, UI checks and working without the backend.
/// Launch with `-mockIdentify identified` (or no_offers, similar, not_product, quota,
/// offline, trial, trial_used). `identified` also finds three shops a few seconds
/// later; `no_offers` finds none. `trial` behaves like a signed-out device's one free
/// try: it needs sign-in afterwards, until the app is reinstalled.
struct MockProductIdentificationService: ProductIdentificationService {

    enum Scenario: String {
        case identified
        case noOffers = "no_offers"
        case similar
        case notProduct = "not_product"
        case quota
        case offline
        case trial
        case trialUsed = "trial_used"
    }

    static let offers: [ShopOffer] = [
        ShopOffer(store: "Foot Locker", url: URL(string: "https://www.example.com/footlocker/air-max-90")!,
                  title: "Nike Air Max 90", price: Decimal(string: "114.99")!, currency: "USD", best: true),
        ShopOffer(store: "JD Sports", url: URL(string: "https://www.example.com/jdsports/air-max-90")!,
                  title: "Nike Air Max 90", price: Decimal(string: "119.99")!, currency: "USD", best: false),
        ShopOffer(store: "Nike", url: URL(string: "https://www.example.com/nike/air-max-90")!,
                  title: "Nike Air Max 90 Shoes", price: 130, currency: "USD", best: false),
    ]

    func findOffers(token: String, country: String?, currency: String) async throws -> [ShopOffer] {
        try await Task.sleep(for: .milliseconds(2500))
        return scenario == .noOffers ? [] : Self.offers
    }

    let scenario: Scenario
    var requiresSignIn: Bool { scenario == .trial || scenario == .trialUsed }
    var offersTrial: Bool {
        switch scenario {
        case .trial: return !UserDefaults.standard.bool(forKey: LiveProductIdentificationService.trialUsedKey)
        case .trialUsed: return true   // the app thinks there's a try left; the server says otherwise
        default: return false
        }
    }

    static let sneakers = ProductIdentification(
        status: .identified,
        title: "Nike Air Max 90",
        brand: "Nike",
        model: "Air Max 90",
        color: "White/Infrared",
        category: "Sneakers",
        description: "Classic low-top running sneaker with a visible Air unit in the heel.",
        estimatedPrice: .init(low: 120, high: 140, currency: "USD"),
        searchQuery: "Nike Air Max 90 white infrared",
        confidence: 0.92
    )

    func identify(imageData: Data, currency: String) async throws -> ProductIdentificationResponse {
        try await Task.sleep(for: .milliseconds(1200))
        let usage = IdentifyUsage(used: 2, limit: 5, remaining: 3,
                                  periodEnd: Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now)
        switch scenario {
        case .identified, .noOffers:
            return .init(result: Self.sneakers, usage: usage, offersToken: "mock-offers")
        case .similar:
            return .init(result: .init(
                status: .similar, title: "Grey wool beanie with leather patch", brand: nil, model: nil,
                color: "Grey", category: "Hats", description: "Ribbed knit beanie with a small brown leather patch.",
                estimatedPrice: .init(low: 20, high: 35, currency: currency),
                searchQuery: "grey wool beanie leather patch", confidence: 0.55
            ), usage: usage)
        case .notProduct:
            return .init(result: .init(
                status: .notAProduct, title: "", brand: nil, model: nil, color: nil, category: "",
                description: "A landscape photo with no product in it.", estimatedPrice: nil,
                searchQuery: "", confidence: 0.9
            ), usage: usage)
        case .quota:
            throw ProductIdentificationError.quotaExceeded(
                IdentifyUsage(used: 5, limit: 5, remaining: 0, periodEnd: usage.periodEnd)
            )
        case .offline:
            throw ProductIdentificationError.network
        case .trial:
            UserDefaults.standard.set(true, forKey: LiveProductIdentificationService.trialUsedKey)
            return .init(result: Self.sneakers, usage: nil, trial: true, offersToken: "mock-offers")
        case .trialUsed:
            throw ProductIdentificationError.trialUsed
        }
    }
}
#endif
