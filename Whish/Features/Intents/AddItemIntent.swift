import AppIntents
import Foundation

// MARK: - Add Item Intent
// "Add wish to Gimme" → Siri asks "What?" → asks "Which list?" → opens app, creates item

struct AddItemIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Add Wish"
    nonisolated(unsafe) static var description: IntentDescription = "Adds a new item to a wishlist in Gimme."
    nonisolated(unsafe) static var openAppWhenRun = true
    nonisolated(unsafe) static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$itemName) to \(\.$list)")
    }

    @Parameter(title: "Item Name", requestValueDialog: IntentDialog("What would you like to add?"))
    var itemName: String

    @Parameter(title: "Wishlist", requestValueDialog: IntentDialog("Which wishlist?"))
    var list: WishListEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        DeepLinkRouter.shared.pendingAction = .addItem(
            title: itemName,
            listID: list?.id
        )
        let listName = list.map { "\($0.emoji) \($0.name)" } ?? "Gimme"
        return .result(dialog: "Adding \"\(itemName)\" to \(listName)…")
    }
}

// MARK: - Quick Add Intent (adds to last-used list)
// "Quick add to Gimme" → Siri asks "What?" → opens app, adds to most recent list

struct QuickAddIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Quick Add Wish"
    nonisolated(unsafe) static var description: IntentDescription = "Quickly adds an item to your most recent wishlist."
    nonisolated(unsafe) static var openAppWhenRun = true
    nonisolated(unsafe) static var parameterSummary: some ParameterSummary {
        Summary("Quick add \(\.$itemName)")
    }

    @Parameter(title: "Item Name", requestValueDialog: IntentDialog("What would you like to add?"))
    var itemName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Use last-used list ID from UserDefaults
        let lastUsedID: UUID?
        if let idStr = UserDefaults.standard.string(forKey: "lastUsedListID") {
            lastUsedID = UUID(uuidString: idStr)
        } else {
            lastUsedID = nil
        }

        DeepLinkRouter.shared.pendingAction = .addItem(
            title: itemName,
            listID: lastUsedID
        )
        return .result(dialog: "Adding \"\(itemName)\"…")
    }
}

// MARK: - How Much Left Intent (answers WITHOUT opening app)
// "Wishlist total in Gimme" → Siri reads back the value

struct HowMuchLeftIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Wishlist Value"
    nonisolated(unsafe) static var description: IntentDescription = "Shows how much is left on your wishlists."
    nonisolated(unsafe) static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Read from widget snapshot (App Group) — no ModelContainer needed
        let snapshot = loadSnapshot()

        if snapshot.totalListCount == 0 {
            return .result(dialog: "You don't have any wishlists yet. Open Gimme to create one!")
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = snapshot.currency
        formatter.maximumFractionDigits = 0
        if snapshot.currency == "USD" { formatter.currencySymbol = "$" }
        let formatted = formatter.string(from: NSNumber(value: snapshot.totalRemainingValue)) ?? "$0"

        let count = snapshot.unpurchasedCount
        return .result(dialog: "You have \(count) wish\(count == 1 ? "" : "es") remaining worth \(formatted) across \(snapshot.totalListCount) list\(snapshot.totalListCount == 1 ? "" : "s").")
    }

    private func loadSnapshot() -> WidgetSnapshotData {
        guard let defaults = UserDefaults(suiteName: "group.com.yaremchuk.app"),
              let data = defaults.data(forKey: "widgetData"),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshotData.self, from: data)
        else { return .empty }
        return snapshot
    }

    private struct WidgetSnapshotData: Codable {
        let totalRemainingValue: Double
        let currency: String
        let unpurchasedCount: Int
        let totalListCount: Int
        let updatedAt: Date

        static let empty = WidgetSnapshotData(
            totalRemainingValue: 0, currency: "USD",
            unpurchasedCount: 0, totalListCount: 0,
            updatedAt: .distantPast
        )
    }
}
