import Foundation
import Testing
@testable import Whish

struct PriceTrackingTests {

    // MARK: - Drop rule

    @Test func notifiesOnFivePercentDrop() {
        #expect(PriceDropRule.shouldNotify(reference: 100, current: 95))
        #expect(PriceDropRule.shouldNotify(reference: 100, current: 80))
    }

    @Test func staysQuietBelowThreshold() {
        #expect(!PriceDropRule.shouldNotify(reference: 100, current: 96))
        #expect(!PriceDropRule.shouldNotify(reference: 100, current: 99.99))
    }

    @Test func ignoresRisesAndMissingReference() {
        #expect(!PriceDropRule.shouldNotify(reference: 100, current: 110))
        #expect(!PriceDropRule.shouldNotify(reference: nil, current: 50))
        #expect(!PriceDropRule.shouldNotify(reference: 0, current: 0))
    }

    // MARK: - History

    @Test func dedupesConsecutiveIdenticalPrices() {
        var history = PriceDropRule.appended([], price: 100)
        history = PriceDropRule.appended(history, price: 100)
        history = PriceDropRule.appended(history, price: 100.005)
        #expect(history.count == 1)
        history = PriceDropRule.appended(history, price: 90)
        #expect(history.count == 2)
    }

    @Test func capsHistoryLength() {
        var history: [PricePoint] = []
        for i in 0..<200 {
            history = PriceDropRule.appended(history, price: Double(i))
        }
        #expect(history.count == 120)
        #expect(history.first?.price == 80)
        #expect(history.last?.price == 199)
    }

    // MARK: - Item helpers

    @Test func dropFractionAgainstBaseline() {
        let item = WishItem(title: "Test", url: "https://example.com", price: 80, currency: "USD")
        item.priceHistory = [
            PricePoint(date: .now.addingTimeInterval(-86_400), price: 100),
            PricePoint(date: .now, price: 80)
        ]
        #expect(item.hasPriceDrop)
        #expect(abs((item.priceDropFraction ?? 0) - 0.2) < 0.001)
        #expect(item.baselinePrice == Decimal(100))
    }

    @Test func noDropWithoutHistory() {
        let item = WishItem(title: "Test", price: 80)
        #expect(!item.hasPriceDrop)
        #expect(item.priceDropFraction == nil)
    }

    @Test func seedingOnlyHappensOnce() {
        let item = WishItem(title: "Test", url: "https://example.com", price: 50, currency: "USD")
        item.seedPriceHistoryIfNeeded()
        #expect(item.priceHistory.count == 1)
        item.price = 40
        item.seedPriceHistoryIfNeeded()
        #expect(item.priceHistory.count == 1)
        #expect(item.priceHistory.first?.price == 50)
    }

    @Test func trackabilityRequiresURLAndPrice() {
        #expect(WishItem(title: "A", url: "https://x.com", price: 10).canTrackPrice)
        #expect(!WishItem(title: "B", price: 10).canTrackPrice)
        #expect(!WishItem(title: "C", url: "https://x.com").canTrackPrice)
        let purchased = WishItem(title: "D", url: "https://x.com", price: 10, isPurchased: true)
        #expect(!purchased.canTrackPrice)
    }

    // MARK: - Sweep cadence

    @Test @MainActor func isDueRespectsCadenceAndBackoff() {
        let item = WishItem(title: "T", url: "https://x.com", price: 10)
        #expect(PriceTrackingService.isDue(item))            // never checked
        item.lastPriceCheckAt = .now.addingTimeInterval(-10 * 3_600)
        #expect(!PriceTrackingService.isDue(item))           // checked 10h ago
        item.lastPriceCheckAt = .now.addingTimeInterval(-24 * 3_600)
        #expect(PriceTrackingService.isDue(item))            // daily cadence
        item.priceCheckFailureCount = 3
        item.lastPriceCheckAt = .now.addingTimeInterval(-2 * 86_400)
        #expect(!PriceTrackingService.isDue(item))           // backing off weekly
        item.lastPriceCheckAt = .now.addingTimeInterval(-8 * 86_400)
        #expect(PriceTrackingService.isDue(item))
    }
}
