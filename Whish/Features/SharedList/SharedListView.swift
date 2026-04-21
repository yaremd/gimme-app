import SwiftUI

/// Read-only view of a publicly shared wishlist, opened via Universal Link.
/// Friends can claim / unclaim items directly from here.
struct SharedListView: View {
    let shareToken: String

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SharedListViewModel()

    // Claim sheet
    @State private var claimTarget: WishItemRecord?
    @State private var claimerName = ""
    @State private var claimerComment = ""
    @State private var isClaimSheetVisible = false

    private var accentColor: Color {
        Color(hex: viewModel.list?.colorHex ?? "#6C63FF")
    }

    private var isAnonymous: Bool {
        viewModel.list?.anonymousReservations ?? false
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            LinearGradient(
                colors: [accentColor.opacity(0.12), .clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.3)
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(.easeInOut, value: accentColor)

            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.loadError {
                    errorView(message: error)
                } else if let list = viewModel.list {
                    listContent(list: list)
                }
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                            .background(.fill, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                    .padding(.leading, 16)
                    Spacer()
                }
                Spacer()
            }
        }
        .task { await viewModel.load(shareToken: shareToken) }
        .onDisappear { viewModel.stopRealtime() }
        .sheet(isPresented: $isClaimSheetVisible, onDismiss: {
            claimerName = ""
            claimerComment = ""
            claimTarget = nil
        }) {
            if let item = claimTarget {
                claimSheet(for: item)
                    .pageSheet()
            }
        }
    }

    // MARK: - List content

    @ViewBuilder
    private func listContent(list: WishListRecord) -> some View {
        let remaining = viewModel.items.filter { !$0.isPurchased }

        ScrollView {
            VStack(spacing: 0) {
                Color.clear.frame(height: 56)

                // ── Header ───────────────────────────────────────
                VStack(spacing: Theme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 90, height: 90)
                        Text(list.emoji)
                            .font(.system(size: 48))
                    }
                    VStack(spacing: 4) {
                        Text(list.name)
                            .font(.rounded(.title2, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(
                            "\(viewModel.items.count) item\(viewModel.items.count == 1 ? "" : "s")" +
                            (remaining.count < viewModel.items.count
                                ? " · \(remaining.count) remaining"
                                : "")
                        )
                        .font(.system(.subheadline))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)

                // ── Items ─────────────────────────────────────────
                if viewModel.items.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(viewModel.items, id: \.id) { item in
                            SharedItemCard(
                                item: item,
                                isMyClaim: viewModel.myClaimedIDs.contains(item.id),
                                isLoading: viewModel.claimingItemID == item.id,
                                isAnonymous: isAnonymous,
                                accentColor: accentColor,
                                onClaim: {
                                    claimTarget = item
                                    isClaimSheetVisible = true
                                },
                                onUnclaim: {
                                    Task {
                                        await viewModel.unclaim(
                                            itemID: item.id,
                                            shareToken: shareToken
                                        )
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.gridPadding)
                    .padding(.bottom, 60)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("✨")
                .font(.system(size: 48))
            Text("Nothing on this list yet")
                .font(.rounded(.title3, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(Theme.Colors.accent)
            Text("Loading wishlist…")
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("🔍")
                .font(.system(size: 48))
            Text(message)
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                Task { await viewModel.load(shareToken: shareToken) }
            } label: {
                Text("Try Again")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Claim sheet

    @ViewBuilder
    private func claimSheet(for item: WishItemRecord) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.Colors.textTertiary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, Theme.Spacing.lg)

            if let imageURL = item.imageURL {
                AsyncImageView(urlString: imageURL, imageData: nil, cornerRadius: 14)
                    .frame(width: 64, height: 64)
                    .padding(.bottom, Theme.Spacing.md)
            }

            Text(item.title)
                .font(.rounded(.title3, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.gridPadding)

            if let price = item.priceDouble, let currency = item.currency {
                Text(Decimal(price).formatted(currency: currency))
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.top, 4)
            }

            VStack(spacing: Theme.Spacing.md) {
                if !isAnonymous {
                    TextField("Your name *", text: $claimerName)
                        .padding(Theme.Spacing.cardInner)
                        .background(
                            Theme.Colors.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        )
                }

                TextField("Leave a message (optional)", text: $claimerComment)
                    .padding(Theme.Spacing.cardInner)
                    .background(
                        Theme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    )
            }
            .padding(.horizontal, Theme.Spacing.gridPadding)
            .padding(.top, Theme.Spacing.xl)

            let trimmedName = claimerName.trimmingCharacters(in: .whitespaces)
            let canClaim = isAnonymous || !trimmedName.isEmpty

            Button {
                guard canClaim else { return }
                let comment = claimerComment.trimmingCharacters(in: .whitespaces)
                isClaimSheetVisible = false
                Task {
                    await viewModel.claim(
                        itemID: item.id,
                        shareToken: shareToken,
                        name: isAnonymous ? "" : trimmedName,
                        comment: comment
                    )
                }
            } label: {
                Text("I'll get this 🎁")
                    .font(.rounded(.body, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        canClaim
                            ? Theme.Colors.accent
                            : Theme.Colors.accent.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canClaim)
            .padding(.horizontal, Theme.Spacing.gridPadding)
            .padding(.top, Theme.Spacing.xl)

            Button("Cancel") { isClaimSheetVisible = false }
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.vertical, Theme.Spacing.lg)

            Spacer()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - SharedItemCard

private struct SharedItemCard: View {
    let item: WishItemRecord
    let isMyClaim: Bool
    let isLoading: Bool
    let isAnonymous: Bool
    let accentColor: Color
    let onClaim: () -> Void
    let onUnclaim: () -> Void

    private var isUnavailable: Bool {
        item.isPurchased || (item.isReservedByFriend && !isMyClaim)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            AsyncImageView(urlString: item.imageURL, imageData: nil, cornerRadius: Theme.Radius.image)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(isUnavailable ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .strikethrough(item.isPurchased, color: Theme.Colors.textSecondary)

                if let price = item.priceDouble, let currency = item.currency {
                    Text(Decimal(price).formatted(currency: currency))
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(isUnavailable ? Theme.Colors.textTertiary : accentColor)
                }

                statusBadge
            }

            Spacer(minLength: 0)

            actionButton
        }
        .padding(Theme.Spacing.cardInner)
        .background(
            isUnavailable
                ? Theme.Colors.surfaceElevated.opacity(0.5)
                : Theme.Colors.surfaceElevated,
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        )
        .opacity(isUnavailable ? 0.65 : 1.0)
        .shadow(
            color: .black.opacity(Theme.Shadow.cardOpacity),
            radius: Theme.Shadow.cardRadius,
            y: Theme.Shadow.cardY
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        if item.isPurchased {
            badge("Purchased", color: Theme.Colors.purchased)
        } else if item.isReservedByFriend {
            if isMyClaim {
                badge("You're getting this ✓", color: accentColor)
            } else if !isAnonymous, let name = item.reservedByName, !name.isEmpty {
                badge("Reserved by \(name)", color: Theme.Colors.textTertiary)
            } else {
                badge("Reserved", color: Theme.Colors.textTertiary)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isLoading {
            ProgressView()
                .frame(width: 44, height: 44)
                .tint(accentColor)
        } else if !item.isPurchased {
            if isMyClaim {
                Button(action: onUnclaim) {
                    Text("Undo")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.surfaceElevated, in: Capsule())
                }
                .buttonStyle(.plain)
            } else if !item.isReservedByFriend {
                Button(action: onClaim) {
                    Text("🎁")
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .background(accentColor.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func badge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.13), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 0.5))
    }
}
