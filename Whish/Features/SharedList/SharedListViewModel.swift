import Foundation
import Supabase

/// Fetches and manages a publicly shared wishlist (no auth required).
/// Uses the `claim_item` / `unclaim_item` RPCs via the anon Supabase key.
/// Subscribes to Supabase Realtime for live reservation updates.
@Observable
@MainActor
final class SharedListViewModel {

    // MARK: - State

    private(set) var list: WishListRecord?
    private(set) var items: [WishItemRecord] = []
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var claimingItemID: UUID?

    /// Item IDs claimed by this device (persisted across sessions).
    private(set) var myClaimedIDs: Set<UUID> = []

    private static let claimsKey = "gimme_my_claimed_ids"

    private var realtimeTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.claimsKey),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            myClaimedIDs = Set(ids)
        }
    }

    // MARK: - Load

    func load(shareToken: String) async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let lists: [WishListRecord] = try await supabase
                .from("wish_lists")
                .select()
                .eq("share_token", value: shareToken)
                .eq("is_shared", value: true)
                .limit(1)
                .execute()
                .value

            guard let record = lists.first else {
                loadError = "This wishlist doesn't exist or is no longer shared."
                return
            }

            list = record

            let fetched: [WishItemRecord] = try await supabase
                .from("wish_items")
                .select()
                .eq("list_id", value: record.id.uuidString)
                .eq("is_archived", value: false)
                .order("is_pinned", ascending: false)
                .order("created_at", ascending: false)
                .execute()
                .value

            items = fetched

            // Start listening for live changes
            subscribeToChanges(listID: record.id)

        } catch {
            loadError = "Couldn't load this wishlist. Check your connection and try again."
        }
    }

    // MARK: - Realtime

    /// Subscribes to Postgres changes on wish_items for this list.
    /// Updates reservation state in real time when other friends claim/unclaim.
    private func subscribeToChanges(listID: UUID) {
        realtimeTask?.cancel()
        realtimeTask = Task { [weak self] in
            let channel = supabase.realtimeV2.channel("shared-list-\(listID.uuidString.prefix(8))")

            let changes = await channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "wish_items",
                filter: "list_id=eq.\(listID.uuidString)"
            )

            do {
                try await channel.subscribeWithError()
            } catch {
                return
            }

            for await action in changes {
                guard !Task.isCancelled else { break }
                await self?.handleRealtimeChange(action)
            }

            await supabase.realtimeV2.removeChannel(channel)
        }
    }

    private func handleRealtimeChange(_ action: AnyAction) {
        switch action {
        case .update(let update):
            guard let record = try? update.decodeRecord(as: WishItemRecord.self, decoder: .init()) else { return }
            if let i = items.firstIndex(where: { $0.id == record.id }) {
                // Don't overwrite if we're the one who just claimed (already updated locally)
                if claimingItemID != record.id {
                    items[i].isReservedByFriend = record.isReservedByFriend
                    items[i].reservedByName = record.reservedByName
                    items[i].reservedComment = record.reservedComment
                    items[i].isPurchased = record.isPurchased
                }
            }
        case .insert(let insert):
            if let record = try? insert.decodeRecord(as: WishItemRecord.self, decoder: .init()),
               !items.contains(where: { $0.id == record.id }) {
                items.insert(record, at: 0)
            }
        case .delete(let delete):
            if let old = try? delete.decodeOldRecord(as: WishItemRecord.self, decoder: .init()) {
                items.removeAll { $0.id == old.id }
            }
        }
    }

    func stopRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    // MARK: - Claim

    func claim(itemID: UUID, shareToken: String, name: String, comment: String) async {
        claimingItemID = itemID
        defer { claimingItemID = nil }

        do {
            struct Params: Encodable {
                let p_item_id: String
                let p_share_token: String
                let p_claimer_name: String
                let p_comment: String?
            }
            struct RPCResult: Decodable { let error: String? }

            let result: RPCResult = try await supabase
                .rpc("claim_item", params: Params(
                    p_item_id: itemID.uuidString,
                    p_share_token: shareToken,
                    p_claimer_name: name,
                    p_comment: comment.isEmpty ? nil : comment
                ))
                .execute()
                .value

            guard result.error == nil else { return }

            if let i = items.firstIndex(where: { $0.id == itemID }) {
                items[i].isReservedByFriend = true
                items[i].reservedByName = name
                items[i].reservedComment = comment.isEmpty ? nil : comment
            }
            myClaimedIDs.insert(itemID)
            persistClaims()
        } catch {}
    }

    // MARK: - Unclaim

    func unclaim(itemID: UUID, shareToken: String) async {
        claimingItemID = itemID
        defer { claimingItemID = nil }

        do {
            struct Params: Encodable {
                let p_item_id: String
                let p_share_token: String
            }
            struct RPCResult: Decodable { let error: String? }

            let result: RPCResult = try await supabase
                .rpc("unclaim_item", params: Params(
                    p_item_id: itemID.uuidString,
                    p_share_token: shareToken
                ))
                .execute()
                .value

            guard result.error == nil else { return }

            if let i = items.firstIndex(where: { $0.id == itemID }) {
                items[i].isReservedByFriend = false
                items[i].reservedByName = nil
                items[i].reservedComment = nil
            }
            myClaimedIDs.remove(itemID)
            persistClaims()
        } catch {}
    }

    // MARK: - Persistence

    private func persistClaims() {
        let ids = Array(myClaimedIDs)
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: Self.claimsKey)
        }
    }
}
