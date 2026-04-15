import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let data: WidgetDisplayData

    var body: some View {
        if data.isEmpty {
            emptyState
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 12) {
            // Left: progress ring + value
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 4) {
                    if let emoji = data.emoji {
                        Text(emoji).font(.system(size: 14))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(data.accentColor)
                    }
                    Text(data.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Link(destination: data.addItemURL) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(data.accentColor)
                    }
                }

                Spacer()

                // Ring + value row
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(Color(.systemFill), lineWidth: 5)
                            .frame(width: 44, height: 44)

                        Circle()
                            .trim(from: 0, to: data.completionFraction)
                            .stroke(
                                data.accentColor,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(data.completionFraction * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if data.remainingValue > 0 {
                            Text(formatCurrency(data.remainingValue, code: data.currency))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        }
                        Text("\(data.purchasedCount)/\(data.totalItemCount) done")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                // Footer: deadline or reservations
                if let days = data.daysUntilDeadline {
                    Spacer().frame(height: 6)
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 9))
                        Text("\(days) day\(days == 1 ? "" : "s") left")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(days <= 7 ? .red : data.accentColor)
                } else if data.reservedCount > 0 {
                    Spacer().frame(height: 6)
                    HStack(spacing: 3) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 9))
                        Text("\(data.reservedCount) reserved")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(data.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Divider
            Rectangle()
                .fill(.quaternary)
                .frame(width: 1)
                .padding(.vertical, 4)

            // Right: top 3 items
            VStack(alignment: .leading, spacing: 8) {
                if data.topItems.isEmpty {
                    Text("No items yet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: .infinity)
                } else {
                    ForEach(data.topItems.prefix(3)) { item in
                        itemRow(item)
                    }
                    if data.topItems.count < 3 {
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func itemRow(_ item: WidgetItem) -> some View {
        HStack(spacing: 6) {
            Text(item.emoji)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    if item.isReserved {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                    }
                }

                if let price = item.price, let currency = item.currency {
                    Text(formatCurrency(price, code: currency))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(data.accentColor)
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 32))
                .foregroundStyle(data.accentColor.opacity(0.5))
            VStack(alignment: .leading, spacing: 4) {
                Text("No wishlists yet")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text("Open Gimme to get started")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Medium", as: .systemMedium) {
    GimmeWidget()
} timeline: {
    GimmeEntry(date: .now, snapshot: .placeholder, selectedListID: nil)
    GimmeEntry(date: .now, snapshot: .empty, selectedListID: nil)
}
