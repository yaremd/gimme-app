import SwiftUI
import SwiftData

// MARK: - Models

struct StatSegment: Identifiable {
    let id = UUID()
    let label: String
    let emoji: String
    let value: Decimal
    let count: Int
    let color: Color
}

struct StatsInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color
}

enum StatsGroupBy: String, CaseIterable {
    case priority = "Priority"
    case list = "List"
    case status = "Status"
}

// MARK: - View Model

@Observable
@MainActor
final class StatsViewModel {
    var groupBy: StatsGroupBy = .priority
    var selectedList: WishList?
    var displayCurrency: String = "USD"

    // MARK: - Filtered items

    func filteredItems(from allItems: [WishItem]) -> [WishItem] {
        guard let selectedList else { return allItems }
        return allItems.filter { $0.list?.persistentModelID == selectedList.persistentModelID }
    }

    // MARK: - Completion metrics

    func completionFraction(items: [WishItem]) -> Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter { $0.isPurchased }.count) / Double(items.count)
    }

    func purchasedCount(items: [WishItem]) -> Int {
        items.filter { $0.isPurchased }.count
    }

    func reservedCount(items: [WishItem]) -> Int {
        items.filter { $0.isReservedByFriend }.count
    }

    // MARK: - Currency helpers

    func autoSelectCurrency(items: [WishItem]) {
        let currencies = items.compactMap { $0.currency }
        guard !currencies.isEmpty else { return }
        let freq = Dictionary(grouping: currencies, by: { $0 }).mapValues(\.count)
        if let dominant = freq.max(by: { $0.value < $1.value })?.key {
            displayCurrency = dominant
        }
    }

    func availableCurrencies(items: [WishItem]) -> [String] {
        Set(items.compactMap { $0.currency }).sorted()
    }

    func hasMultipleCurrencies(items: [WishItem]) -> Bool {
        Set(items.compactMap { $0.currency }).count > 1
    }

    private func convertedPrice(_ item: WishItem) -> Decimal? {
        guard let price = item.price else { return nil }
        return convertCurrency(price, from: item.currency ?? "USD", to: displayCurrency)
    }

    // MARK: - Segment builders

    func segments(items: [WishItem], lists: [WishList]) -> [StatSegment] {
        switch groupBy {
        case .priority: return prioritySegments(items: items)
        case .list:     return listSegments(items: items, lists: lists)
        case .status:   return statusSegments(items: items)
        }
    }

    private func prioritySegments(items: [WishItem]) -> [StatSegment] {
        Priority.allCases.compactMap { priority in
            let filtered = items.filter { $0.priority == priority }
            guard !filtered.isEmpty else { return nil }
            let total = filtered.compactMap { convertedPrice($0) }.reduce(Decimal(0), +)
            return StatSegment(
                label: priority.label,
                emoji: priorityEmoji(priority),
                value: total,
                count: filtered.count,
                color: priorityColor(priority)
            )
        }
    }

    private func listSegments(items: [WishItem], lists: [WishList]) -> [StatSegment] {
        lists.compactMap { list in
            let filtered = items.filter { $0.list?.persistentModelID == list.persistentModelID }
            guard !filtered.isEmpty else { return nil }
            let total = filtered.compactMap { convertedPrice($0) }.reduce(Decimal(0), +)
            return StatSegment(
                label: list.name,
                emoji: list.emoji,
                value: total,
                count: filtered.count,
                color: Color(hex: list.colorHex)
            )
        }
    }

    private func statusSegments(items: [WishItem]) -> [StatSegment] {
        let purchased = items.filter { $0.isPurchased }
        let reserved = items.filter { !$0.isPurchased && $0.isReservedByFriend }
        let wanted = items.filter { !$0.isPurchased && !$0.isReservedByFriend }

        var result: [StatSegment] = []
        if !purchased.isEmpty {
            result.append(StatSegment(
                label: "Purchased",
                emoji: "",
                value: purchased.compactMap { convertedPrice($0) }.reduce(Decimal(0), +),
                count: purchased.count,
                color: Theme.Colors.purchased
            ))
        }
        if !reserved.isEmpty {
            result.append(StatSegment(
                label: "Reserved",
                emoji: "",
                value: reserved.compactMap { convertedPrice($0) }.reduce(Decimal(0), +),
                count: reserved.count,
                color: Color(hex: "#FF9500")
            ))
        }
        if !wanted.isEmpty {
            result.append(StatSegment(
                label: "Wanted",
                emoji: "",
                value: wanted.compactMap { convertedPrice($0) }.reduce(Decimal(0), +),
                count: wanted.count,
                color: Theme.Colors.accent
            ))
        }
        return result
    }

    // MARK: - Aggregate stats (currency-converted)

    func totalValue(items: [WishItem]) -> Decimal {
        items.compactMap { convertedPrice($0) }.reduce(Decimal(0), +)
    }

    func purchasedValue(items: [WishItem]) -> Decimal {
        items.filter { $0.isPurchased }.compactMap { convertedPrice($0) }.reduce(Decimal(0), +)
    }

    func remainingValue(items: [WishItem]) -> Decimal {
        items.filter { !$0.isPurchased }.compactMap { convertedPrice($0) }.reduce(Decimal(0), +)
    }

    // MARK: - Insights engine

    func insights(items: [WishItem], lists: [WishList]) -> [StatsInsight] {
        var result: [StatsInsight] = []

        let total = items.count
        guard total > 0 else { return result }

        let bought = items.filter { $0.isPurchased }
        let reserved = items.filter { $0.isReservedByFriend && !$0.isPurchased }
        let wanted = items.filter { !$0.isPurchased }

        // Per-list completion (only when viewing all lists)
        if selectedList == nil {
            let completeLists = lists.filter { list in
                let listItems = items.filter { $0.list?.persistentModelID == list.persistentModelID }
                return !listItems.isEmpty && listItems.allSatisfy { $0.isPurchased }
            }
            for list in completeLists.prefix(2) {
                result.append(StatsInsight(
                    icon: "checkmark.seal.fill",
                    title: "\(list.emoji) \(list.name) — all wishes fulfilled!",
                    subtitle: nil,
                    color: Theme.Colors.purchased
                ))
            }

            // Nearly complete lists
            let nearlyComplete = lists.filter { list in
                let listItems = items.filter { $0.list?.persistentModelID == list.persistentModelID }
                guard listItems.count >= 3 else { return false }
                let pct = Double(listItems.filter { $0.isPurchased }.count) / Double(listItems.count)
                return pct >= 0.5 && pct < 1.0
            }.sorted { list1, list2 in
                let items1 = items.filter { $0.list?.persistentModelID == list1.persistentModelID }
                let items2 = items.filter { $0.list?.persistentModelID == list2.persistentModelID }
                let pct1 = Double(items1.filter { $0.isPurchased }.count) / Double(items1.count)
                let pct2 = Double(items2.filter { $0.isPurchased }.count) / Double(items2.count)
                return pct1 > pct2
            }
            if let best = nearlyComplete.first {
                let listItems = items.filter { $0.list?.persistentModelID == best.persistentModelID }
                let pct = Int(Double(listItems.filter { $0.isPurchased }.count) / Double(listItems.count) * 100)
                result.append(StatsInsight(
                    icon: "flame.fill",
                    title: "\(best.emoji) \(best.name) is \(pct)% complete",
                    subtitle: "Almost there!",
                    color: Color(hex: "#FF9500")
                ))
            }
        }

        // Reservations on shared lists
        if !reserved.isEmpty {
            let names = Set(reserved.compactMap { $0.reservedByName }).sorted()
            let subtitle = names.isEmpty ? nil : names.prefix(3).joined(separator: ", ")
            result.append(StatsInsight(
                icon: "gift.fill",
                title: "\(reserved.count) \(reserved.count == 1 ? "item" : "items") reserved by friends",
                subtitle: subtitle,
                color: Color(hex: "#FF9500")
            ))
        }

        // Upcoming deadline
        if let list = selectedList, let endDate = list.endDate, endDate > .now {
            let days = Calendar.current.dateComponents([.day], from: .now, to: endDate).day ?? 0
            if days <= 30 {
                let claimedCount = bought.count + reserved.count
                result.append(StatsInsight(
                    icon: "calendar.badge.clock",
                    title: "\(days) day\(days == 1 ? "" : "s") until event",
                    subtitle: "\(claimedCount) of \(total) items claimed",
                    color: days <= 7 ? Theme.Colors.destructive : Theme.Colors.accent
                ))
            }
        }

        // Items without prices (shared list nudge)
        let noPriceCount = wanted.filter { $0.price == nil }.count
        if noPriceCount > 0 {
            let isShared = selectedList?.isShared == true ||
                           (selectedList == nil && lists.contains { $0.isShared })
            if isShared {
                result.append(StatsInsight(
                    icon: "dollarsign.circle",
                    title: "\(noPriceCount) \(noPriceCount == 1 ? "item has" : "items have") no price",
                    subtitle: "Friends can't budget without prices",
                    color: Color(hex: "#FF9500")
                ))
            }
        }

        // Oldest unfulfilled wish
        if let oldest = wanted.min(by: { $0.createdAt < $1.createdAt }) {
            let daysSince = Calendar.current.dateComponents([.day], from: oldest.createdAt, to: .now).day ?? 0
            if daysSince >= 90 {
                let months = daysSince / 30
                let timeStr = months >= 2 ? "\(months) months ago" : "\(daysSince) days ago"
                result.append(StatsInsight(
                    icon: "clock.arrow.circlepath",
                    title: "Oldest wish: \(oldest.title)",
                    subtitle: "Added \(timeStr)",
                    color: Theme.Colors.textSecondary
                ))
            }
        }

        // Priority distribution
        let highCount = items.filter { $0.priority == .high }.count
        let pct = Int(Double(highCount) / Double(total) * 100)
        if pct >= 50 && total >= 3 {
            result.append(StatsInsight(
                icon: "arrow.up.circle.fill",
                title: "\(pct)% of wishes are High priority",
                subtitle: nil,
                color: Color(hex: "#FF4136")
            ))
        }

        // Average item price
        let priced = items.compactMap { convertedPrice($0) }
        if priced.count >= 3 {
            let avg = priced.reduce(Decimal(0), +) / Decimal(priced.count)
            result.append(StatsInsight(
                icon: "tag.fill",
                title: "Average wish costs \(avg.formatted(currency: displayCurrency))",
                subtitle: nil,
                color: Theme.Colors.accent
            ))
        }

        // Price range
        if let minPrice = priced.min(), let maxPrice = priced.max(),
           maxPrice > 0 && minPrice > 0 {
            let ratio = NSDecimalNumber(decimal: maxPrice).doubleValue /
                        NSDecimalNumber(decimal: minPrice).doubleValue
            if ratio >= 5 && priced.count >= 3 {
                result.append(StatsInsight(
                    icon: "arrow.left.and.right",
                    title: "Wishes range from \(minPrice.formatted(currency: displayCurrency)) to \(maxPrice.formatted(currency: displayCurrency))",
                    subtitle: nil,
                    color: Theme.Colors.textSecondary
                ))
            }
        }

        // Items added this month
        let now = Date.now
        let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now))!
        let thisMonthCount = items.filter { $0.createdAt >= startOfMonth }.count
        if thisMonthCount >= 3 {
            result.append(StatsInsight(
                icon: "plus.circle.fill",
                title: "\(thisMonthCount) wishes added this month",
                subtitle: nil,
                color: Theme.Colors.purchased
            ))
        }

        return result
    }

    // MARK: - Helpers

    private func priorityEmoji(_ p: Priority) -> String { "" }

    private func priorityColor(_ p: Priority) -> Color {
        switch p {
        case .high:   return Color(hex: "#FF4136")
        case .medium: return Color(hex: "#FF851B")
        case .low:    return Color(hex: "#3D9970")
        }
    }
}
