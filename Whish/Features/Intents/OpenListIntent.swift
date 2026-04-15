import AppIntents
import SwiftData
import Foundation

// MARK: - WishList Entity for AppIntents

struct WishListEntity: AppEntity {
    nonisolated(unsafe) static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Wishlist")
    nonisolated(unsafe) static var defaultQuery = WishListEntityQuery()

    var id: UUID
    var name: String
    var emoji: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }
}

// MARK: - Entity Query

struct WishListEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [WishListEntity] {
        loadLists().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WishListEntity] {
        loadLists()
    }

    private func loadLists() -> [WishListEntity] {
        guard let defaults = UserDefaults(suiteName: "group.com.yaremchuk.app"),
              let data = defaults.data(forKey: "appIntentsLists"),
              let records = try? JSONDecoder().decode([ListRecord].self, from: data)
        else { return [] }
        return records.map { WishListEntity(id: $0.id, name: $0.name, emoji: $0.emoji) }
    }

    private struct ListRecord: Codable {
        let id: UUID
        let name: String
        let emoji: String
    }
}

// MARK: - Open List Intent

struct OpenListIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Open Wishlist"
    nonisolated(unsafe) static var description: IntentDescription = "Opens a specific wishlist in Gimme."
    nonisolated(unsafe) static var openAppWhenRun = true
    nonisolated(unsafe) static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$list)")
    }

    @Parameter(title: "Wishlist", requestValueDialog: IntentDialog("Which wishlist would you like to open?"))
    var list: WishListEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        if let list {
            DeepLinkRouter.shared.pendingAction = .openList(list.id)
        }
        // If no list selected, just opens the app (openAppWhenRun = true)
        return .result()
    }
}
