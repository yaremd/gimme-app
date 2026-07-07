import BackgroundTasks
import Foundation
import SwiftData

/// On-device price tracking (Phase 1).
///
/// Re-fetches product metadata for tracked items through the same pipeline used
/// when adding items (edge function first, direct fallback), records a compact
/// price history, and fires a local notification when a price drops meaningfully.
/// Sweeps run on app foreground (throttled) and from a background app-refresh task.
@MainActor
final class PriceTrackingService {

    static let shared = PriceTrackingService()
    private init() {}

    static let backgroundTaskID = "com.yaremchuk.app.price-refresh"
    static let freeTrackedLimit = 3

    /// Master switch surfaced in Settings — defaults to on.
    static var alertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "priceAlertsEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "priceAlertsEnabled") }
    }

    private let metadataService: any MetadataService = LiveMetadataService()
    private var isSweeping = false
    private static let lastSweepKey = "lastPriceSweepAt"

    // MARK: - Free-tier slots

    static func trackedCount(in context: ModelContext) -> Int {
        let tracked = FetchDescriptor<WishItem>(
            predicate: #Predicate { $0.isPriceTrackingEnabled == true }
        )
        return (try? context.fetchCount(tracked)) ?? 0
    }

    static func canTrackMore(isPro: Bool, in context: ModelContext) -> Bool {
        isPro || trackedCount(in: context) < freeTrackedLimit
    }

    /// Enables tracking on a freshly added item when a slot is available.
    static func autoEnroll(_ item: WishItem, isPro: Bool, in context: ModelContext) {
        guard item.canTrackPrice, !item.isPriceTrackingEnabled,
              canTrackMore(isPro: isPro, in: context) else { return }
        item.isPriceTrackingEnabled = true
        item.seedPriceHistoryIfNeeded()
    }

    // MARK: - Sweeps

    /// Foreground entry point — at most one sweep per 4 hours.
    func sweepIfDue(context: ModelContext) async {
        if let last = UserDefaults.standard.object(forKey: Self.lastSweepKey) as? Date,
           Date.now.timeIntervalSince(last) < 4 * 3_600 { return }
        await sweep(context: context)
    }

    /// Checks every due item, bounded per sweep, a few fetches in flight.
    func sweep(context: ModelContext, limit: Int = 25) async {
        guard !isSweeping else { return }
        isSweeping = true
        defer { isSweeping = false }
        UserDefaults.standard.set(Date.now, forKey: Self.lastSweepKey)

        let tracked = (try? context.fetch(FetchDescriptor<WishItem>(
            predicate: #Predicate {
                $0.isPriceTrackingEnabled == true
                    && $0.isPurchased == false
                    && $0.isArchived == false
            }
        ))) ?? []
        let due = Array(tracked.filter { Self.isDue($0) }.prefix(limit))
        guard !due.isEmpty else { return }

        let jobs: [(id: UUID, url: URL)] = due.compactMap { item in
            guard let raw = item.url, let url = URL(string: raw) else { return nil }
            return (item.id, url)
        }

        var fetched: [UUID: ItemMetadata] = [:]
        await withTaskGroup(of: (UUID, ItemMetadata?).self) { group in
            let maxConcurrent = 3
            var next = 0
            func enqueue() {
                guard next < jobs.count, !Task.isCancelled else { return }
                let job = jobs[next]
                next += 1
                let service = metadataService
                group.addTask { (job.id, try? await service.fetch(url: job.url)) }
            }
            for _ in 0..<min(maxConcurrent, jobs.count) { enqueue() }
            for await (id, metadata) in group {
                if let metadata { fetched[id] = metadata }
                enqueue()
            }
        }

        for item in due {
            if let metadata = fetched[item.id] {
                await apply(metadata, to: item)
            } else {
                item.lastPriceCheckAt = .now
                item.priceCheckFailureCount += 1
            }
        }
        try? context.save()
    }

    /// Manual "Check now" from item detail. Returns false when the fetch failed.
    @discardableResult
    func checkNow(_ item: WishItem, context: ModelContext) async -> Bool {
        guard let raw = item.url, let url = URL(string: raw),
              let metadata = try? await metadataService.fetch(url: url) else {
            item.lastPriceCheckAt = .now
            item.priceCheckFailureCount += 1
            try? context.save()
            return false
        }
        await apply(metadata, to: item)
        try? context.save()
        return true
    }

    // MARK: - Background refresh

    /// Submits the next background refresh request. Call when the app backgrounds.
    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3_600)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Body of the `.backgroundTask(.appRefresh:)` scene handler.
    func backgroundSweep(container: ModelContainer) async {
        Self.scheduleBackgroundRefresh()
        await sweep(context: ModelContext(container), limit: 10)
    }

    // MARK: - Applying results

    /// Daily cadence; items that keep failing drop to weekly.
    static func isDue(_ item: WishItem, now: Date = .now) -> Bool {
        guard item.canTrackPrice else { return false }
        guard let last = item.lastPriceCheckAt else { return true }
        let interval: TimeInterval = item.priceCheckFailureCount >= 3 ? 7 * 86_400 : 20 * 3_600
        return now.timeIntervalSince(last) >= interval
    }

    private func apply(_ metadata: ItemMetadata, to item: WishItem) async {
        item.lastPriceCheckAt = .now
        guard let newPrice = metadata.price else {
            // Page loaded but price extraction failed — counts toward backoff.
            item.priceCheckFailureCount += 1
            return
        }
        item.priceCheckFailureCount = 0
        let newDouble = NSDecimalNumber(decimal: newPrice).doubleValue

        // Currency flip (geo/site change): restart the baseline, never alert.
        if let old = item.currency, let new = metadata.currency, old != new {
            item.price = newPrice
            item.currency = new
            item.priceHistory = [PricePoint(date: .now, price: newDouble)]
            item.lastNotifiedPriceDouble = nil
            markDirty(item)
            return
        }

        let reference = item.lastNotifiedPriceDouble ?? item.priceHistory.first?.price
        item.priceHistory = PriceDropRule.appended(item.priceHistory, price: newDouble)
        if item.price != newPrice {
            item.price = newPrice
            markDirty(item)
        }

        if Self.alertsEnabled, PriceDropRule.shouldNotify(reference: reference, current: newDouble) {
            item.lastNotifiedPriceDouble = newDouble
            await NotificationService.shared.sendPriceDropAlert(
                itemID: item.id,
                listID: item.list?.id,
                itemTitle: item.title,
                oldPrice: reference.map { Decimal($0) } ?? newPrice,
                newPrice: newPrice,
                currency: item.currency
            )
        }
    }

    private func markDirty(_ item: WishItem) {
        item.needsSync = true
        item.updatedAt = .now
    }
}
