import CoreSpotlight
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Indexes WishList and WishItem records in Spotlight so they appear in system search.
/// Tapping a result opens the app via `gimme://list/<UUID>`.
enum SpotlightIndexService {

    /// Runs on a background ModelContext — safe to call from any actor.
    nonisolated static func reindex(container: ModelContainer) {
        let context = ModelContext(container)

        let lists: [WishList]
        let items: [WishItem]

        do {
            lists = try context.fetch(FetchDescriptor<WishList>())
            items = try context.fetch(FetchDescriptor<WishItem>())
        } catch { return }

        var searchableItems: [CSSearchableItem] = []

        // Index lists
        for list in lists where !list.isArchived {
            let attrs = CSSearchableItemAttributeSet(contentType: .content)
            attrs.title = "\(list.emoji) \(list.name)"
            attrs.contentDescription = "\(list.unpurchasedCount) item\(list.unpurchasedCount == 1 ? "" : "s") remaining"
            attrs.keywords = ["wishlist", "gimme", list.name]

            let item = CSSearchableItem(
                uniqueIdentifier: "gimme://list/\(list.id.uuidString)",
                domainIdentifier: "com.yaremchuk.app.lists",
                attributeSet: attrs
            )
            searchableItems.append(item)
        }

        // Index items
        for item in items {
            let attrs = CSSearchableItemAttributeSet(contentType: .content)
            attrs.title = item.title
            attrs.contentDescription = item.notes
            if let listName = item.list?.name, let emoji = item.list?.emoji {
                attrs.keywords = ["wish", "gimme", listName, emoji]
            }

            // Link to parent list so tapping navigates there
            let listID = item.list?.id.uuidString ?? ""
            let searchItem = CSSearchableItem(
                uniqueIdentifier: "gimme://list/\(listID)?item=\(item.id.uuidString)",
                domainIdentifier: "com.yaremchuk.app.items",
                attributeSet: attrs
            )
            searchableItems.append(searchItem)
        }

        CSSearchableIndex.default().deleteAllSearchableItems { _ in
            CSSearchableIndex.default().indexSearchableItems(searchableItems)
        }
    }
}
