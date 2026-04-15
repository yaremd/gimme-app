import Foundation
import SwiftData

enum ItemFilter: String, CaseIterable {
    case all = "All"
    case wanted = "Wanted"
    case purchased = "Purchased"
}

enum ItemSort: String, CaseIterable {
    case dateAdded  = "Date Added"
    case priority   = "Priority"
    case name       = "Name"
    case purchased  = "Purchased"
    case reserved   = "Reserved"
}

@Observable
@MainActor
final class ListDetailViewModel {
    var filter: ItemFilter = .all
    var sort: ItemSort = .dateAdded
    var isShowingAddItem = false
    var itemToEdit: WishItem? = nil

    private static let priorityRank: [Priority: Int] = [.high: 0, .medium: 1, .low: 2]

    func filteredAndSorted(_ items: [WishItem]) -> [WishItem] {
        let filtered: [WishItem]
        switch filter {
        case .all:       filtered = items
        case .wanted:    filtered = items.filter { !$0.isPurchased }
        case .purchased: filtered = items.filter { $0.isPurchased }
        }

        let currentSort = sort
        return filtered.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            switch currentSort {
            case .dateAdded:
                return lhs.createdAt > rhs.createdAt
            case .priority:
                let li = Self.priorityRank[lhs.priority] ?? 0
                let ri = Self.priorityRank[rhs.priority] ?? 0
                return li < ri
            case .name:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .purchased:
                if lhs.isPurchased != rhs.isPurchased { return !lhs.isPurchased }
                return lhs.createdAt > rhs.createdAt
            case .reserved:
                if lhs.isReservedByFriend != rhs.isReservedByFriend { return lhs.isReservedByFriend }
                return lhs.createdAt > rhs.createdAt
            }
        }
    }

    func togglePurchased(_ item: WishItem) { item.isPurchased.toggle() }
    func pinItem(_ item: WishItem)         { item.isPinned.toggle() }

    func deleteItem(_ item: WishItem, in context: ModelContext) {
        context.delete(item)
    }

    func showAddItem() {
        itemToEdit = nil
        isShowingAddItem = true
    }

    func showEditItem(_ item: WishItem) {
        itemToEdit = item
        isShowingAddItem = true
    }
}
