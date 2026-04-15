import Foundation
import SwiftData

@Observable
@MainActor
final class ItemDetailViewModel {
    var isShowingEditSheet = false
    var isShowingDeleteConfirm = false

    func togglePurchased(_ item: WishItem) {
        item.isPurchased.toggle()
    }

    func clearReservation(_ item: WishItem) {
        item.isReservedByFriend = false
        item.reservedByName = nil
    }

    func deleteItem(_ item: WishItem, in context: ModelContext, onDeleted: @MainActor () -> Void) {
        context.delete(item)
        onDeleted()
    }
}
