import Foundation
import SwiftData
import Supabase

/// Bidirectional sync engine between SwiftData and Supabase.
///
/// Strategy (Phase 3 — last-write-wins on updatedAt):
///  • Push all local lists/items to Supabase (upsert).
///  • Pull any records that exist remotely but not locally.
///  • Conflicts resolved by updatedAt — newer timestamp wins.
///
/// Call `syncAll` on sign-in and periodically when the scene becomes active.
/// Call `deleteList` / `deleteItem` immediately after a user-initiated delete.
@Observable
@MainActor
final class SyncService {

    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: String?

    private var lastSyncAttempt: Date = .distantPast
    private let minSyncInterval: TimeInterval = 30  // throttle: max once per 30 s

    // MARK: - Full sync

    /// Push everything local → pull remote-only records.
    /// Safe to call frequently — internally throttled to `minSyncInterval`.
    /// Accepts `ModelContainer` so heavy work runs on a background thread.
    func syncAll(container: ModelContainer, userID: String, force: Bool = false) async {
        let now = Date()
        guard force || now.timeIntervalSince(lastSyncAttempt) >= minSyncInterval else { return }
        guard !isSyncing else { return }

        lastSyncAttempt = now
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            try await Self.performSync(container: container, userID: userID)
            lastSyncDate = .now
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Delete

    func deleteList(id: UUID) async {
        try? await supabase
            .from("wish_lists")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteItem(id: UUID) async {
        try? await supabase
            .from("wish_items")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Heavy sync (runs off @MainActor)

    /// All SwiftData fetches, image compression, diffing, and model mutations
    /// happen on a background ModelContext. Network calls are already nonisolated.
    /// After this method saves the background context, SwiftData propagates
    /// changes to the main context automatically via persistent-store notifications,
    /// so @Query properties in SwiftUI will refresh.
    private nonisolated static func performSync(container: ModelContainer, userID: String) async throws {
        guard let ownerUUID = UUID(uuidString: userID) else { return }

        let context = ModelContext(container)
        context.autosaveEnabled = false

        // ── 0. Upload pending images (parallel, compressed) ───────
        let allItems = try context.fetch(FetchDescriptor<WishItem>())
        let pendingUploads: [(WishItem, Data, String)] = allItems.compactMap { item in
            guard item.imageURL == nil, let data = item.imageData, !data.isEmpty else { return nil }
            let path = "\(ownerUUID.uuidString.lowercased())/\(item.id.uuidString.lowercased()).jpg"
            let compressed = ImageCompressor.compress(data) ?? data
            return (item, compressed, path)
        }

        if !pendingUploads.isEmpty {
            let uploadResults = await uploadImagesParallel(pendingUploads.map { ($0.1, $0.2) })
            for (item, _, path) in pendingUploads {
                if let url = uploadResults[path] {
                    item.imageURL = url
                    item.updatedAt = .now
                }
            }
        }

        // ── 1. Fetch remote (off main actor) ─────────────────────
        let (remoteLists, remoteItems) = try await fetchRemote()

        let remoteListsByID = Dictionary(uniqueKeysWithValues: remoteLists.map { ($0.id, $0) })
        let remoteItemsByID = Dictionary(uniqueKeysWithValues: remoteItems.map { ($0.id, $0) })

        // ── 2. Sync lists — collect batch, push once ──────────────
        let localLists = try context.fetch(FetchDescriptor<WishList>())
        var listsToPush: [WishListRecord] = []

        for local in localLists {
            if let remote = remoteListsByID[local.id] {
                if remote.updatedAt > (local.updatedAt ?? .distantPast) {
                    applyRemote(remote, to: local)
                } else {
                    let record = WishListRecord(from: local, ownerID: ownerUUID)
                    local.updatedAt = .now
                    local.ownerID = ownerUUID.uuidString
                    listsToPush.append(record)
                }
            } else {
                let record = WishListRecord(from: local, ownerID: ownerUUID)
                local.updatedAt = .now
                local.ownerID = ownerUUID.uuidString
                listsToPush.append(record)
            }
        }

        // Pull remote-only lists
        let localListIDs = Set(localLists.map { $0.id })
        for remote in remoteLists where !localListIDs.contains(remote.id) {
            let list = WishList(
                id: remote.id,
                name: remote.name,
                emoji: remote.emoji,
                colorHex: remote.colorHex,
                createdAt: remote.createdAt,
                isShared: remote.isShared,
                shareToken: remote.shareToken,
                isPinned: remote.isPinned,
                isArchived: remote.isArchived,
                ownerID: remote.ownerID.uuidString,
                updatedAt: remote.updatedAt
            )
            context.insert(list)
        }

        // ── 3. Sync items — collect batch, push once ──────────────
        let localItems = try context.fetch(FetchDescriptor<WishItem>())
        var itemsToPush: [WishItemRecord] = []

        for local in localItems {
            guard let parentList = local.list else { continue }
            if let remote = remoteItemsByID[local.id] {
                if remote.updatedAt > (local.updatedAt ?? .distantPast) {
                    applyRemote(remote, to: local)
                } else {
                    let record = WishItemRecord(from: local, listID: parentList.id, ownerID: ownerUUID)
                    local.updatedAt = .now
                    itemsToPush.append(record)
                }
            } else {
                let record = WishItemRecord(from: local, listID: parentList.id, ownerID: ownerUUID)
                local.updatedAt = .now
                itemsToPush.append(record)
            }
        }

        // Pull remote-only items
        let localItemIDs = Set(localItems.map { $0.id })
        let allLocalLists = try context.fetch(FetchDescriptor<WishList>())
        let listsByID = Dictionary(uniqueKeysWithValues: allLocalLists.map { ($0.id, $0) })

        for remote in remoteItems where !localItemIDs.contains(remote.id) {
            guard let parentList = listsByID[remote.listID] else { continue }
            let item = makeItem(from: remote, list: parentList)
            context.insert(item)
            parentList.items.append(item)
        }

        // ── 4. Batch push (2 network calls instead of N) ─────────
        try await pushRecords(listsToPush, table: "wish_lists")
        try await pushRecords(itemsToPush, table: "wish_items")

        // ── 5. Save background context ───────────────────────────
        try context.save()
    }

    // MARK: - Network helpers (nonisolated — run off main thread)

    private nonisolated static func fetchRemote() async throws -> ([WishListRecord], [WishItemRecord]) {
        async let lists: [WishListRecord] = supabase
            .from("wish_lists")
            .select()
            .execute()
            .value

        async let items: [WishItemRecord] = supabase
            .from("wish_items")
            .select()
            .execute()
            .value

        return try await (lists, items)
    }

    private nonisolated static func pushRecords<T: Encodable>(_ records: [T], table: String) async throws {
        guard !records.isEmpty else { return }
        try await supabase
            .from(table)
            .upsert(records)
            .execute()
    }

    /// Upload images concurrently (up to 4 at a time). Returns [path: publicURL].
    private nonisolated static func uploadImagesParallel(_ uploads: [(Data, String)]) async -> [String: String] {
        await withTaskGroup(of: (String, String?).self) { group in
            for (data, path) in uploads {
                group.addTask {
                    do {
                        try await supabase.storage
                            .from("item-images")
                            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
                        let url = try? supabase.storage.from("item-images").getPublicURL(path: path)
                        return (path, url?.absoluteString)
                    } catch {
                        return (path, nil)
                    }
                }
            }
            var results: [String: String] = [:]
            for await (path, url) in group {
                if let url { results[path] = url }
            }
            return results
        }
    }

    // MARK: - Apply remote → local (nonisolated for background context use)

    private nonisolated static func applyRemote(_ remote: WishListRecord, to local: WishList) {
        local.name       = remote.name
        local.emoji      = remote.emoji
        local.colorHex   = remote.colorHex
        local.isShared   = remote.isShared
        local.shareToken = remote.shareToken
        local.isPinned   = remote.isPinned
        local.isArchived = remote.isArchived
        local.ownerID    = remote.ownerID.uuidString
        local.updatedAt  = remote.updatedAt
        local.endDate    = remote.endDate
        local.reminders  = ReminderOption.decoded(from: remote.reminders)
    }

    private nonisolated static func applyRemote(_ remote: WishItemRecord, to local: WishItem) {
        local.title                = remote.title
        local.notes                = remote.notes
        local.url                  = remote.url
        local.imageURL             = remote.imageURL
        local.price                = remote.priceDouble.map { Decimal($0) }
        local.currency             = remote.currency
        if let p = Priority(rawValue: remote.priority) { local.priority = p }
        local.isPurchased          = remote.isPurchased
        local.isReservedByFriend   = remote.isReservedByFriend
        local.reservedByName       = remote.reservedByName
        local.reservedComment      = remote.reservedComment
        local.endDate              = remote.endDate
        local.reminders            = ReminderOption.decoded(from: remote.reminders)
        local.isPinned             = remote.isPinned
        local.isArchived           = remote.isArchived
        local.updatedAt            = remote.updatedAt
    }

    private nonisolated static func makeItem(from record: WishItemRecord, list: WishList) -> WishItem {
        let item = WishItem(
            id: record.id,
            title: record.title,
            notes: record.notes,
            url: record.url,
            imageURL: record.imageURL,
            price: record.priceDouble.map { Decimal($0) },
            currency: record.currency,
            priority: Priority(rawValue: record.priority) ?? .medium,
            isPurchased: record.isPurchased,
            isReservedByFriend: record.isReservedByFriend,
            reservedByName: record.reservedByName,
            reservedComment: record.reservedComment,
            endDate: record.endDate,
            isPinned: record.isPinned,
            isArchived: record.isArchived,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            list: list
        )
        item.reminders = ReminderOption.decoded(from: record.reminders)
        return item
    }
}
