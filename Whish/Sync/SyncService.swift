import Foundation
import SwiftData
import Supabase

/// Bidirectional sync engine between SwiftData and Supabase.
///
/// Architecture:
///  • Mutations set `needsSync = true` on the model; a targeted per-record push
///    drains that flag in the background (500ms debounce coalesces rapid edits).
///  • Foreground sync pulls only rows with `updated_at > lastSyncAt` (incremental).
///  • If a push fails, `needsSync` stays true — `retryOutbox()` picks it up on the
///    next foreground cycle. Guarantees zero data loss even across app kills.
///  • `syncAll` remains as a full-reconcile fallback for pull-to-refresh and
///    the manual-sync button. Clears `needsSync` on every record after success.
///
/// Conflict resolution is last-write-wins on `updated_at`.
@Observable
@MainActor
final class SyncService {

    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: String?

    private var lastSyncAttempt: Date = .distantPast
    private let minSyncInterval: TimeInterval = 5   // throttle: max once per 5 s
    private var pendingSyncTask: Task<Void, Never>?  // trailing-edge coalesce for throttled calls

    // Per-record push debouncers — coalesce rapid edits into a single upsert.
    private var pushListDebouncers: [UUID: Task<Void, Never>] = [:]
    private var pushItemDebouncers: [UUID: Task<Void, Never>] = [:]

