import Foundation
import SwiftData
import WidgetKit

/// Writes a lightweight snapshot of wishlist data to the App Group container
/// so the WidgetKit extension can read it without accessing SwiftData.
enum WidgetDataService {

    private static let appGroupID = "group.com.yaremchuk.app"
    private static let key = "widgetData"

    /// Coalescing task — cancels previous pending update so we only run once.
    @MainActor private static var pendingUpdate: Task<Void, Never>?

    /// Debounced update — coalesces rapid calls into a single snapshot 500ms later.
    @MainActor
    static func scheduleUpdate(context: ModelContext) {
        pendingUpdate?.cancel()
        pendingUpdate = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            updateSnapshot(context: context)
        }
    }

    /// Builds a snapshot from the current SwiftData state and writes it to App Group UserDefaults.
    @MainActor
    static func updateSnapshot(context: ModelContext) {
        let currency = UserDefaults.standard.string(forKey: "defaultCurrency") ?? "USD"

        let lists: [WishList]
        let items: [WishItem]

        do {
            lists = try context.fetch(FetchDescriptor<WishList>())
            items = try context.fetch(FetchDescriptor<WishItem>())
        } catch {
            return
        }

        let activeLists = lists.filter { !$0.isArchived }
        let activeItems = items.filter { $0.list?.isArchived != true }
        let unpurchased = activeItems.filter { !$0.isPurchased }

        // Total remaining value in display currency
        let totalRemaining = unpurchased.compactMap { item -> Double? in
            guard let price = item.price else { return nil }
            let converted = convertCurrency(price, from: item.currency ?? "USD", to: currency)
            return NSDecimalNumber(decimal: converted).doubleValue
        }.reduce(0, +)

        // Top 3 by priority (high -> medium -> low), then newest first
        let top3 = topItems(from: unpurchased, currency: currency, limit: 3)

        // Per-list snapshots
        let listSnapshots = activeLists.map { list -> WidgetListData in
            let listItems = activeItems.filter { $0.list?.id == list.id }
            let listUnpurchased = listItems.filter { !$0.isPurchased }

            let remaining = listUnpurchased.compactMap { item -> Double? in
                guard let price = item.price else { return nil }
                let converted = convertCurrency(price, from: item.currency ?? "USD", to: currency)
                return NSDecimalNumber(decimal: converted).doubleValue
            }.reduce(0, +)

            return WidgetListData(
                id: list.id.uuidString,
                name: list.name,
                emoji: list.emoji,
                colorHex: list.colorHex,
                totalItemCount: listItems.count,
                purchasedCount: listItems.filter { $0.isPurchased }.count,
                reservedCount: listItems.filter { $0.isReservedByFriend && !$0.isPurchased }.count,
                remainingValue: remaining,
                topItems: topItems(from: listUnpurchased, currency: currency, limit: 3),
                endDate: list.endDate
            )
        }

        let snapshot = WidgetSnapshotData(
            totalRemainingValue: totalRemaining,
            currency: currency,
            unpurchasedCount: unpurchased.count,
            totalItemCount: activeItems.count,
            purchasedCount: activeItems.filter { $0.isPurchased }.count,
            reservedCount: activeItems.filter { $0.isReservedByFriend && !$0.isPurchased }.count,
            totalListCount: activeLists.count,
            topItems: top3,
            updatedAt: .now,
            lists: listSnapshots
        )

        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = try? JSONEncoder().encode(snapshot)
        else { return }

        defaults.set(data, forKey: key)

        // Also write list metadata for AppIntents EntityQuery
        let listRecords = activeLists.map { IntentsListRecord(id: $0.id, name: $0.name, emoji: $0.emoji) }
        if let listData = try? JSONEncoder().encode(listRecords) {
            defaults.set(listData, forKey: "appIntentsLists")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Helpers

    private static func topItems(from unpurchased: [WishItem], currency: String, limit: Int) -> [WidgetItemData] {
        let priorityOrder: [Priority] = [.high, .medium, .low]
        let sorted = unpurchased.sorted { a, b in
            let ai = priorityOrder.firstIndex(of: a.priority) ?? 2
            let bi = priorityOrder.firstIndex(of: b.priority) ?? 2
            if ai != bi { return ai < bi }
            return a.createdAt > b.createdAt
        }
        return sorted.prefix(limit).map { item in
            WidgetItemData(
                id: item.id.uuidString,
                title: item.title,
                emoji: item.list?.emoji ?? "🎁",
                price: item.price.map { NSDecimalNumber(decimal: $0).doubleValue },
                currency: item.currency,
                priority: item.priority.rawValue,
                isReserved: item.isReservedByFriend
            )
        }
    }
}

private struct IntentsListRecord: Codable {
    let id: UUID
    let name: String
    let emoji: String
}

// MARK: - Mirror of WidgetSnapshot (avoids cross-target dependency)

private struct WidgetSnapshotData: Codable {
    let totalRemainingValue: Double
    let currency: String
    let unpurchasedCount: Int
    let totalItemCount: Int
    let purchasedCount: Int
    let reservedCount: Int
    let totalListCount: Int
    let topItems: [WidgetItemData]
    let updatedAt: Date
    let lists: [WidgetListData]
}

private struct WidgetItemData: Codable {
    let id: String
    let title: String
    let emoji: String
    let price: Double?
    let currency: String?
    let priority: String
    let isReserved: Bool
}

private struct WidgetListData: Codable {
    let id: String
    let name: String
    let emoji: String
    let colorHex: String
    let totalItemCount: Int
    let purchasedCount: Int
    let reservedCount: Int
    let remainingValue: Double
    let topItems: [WidgetItemData]
    let endDate: Date?
}
