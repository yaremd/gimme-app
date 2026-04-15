import Foundation

// MARK: - WishListRecord

/// Codable DTO that maps 1:1 to the `wish_lists` Supabase table.
struct WishListRecord: Codable, Sendable {
    let id: UUID
    let ownerID: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var isShared: Bool
    var shareToken: String?
    var isPinned: Bool
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date
    var endDate: Date?
    var reminders: String

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, reminders
        case ownerID     = "owner_id"
        case colorHex    = "color_hex"
        case isShared    = "is_shared"
        case shareToken  = "share_token"
        case isPinned    = "is_pinned"
        case isArchived  = "is_archived"
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
        case endDate     = "end_date"
    }

    init(from list: WishList, ownerID: UUID) {
        id          = list.id
        self.ownerID = ownerID
        name        = list.name
        emoji       = list.emoji
        colorHex    = list.colorHex
        isShared    = list.isShared
        shareToken  = list.shareToken
        isPinned    = list.isPinned
        isArchived  = list.isArchived
        createdAt   = list.createdAt
        updatedAt   = list.updatedAt ?? list.createdAt
        endDate     = list.endDate
        reminders   = ReminderOption.encoded(list.reminders)
    }
}

// MARK: - WishItemRecord

/// Codable DTO that maps 1:1 to the `wish_items` Supabase table.
/// `imageData` is intentionally excluded — binary blobs sync via Storage in Phase 4.
struct WishItemRecord: Codable, Sendable {
    let id: UUID
    let listID: UUID
    let ownerID: UUID
    var title: String
    var notes: String?
    var url: String?
    var imageURL: String?
    var priceDouble: Double?
    var currency: String?
    var priority: String
    var isPurchased: Bool
    var isReservedByFriend: Bool
    var reservedByName: String?
    var reservedComment: String?
    var endDate: Date?
    var notificationsEnabled: Bool
    var reminders: String
    var isPinned: Bool
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, notes, url, currency, priority, reminders
        case listID               = "list_id"
        case ownerID              = "owner_id"
        case imageURL             = "image_url"
        case priceDouble          = "price_double"
        case isPurchased          = "is_purchased"
        case isReservedByFriend   = "is_reserved_by_friend"
        case reservedByName       = "reserved_by_name"
        case reservedComment      = "reserved_comment"
        case endDate              = "end_date"
        case notificationsEnabled = "notifications_enabled"
        case isPinned             = "is_pinned"
        case isArchived           = "is_archived"
        case createdAt            = "created_at"
        case updatedAt            = "updated_at"
    }

    init(from item: WishItem, listID: UUID, ownerID: UUID) {
        id                   = item.id
        self.listID          = listID
        self.ownerID         = ownerID
        title                = item.title
        notes                = item.notes
        url                  = item.url
        imageURL             = item.imageURL
        priceDouble          = item.price.map { NSDecimalNumber(decimal: $0).doubleValue }
        currency             = item.currency
        priority             = item.priority.rawValue
        isPurchased          = item.isPurchased
        isReservedByFriend   = item.isReservedByFriend
        reservedByName       = item.reservedByName
        reservedComment      = item.reservedComment
        endDate              = item.endDate
        notificationsEnabled = !item.reminders.isEmpty
        reminders            = ReminderOption.encoded(item.reminders)
        isPinned             = item.isPinned
        isArchived           = item.isArchived
        createdAt            = item.createdAt
        updatedAt            = item.updatedAt ?? item.createdAt
    }
}
