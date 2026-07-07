import Foundation
import SwiftData

@Model
final class WishItem {
    var id: UUID
    var title: String
    var notes: String?
    var url: String?
    var imageURL: String?
    @Attribute(.externalStorage) var imageData: Data?
    private var priceDouble: Double?
    var currency: String?
    var priority: Priority
    var isPurchased: Bool
    var isReservedByFriend: Bool
    var reservedByName: String?
    var reservedComment: String?
    var endDate: Date?
    var notificationsEnabled: Bool
    /// JSON-encoded `[String]` of `ReminderOption` raw values.
    var remindersRaw: String = "[]"
    var isPinned: Bool
    var isArchived: Bool
    var createdAt: Date
    /// Last mutation time — used for conflict resolution during sync. nil = never synced.
    var updatedAt: Date?
    /// Outbox flag — true when local mutation hasn't been pushed to Supabase yet.
    /// Defaults to true so the first launch after this field is added triggers a one-time reconcile.
    var needsSync: Bool = true

    // MARK: Price tracking (on-device)
    // All fields optional/defaulted — must stay lightweight-migration-safe,
    // otherwise WhishApp.init wipes the store on schema mismatch.

    /// Whether this item participates in automatic price checks.
    var isPriceTrackingEnabled: Bool = false
    /// JSON-encoded `[PricePoint]`, oldest first. Accessed via `priceHistory`.
    var priceHistoryData: Data?
    var lastPriceCheckAt: Date?
    /// Price already alerted about — suppresses repeat notifications for the same drop.
    var lastNotifiedPriceDouble: Double?
    /// Consecutive failed checks — items backing off get checked weekly instead of daily.
    var priceCheckFailureCount: Int = 0

    var list: WishList?

    var price: Decimal? {
        get { priceDouble.map { Decimal($0) } }
        set { priceDouble = newValue.map { NSDecimalNumber(decimal: $0).doubleValue } }
    }

    var reminders: Set<ReminderOption> {
        get { ReminderOption.decoded(from: remindersRaw) }
        set { remindersRaw = ReminderOption.encoded(newValue) }
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        url: String? = nil,
        imageURL: String? = nil,
        imageData: Data? = nil,
        price: Decimal? = nil,
        currency: String? = "USD",
        priority: Priority = .medium,
        isPurchased: Bool = false,
        isReservedByFriend: Bool = false,
        reservedByName: String? = nil,
        reservedComment: String? = nil,
        endDate: Date? = nil,
        notificationsEnabled: Bool = false,
        isPinned: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        list: WishList? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.url = url
        self.imageURL = imageURL
        self.imageData = imageData
        self.priceDouble = price.map { NSDecimalNumber(decimal: $0).doubleValue }
        self.currency = currency
        self.priority = priority
        self.isPurchased = isPurchased
        self.isReservedByFriend = isReservedByFriend
        self.reservedByName = reservedByName
        self.reservedComment = reservedComment
        self.endDate = endDate
        self.notificationsEnabled = notificationsEnabled
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.list = list
    }
}
