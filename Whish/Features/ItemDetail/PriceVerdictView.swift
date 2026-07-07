import SwiftUI

extension PriceVerdict {
    var label: String {
        switch self {
        case .lowestYet:       return "Lowest price yet"
        case .goodPrice:       return "Good price"
        case .typical:         return "Typical price"
        case .higherThanUsual: return "Higher than usual"
        }
    }

    var icon: String {
        switch self {
        case .lowestYet:       return "arrow.down"
        case .goodPrice:       return "checkmark"
        case .typical:         return "minus"
        case .higherThanUsual: return "arrow.up"
        }
    }

    var color: Color {
        switch self {
        case .lowestYet, .goodPrice: return Theme.Colors.purchased
        case .typical:               return Theme.Colors.textSecondary
        case .higherThanUsual:       return Color(hex: "#FF851B")
        }
    }
}

/// Capsule chip stating the price verdict ("Lowest price yet", …).
struct PriceVerdictChip: View {
    let verdict: PriceVerdict

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: verdict.icon)
                .font(.system(size: 10, weight: .bold))
            Text(verdict.label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(verdict.color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(verdict.color.opacity(0.14), in: Capsule())
    }
}

/// Low↔high track with a dot marking where the current price sits —
/// readable without interpreting a chart.
struct PriceRangeBar: View {
    let low: Double
    let high: Double
    let current: Double
    let currency: String?
    let dotColor: Color

    private var fraction: CGFloat {
        guard high > low else { return 0 }
        return CGFloat(min(max((current - low) / (high - low), 0), 1))
    }

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.surfaceBorder)
                        .frame(height: 4)
                    Circle()
                        .fill(dotColor)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(Theme.Colors.surface, lineWidth: 2))
                        .offset(x: fraction * (geo.size.width - 12))
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 12)

            HStack {
                Text("\(Decimal(low).formatted(currency: currency)) low")
                Spacer()
                Text("\(Decimal(high).formatted(currency: currency)) high")
            }
            .font(.system(.caption2, weight: .medium))
            .foregroundStyle(Theme.Colors.textTertiary)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        PriceVerdictChip(verdict: .lowestYet)
        PriceVerdictChip(verdict: .goodPrice)
        PriceVerdictChip(verdict: .typical)
        PriceVerdictChip(verdict: .higherThanUsual)
        PriceRangeBar(low: 199, high: 249, current: 199, currency: "USD",
                      dotColor: Theme.Colors.purchased)
    }
    .padding()
}
