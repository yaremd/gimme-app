import AppIntents
import WidgetKit

// MARK: - List entity for widget configuration

struct WidgetListEntity: AppEntity {
    nonisolated(unsafe) static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Wishlist")
    nonisolated(unsafe) static var defaultQuery = WidgetListEntityQuery()

    var id: String
    var name: String
    var emoji: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }
}

struct WidgetListEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetListEntity] {
        loadEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WidgetListEntity] {
        loadEntities()
    }

    private func loadEntities() -> [WidgetListEntity] {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshot.appGroupID),
              let data = defaults.data(forKey: "appIntentsLists"),
              let records = try? JSONDecoder().decode([ListRecord].self, from: data)
        else { return [] }
        return records.map { WidgetListEntity(id: $0.id.uuidString, name: $0.name, emoji: $0.emoji) }
    }

    private struct ListRecord: Codable {
        let id: UUID
        let name: String
        let emoji: String
    }
}

// MARK: - Widget configuration intent

struct SelectListIntent: WidgetConfigurationIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Select Wishlist"
    nonisolated(unsafe) static var description: IntentDescription = "Choose which wishlist to display."

    @Parameter(title: "Wishlist")
    var list: WidgetListEntity?
}
