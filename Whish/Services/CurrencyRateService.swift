import Foundation

/// Fetches live FX rates from open.er-api.com and caches them in UserDefaults.
/// Falls back to the static `fxRatesFallback` table when no cache exists.
enum CurrencyRateService {

    private static let apiURL = URL(string: "https://open.er-api.com/v6/latest/USD")!
    private static let cacheKey = "cachedFxRates"
    private static let timestampKey = "fxLastUpdated"
    private static let throttleInterval: TimeInterval = 86_400 // 24 hours

    /// Fetches new rates only if the cache is older than 24 hours (or empty).
    static func refreshIfNeeded() async {
        let lastUpdated = UserDefaults.standard.double(forKey: timestampKey)
        let elapsed = Date().timeIntervalSince1970 - lastUpdated
        guard elapsed > throttleInterval || lastUpdated == 0 else { return }
        await refresh()
    }

    /// Forces a fresh fetch regardless of cache age.
    static func refresh() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: apiURL)
            let response = try JSONDecoder().decode(RateResponse.self, from: data)
            if let encoded = try? JSONEncoder().encode(response.rates) {
                UserDefaults.standard.set(encoded, forKey: cacheKey)
            }
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timestampKey)
            invalidateFXCache()
        } catch {
            // Network failure — silently keep existing/fallback rates
        }
    }

    private struct RateResponse: Decodable {
        let rates: [String: Double]
    }
}
