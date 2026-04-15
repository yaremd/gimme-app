import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let data: WidgetDisplayData

    var body: some View {
        if data.isEmpty {
            emptyState
        } else {
            content
        }
    }

    private var content: some View {
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

            // Progress ring + value
            HStack(spacing: 12) {
                // Ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemFill), lineWidth: 5)
                        .frame(width: 48, height: 48)

                    Circle()
                        .trim(from: 0, to: data.completionFraction)
                        .stroke(
                            data.accentColor,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(data.completionFraction * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                // Value
                VStack(alignment: .leading, spacing: 2) {
                    if data.remainingValue > 0 {
                        Text(formatCurrency(data.remainingValue, code: data.currency))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }

                    Text("\(data.purchasedCount)/\(data.totalItemCount) done")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            // Deadline or reservation info
            if let days = data.daysUntilDeadline {
                Spacer().frame(height: 8)
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9))
                    Text("\(days)d left")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(days <= 7 ? .red : data.accentColor)
            } else if data.reservedCount > 0 {
                Spacer().frame(height: 8)
                HStack(spacing: 3) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 9))
                    Text("\(data.reservedCount) reserved")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(data.accentColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 28))
                .foregroundStyle(data.accentColor.opacity(0.5))
            Text("No wishlists yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Small", as: .systemSmall) {
    GimmeWidget()
} timeline: {
    GimmeEntry(date: .now, snapshot: .placeholder, selectedListID: nil)
    GimmeEntry(date: .now, snapshot: .empty, selectedListID: nil)
}
