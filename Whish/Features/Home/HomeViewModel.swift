import Foundation
import SwiftData

@Observable
@MainActor
final class HomeViewModel {
    var isShowingNewList = false
    var listToRename: WishList? = nil
    var renameText = ""
    var showArchivedLists = false

    /// The actual search query applied to filtering. Updated after a debounce delay.
    private(set) var activeSearchText = ""

    /// Bind to this in the view. The didSet debounces before updating activeSearchText.
    var searchText = "" {
        didSet { scheduleSearchUpdate() }
    }

    private var searchDebounceTask: Task<Void, Never>?

    func showNewList() { isShowingNewList = true }

    func createList(name: String, emoji: String, colorHex: String, in context: ModelContext) {
        let list = WishList(name: name.trimmingCharacters(in: .whitespaces), emoji: emoji, colorHex: colorHex)
        context.insert(list)
    }

    func deleteList(_ list: WishList, in context: ModelContext) { context.delete(list) }
    func archiveList(_ list: WishList)   { list.isArchived = true }
    func unarchiveList(_ list: WishList) { list.isArchived = false }
    func pinList(_ list: WishList)       { list.isPinned.toggle() }

    func startRename(_ list: WishList) {
        renameText = list.name
        listToRename = list
    }

    func commitRename() {
        guard let list = listToRename,
              !renameText.trimmingCharacters(in: .whitespaces).isEmpty else {
            listToRename = nil; return
        }
        list.name = renameText.trimmingCharacters(in: .whitespaces)
        listToRename = nil
    }

    func updateColor(_ list: WishList, colorHex: String) { list.colorHex = colorHex }

    // MARK: - Search debounce

    private func scheduleSearchUpdate() {
        searchDebounceTask?.cancel()
        let newText = searchText
        if newText.isEmpty {
            // Clear immediately so UI updates instantly when user clears search
            activeSearchText = ""
            return
        }
        searchDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            activeSearchText = newText
        }
    }

    /// Active (non-archived) lists, search-filtered, pinned first then newest first.
    func filteredLists(_ lists: [WishList]) -> [WishList] {
        let active = lists.filter { !$0.isArchived }
        let searched = activeSearchText.isEmpty
            ? active
            : active.filter {
                $0.name.localizedCaseInsensitiveContains(activeSearchText) ||
                $0.emoji.localizedCaseInsensitiveContains(activeSearchText)
            }
        return searched.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.createdAt > rhs.createdAt
        }
    }

    /// Items matching the search query across all lists.
    func filteredItems(_ items: [WishItem]) -> [WishItem] {
        guard !activeSearchText.isEmpty else { return [] }
        let q = activeSearchText
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            ($0.notes?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    func archivedLists(_ lists: [WishList]) -> [WishList] {
        lists.filter { $0.isArchived }
    }
}
