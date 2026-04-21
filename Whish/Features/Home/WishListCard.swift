import SwiftUI

struct WishListCard: View {
    let list: WishList
    /// Pre-formatted total value string — supplied by HomeView to avoid per-card O(n) loops.
    var totalText: String? = nil

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Emoji icon — coloured circle
            ZStack {
                Circle()
                    .fill(Color(hex: list.colorHex).opacity(0.25))
                    .frame(width: 52, height: 52)
                Text(list.emoji)
                    .font(.system(size: 26))
            }

            // Name + value (row 1) / item count + progress (row 2)
            VStack(alignment: .leading, spacing: 6) {
                // Row 1: name + pin icon + amount
                HStack(spacing: 4) {
                    Text(list.name)
                        .font(.rounded(.body, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    if list.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.orange)
                            .rotationEffect(.degrees(45))
                    }
                    Spacer(minLength: 0)
                    if let value = totalText {
                        Text(value)
                            .font(.rounded(.callout, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                }
                // Row 2: remaining items + event date + progress pill
                HStack {
                    Text(itemCountLabel)
                        .font(.system(.subheadline))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if let endDate = list.endDate {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9, weight: .semibold))
                            Text(endDate.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(eventDateColor(for: endDate))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            eventDateColor(for: endDate).opacity(0.1),
                            in: Capsule()
                        )
                    }
                    Spacer(minLength: 0)
                    if list.items.count > 0 {
                        ProgressPill(
                            progress: purchasedFraction,
                            color: Color(hex: list.colorHex)
                        )
                    }
                }
            }
        }
        .padding(Theme.Spacing.cardInner)
        .glassCardBackground()
        .shadow(color: .black.opacity(Theme.Shadow.cardOpacity),
                radius: Theme.Shadow.cardRadius, y: Theme.Shadow.cardY)
    }

    // MARK: - Helpers
    private var itemCountLabel: String {
        let total    = list.items.count
        let remaining = list.unpurchasedCount
        if total == 0     { return "Empty" }
        if remaining == 0 { return "All done 🎉" }
        return "\(remaining) of \(total) remaining"
    }

    private var purchasedFraction: Double {
        let total = list.items.count
        guard total > 0 else { return 0 }
        return Double(total - list.unpurchasedCount) / Double(total)
    }

    private func eventDateColor(for date: Date) -> Color {
        if date < .now { return .red }
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        return days <= 7 ? .red : Theme.Colors.textSecondary
    }

}

// MARK: - Progress Pill
private struct ProgressPill: View {
    let progress: Double
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(color.opacity(colorScheme == .dark ? 0.15 : 0.25))
                .frame(width: 48, height: 4)
            Capsule()
                .fill(color.opacity(colorScheme == .dark ? 1.0 : 0.85))
                .frame(width: max(4, 48 * progress), height: 4)
                .animation(Theme.spring, value: progress)
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        WishListCard(list: WishList(name: "Birthday", emoji: "🎂", colorHex: "#FFB3BA"))
        WishListCard(list: WishList(name: "Tech Gear", emoji: "💻", colorHex: "#B3D9FF"))
        WishListCard(list: WishList(name: "Books", emoji: "📚", colorHex: "#FFE4B3"))
    }
    .padding()
    .background(Theme.Colors.background)
}
