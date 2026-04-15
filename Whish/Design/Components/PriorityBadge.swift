import SwiftUI

struct PriorityBadge: View {
    let priority: Priority
    var compact: Bool = false
    var filled: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: priority.systemImage)
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
            if !compact {
                Text(priority.label)
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundStyle(filled ? .white : baseColor)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(filled ? baseColor : baseColor.opacity(0.15), in: Capsule())
    }

    private var baseColor: Color {
        switch priority {
        case .low:    return Color(hex: "#3D9970")
        case .medium: return Color(hex: "#FF851B")
        case .high:   return Color(hex: "#FF4136")
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        PriorityBadge(priority: .low)
        PriorityBadge(priority: .medium)
        PriorityBadge(priority: .high)
    }
    .padding()
}
