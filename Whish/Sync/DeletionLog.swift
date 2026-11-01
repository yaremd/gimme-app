import Foundation
import SwiftData

/// Durable record of what the user deleted — the missing half of the sync protocol.
///
/// Sync reconciles by copying rows that exist on one side to the other, in both
/// directions: a local row with no remote match is pushed up, a remote row with
/// no local match is pulled down. That makes a deletion indistinguishable from
/// "a record the other side hasn't seen yet", so whichever copy of a deleted
/// record outlives the delete recreates the other one. A tombstone turns the
/// deletion itself into a fact, and facts survive failed requests, app kills,
/// and other devices.
///
/// Stored in UserDefaults rather than SwiftData on purpose: `WhishApp.init`
/// wipes the persistent store when the SwiftData schema fails to migrate, and
/// the record of what the user deleted is the one thing that must not be lost
/// down that path — losing it resurrects everything they ever deleted.
enum DeletionLog {

    enum Entity: String, CaseIterable, Sendable {
        case list = "wish_list"
        case item = "wish_item"

        fileprivate var storageKey: String { "sync.tombstones.\(rawValue)" }
    }

    /// How long a confirmed tombstone is kept. Long enough that every device
    /// syncs at least once, short enough that the log stays small.
    static let retention: TimeInterval = 60 * 60 * 24 * 90   // 90 days

    struct Entry: Codable, Sendable {
        var deletedAt: Date
        /// True once the server has dropped the row and stored the tombstone.
        /// False means the deletion is still owed to the server.
        var isConfirmed: Bool
    }

    // MARK: - Recording

    /// Marks `id` as deleted. Call this in the same turn as the local delete, so
    /// no sync cycle can observe the record without also observing its deletion.
    static func record(_ id: UUID, entity: Entity, at date: Date = .now) {
        mutate(entity) { entries in
            // Keep the original timestamp if this id was already tombstoned.
            if entries[id.uuidString] == nil {
                entries[id.uuidString] = Entry(deletedAt: date, isConfirmed: false)
            }
        }
    }

    /// Adopts tombstones pulled from the server — deletions made on another
    /// device. They arrive confirmed; the server is where they came from. Each
    /// keeps the server's deletion time, so retention ages it from when it was
    /// deleted rather than from whenever it was last pulled.
    static func adopt(_ tombstones: [UUID: Date], entity: Entity) {
        guard !tombstones.isEmpty else { return }
        mutate(entity) { entries in
            for (id, deletedAt) in tombstones {
                entries[id.uuidString] = Entry(deletedAt: deletedAt, isConfirmed: true)
            }
        }
    }

    /// Called once the server has dropped the row and stored the tombstone.
    static func markConfirmed(_ id: UUID, entity: Entity) {
        mutate(entity) { entries in
            entries[id.uuidString]?.isConfirmed = true
        }
    }

    // MARK: - Querying

    static func isDeleted(_ id: UUID, entity: Entity) -> Bool {
        read(entity)[id.uuidString] != nil
    }

    /// Every id known to be deleted, confirmed or not. Sync vetoes both
    /// directions of the reconcile against this set.
    static func deletedIDs(_ entity: Entity) -> Set<UUID> {
        Set(read(entity).keys.compactMap(UUID.init(uuidString:)))
    }

    /// Deletions the server has not acknowledged yet — the delete outbox.
    static func unconfirmedIDs(_ entity: Entity) -> [UUID] {
        read(entity).compactMap { key, entry in
            entry.isConfirmed ? nil : UUID(uuidString: key)
        }
    }

    // MARK: - Housekeeping

    /// Drops confirmed tombstones older than `retention`. Unconfirmed ones stay
    /// regardless of age — they still have a deletion to deliver.
    static func prune(now: Date = .now) {
        for entity in Entity.allCases {
            mutate(entity) { entries in
                entries = entries.filter { _, entry in
                    !entry.isConfirmed || now.timeIntervalSince(entry.deletedAt) < retention
                }
            }
        }
    }

    /// Clears the whole log, pull cursors included. Only for when the account
    /// itself goes away — the tombstones describe rows that no longer exist
    /// anywhere.
    static func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        for entity in Entity.allCases {
            defaults.removeObject(forKey: entity.storageKey)
        }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(cursorKeyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Pull cursor

    /// The newest server `deleted_at` this device has pulled for `ownerID`.
    ///
    /// A server timestamp, never this device's clock: comparing the server's
    /// `deleted_at` against a local clock skips tombstones whenever the two
    /// disagree. Only moves forward after a pull succeeds, so a failed pull
    /// can't step over deletions it never saw. Per account, so signing into a
    /// different one starts from the beginning.
    static func pullCursor(for ownerID: UUID) -> Date? {
        defaults.object(forKey: cursorKey(ownerID)) as? Date
    }

    static func advancePullCursor(to date: Date, for ownerID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        if let current = defaults.object(forKey: cursorKey(ownerID)) as? Date, current >= date { return }
        defaults.set(date, forKey: cursorKey(ownerID))
    }

    private static let cursorKeyPrefix = "sync.tombstones.cursor."
    private static func cursorKey(_ ownerID: UUID) -> String {
        cursorKeyPrefix + ownerID.uuidString
    }

    // MARK: - Storage

    /// Overridable so tests get their own suite instead of the app's defaults.
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    private static func read(_ entity: Entity) -> [String: Entry] {
        lock.lock()
        defer { lock.unlock() }
        return load(entity)
    }

    /// Read–modify–write under the lock: sync runs deletions from several tasks
    /// at once, and a lost update here is a resurrected record.
    private static func mutate(_ entity: Entity, _ body: (inout [String: Entry]) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        var entries = load(entity)
        body(&entries)
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: entity.storageKey)
    }

    private static func load(_ entity: Entity) -> [String: Entry] {
        guard let data = defaults.data(forKey: entity.storageKey),
              let entries = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return [:] }
        return entries
    }
}

private let lock = NSLock()

// MARK: - Deleting through the log

extension ModelContext {

    /// Deletes `item` and tombstones it, then saves so the removal is on disk
    /// before any background sync context reads the store. Without the save the
    /// delete sits in the main context until autosave fires, and a sync that
    /// starts in between still sees the row and pushes it back to the server.
    ///
    /// Guest data (no owner) never reached the server, so it gets no tombstone:
    /// there is nothing to delete remotely, and the entry would sit in the
    /// delete outbox forever.
    func deleteRecord(_ item: WishItem) {
        if item.list?.ownerID != nil {
            DeletionLog.record(item.id, entity: .item)
        }
        delete(item)
        try? save()
    }

    /// Deletes `list` and, by cascade, its items. Only the list is tombstoned:
    /// SwiftData cascades the items here, the `list_id` foreign key cascades
    /// them on the server, and the server's delete trigger tombstones each one
    /// for other devices. Tombstoning them here too would only queue a DELETE
    /// per item for rows that are already gone.
    func deleteRecord(_ list: WishList) {
        if list.ownerID != nil {
            DeletionLog.record(list.id, entity: .list)
        }
        delete(list)
        try? save()
    }
}
