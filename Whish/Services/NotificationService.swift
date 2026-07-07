import Foundation
import UserNotifications

/// Manages local notifications for wishlist item deadlines.
/// Notification IDs use the format `"{uuid}_{reminderOption.rawValue}"` to allow
/// multiple reminders per entity.
struct NotificationService: Sendable {
    static let shared = NotificationService()
    private init() {}

    // MARK: - Permission

    /// Requests notification authorization. Returns true if authorized.
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return true
        case .denied: return false
        default: break
        }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Schedule

    /// Schedules one notification per selected reminder option, all firing at 09:00
    /// on the appropriate day relative to `endDate`. Clears any prior notifications
    /// for this entity first.
    func scheduleReminders(id: UUID, title: String, endDate: Date,
                           reminders: Set<ReminderOption>) async {
        cancelAll(id: id)

        guard !reminders.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        let cal = Calendar.current

        for option in reminders {
            let targetDay = cal.date(byAdding: .day, value: option.dayOffset, to: endDate) ?? endDate
            guard let fireDate = cal.date(bySettingHour: 9, minute: 0, second: 0, of: targetDay),
                  fireDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Don't forget: \(title)"
            content.body = notificationBody(for: option)
            content.sound = .default
            content.userInfo = ["itemID": id.uuidString, "reminderType": option.rawValue]

            let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "\(id.uuidString)_\(option.rawValue)"
            let request = UNNotificationRequest(identifier: identifier,
                                                content: content,
                                                trigger: trigger)
            try? await center.add(request)
        }
    }

    // MARK: - Price drops

    /// Immediate local notification for a detected price drop. One pending
    /// notification per item — a newer drop replaces the previous one.
    func sendPriceDropAlert(itemID: UUID, listID: UUID?, itemTitle: String,
                            oldPrice: Decimal, newPrice: Decimal, currency: String?) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }

        let oldDouble = NSDecimalNumber(decimal: oldPrice).doubleValue
        let newDouble = NSDecimalNumber(decimal: newPrice).doubleValue
        let percent = oldDouble > 0
            ? Int((((oldDouble - newDouble) / oldDouble) * 100).rounded())
            : 0

        let content = UNMutableNotificationContent()
        content.title = "📉 Price drop: \(itemTitle)"
        content.body = "Now \(newPrice.formatted(currency: currency)) — was \(oldPrice.formatted(currency: currency)) (\(percent)% off)"
        content.sound = .default
        var userInfo: [String: String] = ["item_id": itemID.uuidString]
        if let listID { userInfo["list_id"] = listID.uuidString }
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: "price-drop-\(itemID.uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    // MARK: - Cancel

    /// Removes all pending notifications for this entity (all reminder types + legacy format).
    func cancelAll(id: UUID) {
        var ids = ReminderOption.allCases.map { "\(id.uuidString)_\($0.rawValue)" }
        ids.append(id.uuidString) // Legacy single-ID cleanup
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Helpers

    private func notificationBody(for option: ReminderOption) -> String {
        switch option {
        case .onTheDay:        return "Today is the day!"
        case .oneDayBefore:    return "Your event is tomorrow."
        case .threeDaysBefore: return "Your event is in 3 days."
        case .oneWeekBefore:   return "Your event is in 1 week."
        }
    }
}
