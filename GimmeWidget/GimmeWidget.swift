import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct GimmeEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// Selected list ID from widget config, nil = all lists.
    let selectedListID: String?

    /// Resolved data for the widget to display.
    var displayData: WidgetDisplayData {
        if let selectedListID, let list = snapshot.list(for: selectedListID) {
            return WidgetDisplayData(
                remainingValue: list.remainingValue,
                currency: snapshot.currency,
                unpurchasedCount: list.unpurchasedCount,
                totalItemCount: list.totalItemCount,
                purchasedCount: list.purchasedCount,
                reservedCount: list.reservedCount,
                completionFraction: list.completionFraction,
                topItems: list.topItems,
                title: list.name,
                emoji: list.emoji,
                colorHex: list.colorHex,
                daysUntilDeadline: list.daysUntilDeadline,
                totalListCount: nil,
                selectedListID: selectedListID
            )
        }
        return WidgetDisplayData(
            remainingValue: snapshot.totalRemainingValue,
            currency: snapshot.currency,
            unpurchasedCount: snapshot.unpurchasedCount,
            totalItemCount: snapshot.totalItemCount,
            purchasedCount: snapshot.purchasedCount,
            reservedCount: snapshot.reservedCount,
            completionFraction: snapshot.completionFraction,
            topItems: snapshot.topItems,
            title: "Gimme",
            emoji: nil,
            colorHex: nil,
            daysUntilDeadline: nil,
            totalListCount: snapshot.totalListCount,
            selectedListID: nil
        )
    }
}

/// Flattened data for widget views — avoids branching logic in every view.
struct WidgetDisplayData {
    let remainingValue: Double
    let currency: String
    let unpurchasedCount: Int
    let totalItemCount: Int
    let purchasedCount: Int
    let reservedCount: Int
    let completionFraction: Double
    let topItems: [WidgetItem]
    let title: String
    let emoji: String?
    let colorHex: String?
    let daysUntilDeadline: Int?
    let totalListCount: Int?
    /// List ID for deep-linking, nil = all lists.
    let selectedListID: String?

    var isEmpty: Bool { totalItemCount == 0 && (totalListCount ?? 1) == 0 }
    var accentColor: Color {
        if let hex = colorHex { return Color(hex: hex) }
        return Color(red: 0.424, green: 0.388, blue: 1.0)
    }

    /// Deep link URL to add a new wish.
    var addItemURL: URL {
        if let id = selectedListID {
            return URL(string: "gimme://add?list=\(id)")!
        }
        return URL(string: "gimme://add")!
    }
}

// MARK: - Timeline Provider

struct GimmeTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> GimmeEntry {
        GimmeEntry(date: .now, snapshot: .placeholder, selectedListID: nil)
    }

    func snapshot(for configuration: SelectListIntent, in context: Context) async -> GimmeEntry {
        GimmeEntry(date: .now, snapshot: .load(), selectedListID: configuration.list?.id)
    }

    func timeline(for configuration: SelectListIntent, in context: Context) async -> Timeline<GimmeEntry> {
        let entry = GimmeEntry(date: .now, snapshot: .load(), selectedListID: configuration.list?.id)
        return Timeline(entries: [entry], policy: .atEnd)
    }
}

// MARK: - Widget Definition (Small + Medium)

struct GimmeWidget: Widget {
    let kind = "GimmeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectListIntent.self, provider: GimmeTimelineProvider()) { entry in
            GimmeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Gimme")
        .description("Track your wishlist at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget View Router

struct GimmeWidgetEntryView: View {
    let entry: GimmeEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.displayData)
        case .systemMedium:
            MediumWidgetView(data: entry.displayData)
        default:
            SmallWidgetView(data: entry.displayData)
        }
    }
}

// MARK: - Placeholder data

extension WidgetSnapshot {
    static let placeholder = WidgetSnapshot(
        totalRemainingValue: 1077,
        currency: "USD",
        unpurchasedCount: 7,
        totalItemCount: 12,
        purchasedCount: 5,
        reservedCount: 2,
        totalListCount: 3,
        topItems: [
            WidgetItem(id: "1", title: "AirPods Max", emoji: "🎂", price: 549.0, currency: "USD", priority: "high", isReserved: false),
            WidgetItem(id: "2", title: "Standing Desk", emoji: "💻", price: 399.0, currency: "USD", priority: "high", isReserved: true),
            WidgetItem(id: "3", title: "Running Shoes", emoji: "🏃", price: 129.0, currency: "USD", priority: "medium", isReserved: false),
        ],
        updatedAt: .now,
        lists: [
            WidgetListSnapshot(
                id: "list-1", name: "Birthday", emoji: "🎂", colorHex: "#E8586D",
                totalItemCount: 8, purchasedCount: 3, reservedCount: 2,
                remainingValue: 650, topItems: [], endDate: nil
            )
        ]
    )
}
