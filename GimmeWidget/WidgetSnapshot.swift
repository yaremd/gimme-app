import Foundation

/// Lightweight snapshot of wishlist data shared between the main app and widget
/// via App Group UserDefaults. The main app writes this; the widget reads it.
struct WidgetSnapshot: Codable {
    let totalRemainingValue: Double
    let currency: String
    let unpurchasedCount: Int
    let totalItemCount: Int
    let purchasedCount: Int
    let reservedCount: Int
    let totalListCount: Int
    let topItems: [WidgetItem]
    let updatedAt: Date
    /// Per-list snapshots keyed by list UUID string.
    let lists: [WidgetListSnapshot]

    /// Completion fraction 0…1.
    var completionFraction: Double {
        guard totalItemCount > 0 else { return 0 }
        return Double(purchasedCount) / Double(totalItemCount)
    }

    /// Find a specific list snapshot by ID.
    func list(for id: String) -> WidgetListSnapshot? {
        lists.first { $0.id == id }
    }

    static let empty = WidgetSnapshot(
        totalRemainingValue: 0,
        currency: "USD",
        unpurchasedCount: 0,
        totalItemCount: 0,
        purchasedCount: 0,
        reservedCount: 0,
        totalListCount: 0,
        topItems: [],
        updatedAt: .distantPast,
        lists: []
    )

    static let appGroupID = "group.com.yaremchuk.app"
    static let userDefaultsKey = "widgetData"

    static func load() -> WidgetSnapshot {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = defaults.data(forKey: userDefaultsKey),
            let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}

struct WidgetItem: Codable, Identifiable {
    let id: String
    let title: String
    let emoji: String
    let price: Double?
    let currency: String?
    let priority: String
    let isReserved: Bool
}

/// Per-list snapshot for configurable widgets.
struct WidgetListSnapshot: Codable, Identifiable {
    let id: String
    let name: String
    let emoji: String
    let colorHex: String
    let totalItemCount: Int
    let purchasedCount: Int
    let reservedCount: Int
    let remainingValue: Double
    let topItems: [WidgetItem]
    let endDate: Date?

    var completionFraction: Double {
        guard totalItemCount > 0 else { return 0 }
        return Double(purchasedCount) / Double(totalItemCount)
    }

    var unpurchasedCount: Int { totalItemCount - purchasedCount }

    /// Days until endDate, nil if no deadline.
    var daysUntilDeadline: Int? {
        guard let endDate, endDate > .now else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: endDate).day
    }
}
