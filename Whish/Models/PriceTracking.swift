import Foundation

/// One observed price at a point in time. History is stored oldest-first.
struct PricePoint: Codable, Equatable, Sendable {
    let date: Date
    let price: Double
}

/// Pure decision rules for price tracking — free of model/UI so they're unit-testable.
enum PriceDropRule {
    /// Minimum relative drop (vs. the reference price) that triggers an alert.
    static let notifyThreshold = 0.05
    /// Guards against float noise being read as a price change.
    static let epsilon = 0.009

    /// Whether a drop to `current` deserves a notification.
    /// `reference` is the last price we alerted about, else the tracking baseline.
    static func shouldNotify(reference: Double?, current: Double) -> Bool {
        guard let reference, reference > 0 else { return false }
        let drop = reference - current
        return drop > epsilon && drop / reference >= notifyThreshold
    }

    /// Appends `price` to `history`, skipping consecutive identical prices and
    /// capping length so storage stays compact.
    static func appended(_ history: [PricePoint], price: Double,
                         at date: Date = .now, cap: Int = 120) -> [PricePoint] {
        if let last = history.last, abs(last.price - price) <= epsilon {
            return history
        }
        var updated = history + [PricePoint(date: date, price: price)]
        if updated.count > cap { updated.removeFirst(updated.count - cap) }
        return updated
    }
}

/// One-glance answer to "is this a good price?" — banded against the
/// lowest/highest prices seen so far (Google Shopping's insights pattern).
enum PriceVerdict: Equatable {
    case lowestYet
    case goodPrice
    case typical
    case higherThanUsual

    /// nil when there isn't enough variation to judge — fewer than two
    /// history points, or a range under 1% of the high.
    static func evaluate(history: [PricePoint], current: Double) -> PriceVerdict? {
        let prices = history.map(\.price)
        guard prices.count >= 2,
              let low = prices.min(), let high = prices.max(),
              high - low > PriceDropRule.epsilon,
              (high - low) / high >= 0.01
        else { return nil }

        if current <= low + PriceDropRule.epsilon { return .lowestYet }
        let position = (current - low) / (high - low)
        if position <= 0.33 { return .goodPrice }
        if position >= 0.90 { return .higherThanUsual }
        return .typical
    }
}

extension WishItem {

    /// Verdict for the current price, nil when history is too flat to judge.
    var priceVerdict: PriceVerdict? {
        guard let current = price.map({ NSDecimalNumber(decimal: $0).doubleValue }) else { return nil }
        return PriceVerdict.evaluate(history: priceHistory, current: current)
    }

    var priceHistory: [PricePoint] {
        get {
            guard let priceHistoryData else { return [] }
            return (try? JSONDecoder().decode([PricePoint].self, from: priceHistoryData)) ?? []
        }
        set {
            priceHistoryData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue)
        }
    }

    /// Price when tracking started — the reference for "was/now" and drop badges.
    var baselinePrice: Decimal? {
        priceHistory.first.map { Decimal($0.price) }
    }

    /// 0.12 = current price is 12% below the baseline. nil when there's no drop.
    var priceDropFraction: Double? {
        guard let baseline = priceHistory.first?.price, baseline > 0,
              let current = price.map({ NSDecimalNumber(decimal: $0).doubleValue })
        else { return nil }
        let drop = (baseline - current) / baseline
        return drop > 0.001 ? drop : nil
    }

    /// True when the drop is big enough to surface in UI (card badge, was/now price).
    var hasPriceDrop: Bool {
        (priceDropFraction ?? 0) >= PriceDropRule.notifyThreshold
    }

    /// An item needs a URL and a detected price to be trackable.
    var canTrackPrice: Bool {
        url != nil && price != nil && !isPurchased && !isArchived
    }

    /// Starts history at the current price when tracking turns on.
    func seedPriceHistoryIfNeeded() {
        guard priceHistory.isEmpty,
              let current = price.map({ NSDecimalNumber(decimal: $0).doubleValue })
        else { return }
        priceHistory = [PricePoint(date: .now, price: current)]
    }
}
