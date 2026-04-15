import SwiftData
import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var auth

    @State private var isShowingConfirm = false
    @State private var contentHeight: CGFloat = 0

    private let consequences: [(icon: String, text: String)] = [
        ("list.bullet.rectangle", "All your wishlists will be deleted"),
        ("gift",                  "All items and saved prices will be removed"),
        ("icloud.slash",          "Data will be wiped from all devices"),
        ("xmark.circle",          "This cannot be undone"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                // Header
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 60, height: 60)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.red.opacity(0.85))
                    }

                    Text("Delete Account")
                        .font(.rounded(.title3, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("This is permanent and cannot be reversed.")
                        .font(.system(.subheadline))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Theme.Spacing.gridPadding)
                .padding(.bottom, Theme.Spacing.lg)

                // Consequences list
                VStack(spacing: 0) {
                    ForEach(Array(consequences.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.red.opacity(0.1))
                                    .frame(width: 32, height: 32)
                                Image(systemName: item.icon)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.red.opacity(0.8))
                            }
                            Text(item.text)
                                .font(.system(.subheadline))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, Theme.Spacing.cardInner)

                        if index < consequences.count - 1 {
                            Rectangle()
                                .fill(Theme.Colors.surfaceBorder)
                                .frame(height: 0.5)
                                .padding(.leading, 60)
                        }
                    }
                }
                .background(Theme.Colors.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .padding(.horizontal, Theme.Spacing.gridPadding)
                .padding(.bottom, Theme.Spacing.lg)

                // Error
                if let error = auth.errorMessage {
                    Text(error)
                        .font(.system(.caption))
                        .foregroundStyle(.red.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.gridPadding)
                        .padding(.bottom, Theme.Spacing.sm)
                }

                // Delete button
                Button {
                    isShowingConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Delete My Account")
                                .font(.rounded(.body, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
                    .background(Color.red.opacity(auth.isLoading ? 0.5 : 0.85),
                                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(auth.isLoading)
                .padding(.horizontal, Theme.Spacing.gridPadding)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        contentHeight = geo.size.height
                    }
                }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
        }
        .alert("Delete Account Forever?", isPresented: $isShowingConfirm) {
            Button("Delete Forever", role: .destructive) {
                Task {
                    await auth.deleteAccount {
                        try modelContext.delete(model: WishList.self)
                        try modelContext.delete(model: WishItem.self)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All your wishlists and items will be permanently deleted. This cannot be undone.")
        }
        .presentationCornerRadius(Theme.Radius.sheet)
        .presentationDetents(contentHeight > 0 ? [.height(contentHeight + 56)] : [.medium])
        .presentationDragIndicator(.hidden)
        .presentationBackground {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Theme.backgroundGradient.opacity(0.85)
            }
        }
    }
}