    // Incremental pull watermark — persisted so it survives relaunches.
    private var lastIncrementalSyncAt: Date? {
        get { UserDefaults.standard.object(forKey: "syncService.lastIncrementalSyncAt") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "syncService.lastIncrementalSyncAt") }
    }

    // MARK: - Targeted push (foreground, debounced)

    /// Call after mutating a WishList. Sets `needsSync = true`, stamps `updatedAt`,
    /// and schedules a single-row upsert 500ms later (coalesces rapid edits).
    func schedulePushList(_ list: WishList, container: ModelContainer, userID: String) {
        list.needsSync = true
        list.updatedAt = .now
        list.ownerID = userID

        let id = list.id
        pushListDebouncers[id]?.cancel()
        pushListDebouncers[id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            self.pushListDebouncers[id] = nil
            await Self.pushList(id: id, container: container, userID: userID)
        }
    }

    /// Call after mutating a WishItem. Same semantics as `schedulePushList`.
    func schedulePushItem(_ item: WishItem, container: ModelContainer, userID: String) {
        item.needsSync = true
        item.updatedAt = .now

        let id = item.id
        pushItemDebouncers[id]?.cancel()
        pushItemDebouncers[id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            self.pushItemDebouncers[id] = nil
            await Self.pushItem(id: id, container: container, userID: userID)
        }
    }

    // MARK: - Foreground sync (pull + outbox drain)

    /// Lightweight sync suitable for app foreground / post-login:
    ///   1. Pull only rows updated after `lastIncrementalSyncAt`.
    ///   2. Drain the outbox (retry any records with `needsSync == true`).
    /// Runs fully off MainActor.
    func foregroundSync(container: ModelContainer, userID: String) async {
        let sp = Perf.begin("sync-foreground")
        defer { Perf.end("sync-foreground", sp) }

        guard (try? await supabase.auth.session) != nil else { return }

        let since = lastIncrementalSyncAt
        let syncStart = Date()

        await Self.pullChangesSince(since, container: container, userID: userID)
        await Self.retryOutbox(container: container, userID: userID)

        lastIncrementalSyncAt = syncStart
        lastSyncDate = .now
    }

    // MARK: - Full reconcile (pull-to-refresh, Settings manual sync)

    /// Full fetch-all + diff + push. Throttled to once per 5s unless `force` is true.
    /// On success clears `needsSync` on every record (the whole store is reconciled).
    func syncAll(container: ModelContainer, userID: String, force: Bool = false) async {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastSyncAttempt)

        if !force && elapsed < minSyncInterval {
            if pendingSyncTask == nil {
                let delay = minSyncInterval - elapsed
                pendingSyncTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(delay))
                    guard let self, !Task.isCancelled else { return }
                    self.pendingSyncTask = nil
                    await self.syncAll(container: container, userID: userID, force: true)
                }
            }
            return
        }

        pendingSyncTask?.cancel()
        pendingSyncTask = nil

        guard !isSyncing else { return }

        let _sp = Perf.begin("sync-all")
        defer { Perf.end("sync-all", _sp) }

        lastSyncAttempt = now
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            try await Self.performSync(container: container, userID: userID)
            lastIncrementalSyncAt = now
            lastSyncDate = .now
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Delete

    func deleteList(id: UUID) async {
        _ = try? await supabase
            .from("wish_lists")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteItem(id: UUID) async {
        _ = try? await supabase
            .from("wish_items")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Targeted push (nonisolated, off-main)

    private nonisolated static func pushList(id: UUID, container: ModelContainer, userID: String) async {
        guard let ownerUUID = UUID(uuidString: userID) else { return }
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false

        let descriptor = FetchDescriptor<WishList>(predicate: #Predicate { $0.id == id })
        guard let list = (try? ctx.fetch(descriptor))?.first else { return }

        let record = WishListRecord(from: list, ownerID: ownerUUID)
        do {
            try await supabase.from("wish_lists").upsert(record).execute()
            list.needsSync = false
            list.ownerID = ownerUUID.uuidString
            try? ctx.save()
        } catch {
            // Leave needsSync = true — retryOutbox will pick it up.
        }
    }

    private nonisolated static func pushItem(id: UUID, container: ModelContainer, userID: String) async {
        guard let ownerUUID = UUID(uuidString: userID) else { return }
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false

        let descriptor = FetchDescriptor<WishItem>(predicate: #Predicate { $0.id == id })
        guard let item = (try? ctx.fetch(descriptor))?.first,
              let parentList = item.list else { return }

        // Upload pending image first so the upserted row includes the URL.
        if item.imageURL == nil, let data = item.imageData, !data.isEmpty {
            let path = "\(ownerUUID.uuidString.lowercased())/\(id.uuidString.lowercased()).jpg"
            let compressed = ImageCompressor.compress(data) ?? data
            do {
                try await supabase.storage
                    .from("item-images")
                    .upload(path, data: compressed, options: FileOptions(contentType: "image/jpeg", upsert: true))
                if let url = try? supabase.storage.from("item-images").getPublicURL(path: path) {
                    item.imageURL = url.absoluteString
                    item.updatedAt = .now
                }
            } catch {
                // Image upload failed — push row anyway, retry on next outbox drain.
            }
        }

        let record = WishItemRecord(from: item, listID: parentList.id, ownerID: ownerUUID)
        do {
            try await supabase.from("wish_items").upsert(record).execute()
            item.needsSync = false
            try? ctx.save()
        } catch {
            // Leave needsSync = true.
        }
    }

    // MARK: - Incremental pull

    /// Pull only rows with `updated_at > since` (or everything if `since` is nil).
    /// Apply changes via background ModelContext. Runs fully off MainActor.
    private nonisolated static func pullChangesSince(_ since: Date?, container: ModelContainer, userID: String) async {
        let sp = Perf.begin("sync-pull-incremental")
        defer { Perf.end("sync-pull-incremental", sp) }

        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceString = iso.string(from: since ?? .distantPast)

        async let remoteLists: [WishListRecord] = {
            do {
                return try await supabase
                    .from("wish_lists")
                    .select()
                    .gt("updated_at", value: sinceString)
                    .execute()
                    .value
            } catch {
                return []
            }
        }()

        async let remoteItems: [WishItemRecord] = {
            do {
                return try await supabase
                    .from("wish_items")
                    .select()
                    .gt("updated_at", value: sinceString)
                    .execute()
                    .value
            } catch {
                return []
            }
        }()

        let (lists, items) = await (remoteLists, remoteItems)
        guard !lists.isEmpty || !items.isEmpty else { return }

        // Apply lists
        let localLists = (try? ctx.fetch(FetchDescriptor<WishList>())) ?? []
        let localListsByID = Dictionary(uniqueKeysWithValues: localLists.map { ($0.id, $0) })

        for remote in lists {
            if let local = localListsByID[remote.id] {
                if remote.updatedAt > (local.updatedAt ?? .distantPast) {
                    applyRemote(remote, to: local)
                    local.needsSync = false
                }
            } else {
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
                    updatedAt: remote.updatedAt,
                    endDate: remote.endDate,
                    reminders: ReminderOption.decoded(from: remote.reminders),
                    anonymousReservations: remote.anonymousReservations
                )
                list.needsSync = false
                ctx.insert(list)
            }
        }

        // Apply items (must be after lists so parent references resolve)
        let localItems = (try? ctx.fetch(FetchDescriptor<WishItem>())) ?? []
        let localItemsByID = Dictionary(uniqueKeysWithValues: localItems.map { ($0.id, $0) })
        let allLists = (try? ctx.fetch(FetchDescriptor<WishList>())) ?? []
        let listsByID = Dictionary(uniqueKeysWithValues: allLists.map { ($0.id, $0) })

        for remote in items {
            if let local = localItemsByID[remote.id] {
                if remote.updatedAt > (local.updatedAt ?? .distantPast) {
                    applyRemote(remote, to: local)
                    local.needsSync = false
                }
            } else if let parentList = listsByID[remote.listID] {
                let item = makeItem(from: remote, list: parentList)
                item.needsSync = false
                ctx.insert(item)
                parentList.items.append(item)
            }
        }

        try? ctx.save()
    }

    // MARK: - Outbox retry

    /// Drain all records with `needsSync == true`. Bounded to 4 concurrent pushes.
    private nonisolated static func retryOutbox(container: ModelContainer, userID: String) async {
        let sp = Perf.begin("sync-outbox-drain")
        defer { Perf.end("sync-outbox-drain", sp) }

        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false

        let pendingListIDs: [UUID] = {
            let d = FetchDescriptor<WishList>(predicate: #Predicate { $0.needsSync == true })
            return ((try? ctx.fetch(d)) ?? []).map { $0.id }
        }()
        let pendingItemIDs: [UUID] = {
            let d = FetchDescriptor<WishItem>(predicate: #Predicate { $0.needsSync == true })
            return ((try? ctx.fetch(d)) ?? []).map { $0.id }
        }()

        guard !pendingListIDs.isEmpty || !pendingItemIDs.isEmpty else { return }

        // Bounded concurrency: push lists first (items depend on list existence),
        // then items. Up to 4 concurrent HTTP calls at a time.
        await drainBounded(pendingListIDs, maxConcurrent: 4) { id in
            await pushList(id: id, container: container, userID: userID)
        }
        await drainBounded(pendingItemIDs, maxConcurrent: 4) { id in
            await pushItem(id: id, container: container, userID: userID)
        }
    }

    private nonisolated static func drainBounded(
        _ ids: [UUID],
        maxConcurrent: Int,
        push: @escaping @Sendable (UUID) async -> Void
    ) async {
        guard !ids.isEmpty else { return }
        var iterator = ids.makeIterator()
        await withTaskGroup(of: Void.self) { group in
            var inFlight = 0
            while inFlight < maxConcurrent, let id = iterator.next() {
                group.addTask { await push(id) }
                inFlight += 1
            }
            while await group.next() != nil {
                inFlight -= 1
                if let id = iterator.next() {
                    group.addTask { await push(id) }
                    inFlight += 1
                }
            }
        }
    }

    // MARK: - Heavy sync (runs off @MainActor) — fallback for pull-to-refresh / manual

    /// All SwiftData fetches, image compression, diffing, and model mutations
    /// happen on a background ModelContext. Network calls are already nonisolated.
    /// After this method saves the background context, SwiftData propagates
    /// changes to the main context automatically via persistent-store notifications,
    /// so @Query properties in SwiftUI will refresh.
    private nonisolated static func performSync(container: ModelContainer, userID: String) async throws {
        guard let ownerUUID = UUID(uuidString: userID) else { return }

        // Ensure the Supabase client has loaded the session before any requests.
        // On first launch the cached session may be available to AuthService before
        // the client's internal token is ready, causing unauthenticated upserts.
        _ = try await supabase.auth.session

        let sp = Perf.begin("sync-perform")
        defer { Perf.end("sync-perform", sp) }

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

        // ── 5. Clear outbox flags on every record — full reconcile leaves nothing pending.
        for list in try context.fetch(FetchDescriptor<WishList>()) { list.needsSync = false }
        for item in try context.fetch(FetchDescriptor<WishItem>()) { item.needsSync = false }

        // ── 6. Save background context ───────────────────────────
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
