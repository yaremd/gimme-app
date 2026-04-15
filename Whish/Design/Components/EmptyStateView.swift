import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let description: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .font(.rounded(.title2, weight: .semibold))
        } description: {
            Text(description)
                .font(.system(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } actions: {
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Theme.Colors.accent)
            }
        }
    }
}

#Preview {
    EmptyStateView(
        systemImage: "sparkles",
        title: "No Lists Yet",
        description: "Create your first wishlist and start adding the things you love.",
        actionLabel: "Create a List",
        action: {}
    )
}
