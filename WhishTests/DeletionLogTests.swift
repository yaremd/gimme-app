import Foundation
import SwiftData
import Testing
@testable import Whish

/// Serialized: `DeletionLog` is process-wide state backed by a UserDefaults suite.
@Suite(.serialized)
struct DeletionLogTests {

    /// Points the log at a throwaway suite so tests never touch the app's defaults.
    /// The body receives the suite name, for tests that need a second handle onto
    /// the same storage.
    private func withFreshLog(_ body: (String) throws -> Void) rethrows {
        let suiteName = "DeletionLogTests.\(UUID().uuidString)"
        let previous = DeletionLog.defaults
        DeletionLog.defaults = UserDefaults(suiteName: suiteName)!
        defer {
            DeletionLog.defaults = previous
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        try body(suiteName)
    }

    // MARK: - Recording

    @Test func recordsADeletionAsUnconfirmed() {
        withFreshLog { _ in
            let id = UUID()
            DeletionLog.record(id, entity: .item)

            #expect(DeletionLog.isDeleted(id, entity: .item))
            #expect(DeletionLog.unconfirmedIDs(.item) == [id])
        }
    }

    @Test func keepsListAndItemTombstonesApart() {
        withFreshLog { _ in
            let id = UUID()
            DeletionLog.record(id, entity: .item)

            #expect(DeletionLog.isDeleted(id, entity: .item))
            #expect(!DeletionLog.isDeleted(id, entity: .list))
        }
    }

    @Test func confirmingClearsTheDeleteOutbox() {
        withFreshLog { _ in
            let id = UUID()
            DeletionLog.record(id, entity: .list)
            DeletionLog.markConfirmed(id, entity: .list)

            #expect(DeletionLog.unconfirmedIDs(.list).isEmpty)
            // Still deleted — confirmation means "the server agrees", not "forget it".
            #expect(DeletionLog.isDeleted(id, entity: .list))
        }
    }

    @Test func adoptedTombstonesArriveConfirmed() {
        withFreshLog { _ in
            let ids = [UUID(), UUID()]
            DeletionLog.adopt(Dictionary(uniqueKeysWithValues: ids.map { ($0, Date.now) }), entity: .item)

            #expect(DeletionLog.deletedIDs(.item) == Set(ids))
            #expect(DeletionLog.unconfirmedIDs(.item).isEmpty)
        }
    }

    @Test func adoptedTombstonesAgeFromTheServerDeletionTime() {
        withFreshLog { _ in
            let id = UUID()
            // Re-pulled today, but deleted on another device long ago. Stamping it
            // with the pull time would restart its retention on every full sync.
            DeletionLog.adopt([id: Date(timeIntervalSinceNow: -DeletionLog.retention - 60)], entity: .item)

            DeletionLog.prune()

            #expect(!DeletionLog.isDeleted(id, entity: .item))
        }
    }

    @Test func reRecordingKeepsTheOriginalDeletionTime() {
        withFreshLog { _ in
            let id = UUID()
            let first = Date(timeIntervalSince1970: 1_000)
            DeletionLog.record(id, entity: .item, at: first)
            DeletionLog.markConfirmed(id, entity: .item)
            DeletionLog.record(id, entity: .item, at: .now)

            // A second record() must not reopen a settled deletion.
            #expect(DeletionLog.unconfirmedIDs(.item).isEmpty)
        }
    }

    // MARK: - Pruning

    @Test func prunesConfirmedTombstonesPastRetention() {
        withFreshLog { _ in
            let old = UUID()
            let recent = UUID()
            DeletionLog.record(old, entity: .item, at: Date(timeIntervalSinceNow: -DeletionLog.retention - 60))
            DeletionLog.record(recent, entity: .item)
            DeletionLog.markConfirmed(old, entity: .item)
            DeletionLog.markConfirmed(recent, entity: .item)

            DeletionLog.prune()

            #expect(!DeletionLog.isDeleted(old, entity: .item))
            #expect(DeletionLog.isDeleted(recent, entity: .item))
        }
    }

    @Test func keepsUnconfirmedTombstonesHoweverOld() {
        withFreshLog { _ in
            let id = UUID()
            DeletionLog.record(id, entity: .item, at: Date(timeIntervalSinceNow: -DeletionLog.retention * 10))

            DeletionLog.prune()

            // The server still owes us this deletion — ageing out would resurrect it.
            #expect(DeletionLog.isDeleted(id, entity: .item))
        }
    }

    @Test func survivesARelaunch() {
        withFreshLog { suiteName in
            let id = UUID()
            DeletionLog.record(id, entity: .item)

            // A fresh handle onto the same suite stands in for the next launch.
            // An unconfirmed deletion has to outlive the process, or killing the
            // app mid-delete is enough to bring the record back.
            DeletionLog.defaults = UserDefaults(suiteName: suiteName)!

            #expect(DeletionLog.isDeleted(id, entity: .item))
            #expect(DeletionLog.unconfirmedIDs(.item) == [id])
        }
    }

    // MARK: - Pull cursor

    @Test func pullCursorOnlyMovesForward() {
        withFreshLog { _ in
            let owner = UUID()
            let later = Date(timeIntervalSince1970: 2_000)
            #expect(DeletionLog.pullCursor(for: owner) == nil)

            DeletionLog.advancePullCursor(to: later, for: owner)
            DeletionLog.advancePullCursor(to: Date(timeIntervalSince1970: 1_000), for: owner)

            #expect(DeletionLog.pullCursor(for: owner) == later)
        }
    }

    @Test func pullCursorIsPerAccount() {
        withFreshLog { _ in
            let first = UUID()
            DeletionLog.advancePullCursor(to: .now, for: first)

            // Another account on this device has pulled nothing yet.
            #expect(DeletionLog.pullCursor(for: UUID()) == nil)
        }
    }

    @Test func removeAllClearsTombstonesAndCursors() {
        withFreshLog { _ in
            let owner = UUID()
            let id = UUID()
            DeletionLog.record(id, entity: .list)
            DeletionLog.advancePullCursor(to: .now, for: owner)

            DeletionLog.removeAll()

            #expect(!DeletionLog.isDeleted(id, entity: .list))
            #expect(DeletionLog.pullCursor(for: owner) == nil)
        }
    }

    // MARK: - Deleting through the log

    @MainActor
    @Test func deletingAnItemTombstonesIt() throws {
        try withFreshLog { _ in
            let container = try ModelContainer(
                for: WishList.self, WishItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let context = ModelContext(container)

            let list = WishList(name: "Birthday", ownerID: UUID().uuidString)
            let item = WishItem(title: "Headphones", list: list)
            context.insert(list)
            context.insert(item)
            list.items.append(item)
            try context.save()

            let itemID = item.id
            context.deleteRecord(item)

            #expect(DeletionLog.isDeleted(itemID, entity: .item))
            // Saved synchronously — a sync context reading the store right now
            // must not find the row and push it back to the server.
            #expect(try context.fetch(FetchDescriptor<WishItem>()).isEmpty)
        }
    }

    @MainActor
    @Test func deletingAListTombstonesOnlyTheList() throws {
        try withFreshLog { _ in
            let container = try ModelContainer(
                for: WishList.self, WishItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let context = ModelContext(container)

            let list = WishList(name: "Wedding", ownerID: UUID().uuidString)
            let first = WishItem(title: "Kettle", list: list)
            let second = WishItem(title: "Towels", list: list)
            context.insert(list)
            context.insert(first)
            context.insert(second)
            list.items.append(contentsOf: [first, second])
            try context.save()

            let listID = list.id
            context.deleteRecord(list)

            #expect(DeletionLog.isDeleted(listID, entity: .list))
            // The items go by cascade, locally and on the server, where the
            // delete trigger tombstones each one. Queuing them here as well
            // would only send a DELETE per item for rows already gone.
            #expect(DeletionLog.unconfirmedIDs(.item).isEmpty)
            #expect(try context.fetch(FetchDescriptor<WishItem>()).isEmpty)
        }
    }

    @MainActor
    @Test func deletingGuestDataLeavesNoTombstone() throws {
        try withFreshLog { _ in
            let container = try ModelContainer(
                for: WishList.self, WishItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let context = ModelContext(container)

            let list = WishList(name: "Guest list")   // no owner: never synced
            let item = WishItem(title: "Lamp", list: list)
            context.insert(list)
            context.insert(item)
            list.items.append(item)
            try context.save()

            context.deleteRecord(item)
            context.deleteRecord(list)

            // Nothing on the server to delete, so nothing should sit in the
            // delete outbox waiting for a session that may never come.
            #expect(DeletionLog.unconfirmedIDs(.item).isEmpty)
            #expect(DeletionLog.unconfirmedIDs(.list).isEmpty)
            #expect(try context.fetch(FetchDescriptor<WishList>()).isEmpty)
        }
    }
}
