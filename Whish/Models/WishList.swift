import Foundation
import SwiftData

@Model
final class WishList {
    var id: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var createdAt: Date
    var isShared: Bool
    var shareToken: String?
    var isPinned: Bool
    var isArchived: Bool
    /// Supabase user UUID — nil for local-only lists, set when synced.
    var ownerID: String?
    /// Last mutation time — used for conflict resolution during sync. nil = never synced.
    var updatedAt: Date?
    /// Outbox flag — true when local mutation hasn't been pushed to Supabase yet.
    /// Defaults to true so the first launch after this field is added triggers a one-time reconcile.
    var needsSync: Bool = true
    var endDate: Date?
    /// JSON-encoded `[String]` of `ReminderOption` raw values.
    var remindersRaw: String = "[]"
    var anonymousReservations: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \WishItem.list)
    var items: [WishItem] = []

    var reminders: Set<ReminderOption> {
        get { ReminderOption.decoded(from: remindersRaw) }
        set { remindersRaw = ReminderOption.encoded(newValue) }
    }

    var itemCount: Int { items.count }
    var unpurchasedCount: Int { items.filter { !$0.isPurchased }.count }

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "✨",
        colorHex: String = "#6C63FF",
        createdAt: Date = .now,
        isShared: Bool = false,
        shareToken: String? = nil,
        isPinned: Bool = false,
        isArchived: Bool = false,
        ownerID: String? = nil,
        updatedAt: Date? = nil,
        endDate: Date? = nil,
        reminders: Set<ReminderOption> = [],
        anonymousReservations: Bool = false
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.isShared = isShared
        self.shareToken = shareToken
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.ownerID = ownerID
        self.updatedAt = updatedAt
        self.endDate = endDate
        self.remindersRaw = ReminderOption.encoded(reminders)
        self.anonymousReservations = anonymousReservations
    }
}
