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

/// Equal-weight control for the price-tracking card's action row.
/// Outlined by default; filled once it carries a value (e.g. a set target),
/// so "configured" reads at a glance without a second label.
struct PriceActionButton: View {
    let icon: String
    let title: String
    var tint: Color = Theme.Colors.accent
    var isFilled: Bool = false
    var isBusy: Bool = false
    let action: () -> Void

    private var foreground: Color { isFilled ? .white : tint }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foreground)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background {
                Capsule()
                    .fill(isFilled ? tint : Theme.Colors.surfaceElevated)
                    .overlay(
                        Capsule().strokeBorder(isFilled ? Color.clear : tint.opacity(0.35),
                                               lineWidth: 1)
                    )
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .animation(Theme.quickSpring, value: isFilled)
    }
}

/// Inline nudge shown when an item is tracked but alerts can't reach the user —
/// otherwise notifications are dropped silently and tracking looks broken.
struct PriceAlertPermissionRow: View {
    let message: String
    /// True when the only remedy is the iOS Settings app (permission denied).
    let opensSettings: Bool
    let action: () -> Void

    private let warning = Color(hex: "#FF851B")

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 13))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Alerts are off")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: opensSettings ? "arrow.up.forward.app" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(warning)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                warning.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
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
        PriceAlertPermissionRow(message: "Turn on notifications to hear about drops.",
                                opensSettings: false) {}
        HStack(spacing: 8) {
            PriceActionButton(icon: "bell", title: "Set alert") {}
            PriceActionButton(icon: "arrow.clockwise", title: "Check now") {}
        }
        HStack(spacing: 8) {
            PriceActionButton(icon: "bell.fill", title: "Below $180",
                              tint: Theme.Colors.purchased, isFilled: true) {}
            PriceActionButton(icon: "arrow.clockwise", title: "Check now", isBusy: true) {}
        }
    }
    .padding()
}
