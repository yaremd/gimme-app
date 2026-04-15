import Foundation

enum ReminderOption: String, Codable, CaseIterable, Hashable {
    case onTheDay        = "on_the_day"
    case oneDayBefore    = "one_day_before"
    case threeDaysBefore = "three_days_before"
    case oneWeekBefore   = "one_week_before"

    var label: String {
        switch self {
        case .onTheDay:        return "On the day"
        case .oneDayBefore:    return "1 day before"
        case .threeDaysBefore: return "3 days before"
        case .oneWeekBefore:   return "1 week before"
        }
    }

    /// Short label for chip/pill UI
    var chipLabel: String {
        switch self {
        case .onTheDay:        return "Same day"
        case .oneDayBefore:    return "1 day"
        case .threeDaysBefore: return "3 days"
        case .oneWeekBefore:   return "1 week"
        }
    }

    /// Calendar offset to subtract from the end date.
    var dayOffset: Int {
        switch self {
        case .onTheDay:        return 0
        case .oneDayBefore:    return -1
        case .threeDaysBefore: return -3
        case .oneWeekBefore:   return -7
        }
    }

    // MARK: - Persistence helpers

    static func encoded(_ options: Set<ReminderOption>) -> String {
        let raw = options.map(\.rawValue).sorted()
        return (try? JSONEncoder().encode(raw)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    static func decoded(from string: String?) -> Set<ReminderOption> {
        guard let data = string?.data(using: .utf8),
              let raw = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(raw.compactMap { ReminderOption(rawValue: $0) })
    }
}
