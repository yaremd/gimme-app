import SwiftUI

struct WishItemCard: View {
    let item: WishItem
    var listColor: Color = Theme.Colors.accent
    var onTogglePurchased: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var priceColor: Color {
        colorScheme == .dark ? listColor : listColor.withContrast(atLeast: 4.5, against: Theme.Colors.surfaceElevated)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Thumbnail
            AsyncImageView(urlString: item.imageURL, imageData: item.imageData, cornerRadius: Theme.Radius.image)
                .frame(width: 60, height: 60)

            // Content
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(item.isPurchased ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .strikethrough(item.isPurchased, color: Theme.Colors.textSecondary)

                if let price = item.price, price > 0 {
                    Text(price.formatted(currency: item.currency))
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(item.isPurchased ? Theme.Colors.textSecondary : priceColor)
                } else {
                    Text("No price set")
                        .font(.system(.subheadline))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    PriorityBadge(priority: item.priority, compact: true)

                    if item.isReservedByFriend {
                        Text("Reserved")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Theme.Colors.textSecondary.opacity(0.13), in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.Colors.textSecondary.opacity(0.25), lineWidth: 0.5))
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: Theme.Spacing.sm) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                        .rotationEffect(.degrees(45))
                }
                // Purchased toggle
                Button { onTogglePurchased?() } label: {
                    Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(item.isPurchased ? listColor : Theme.Colors.textTertiary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.9))
            }
        }
        .padding(Theme.Spacing.cardInner)
        .background(Theme.Colors.surfaceElevated,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(Theme.Shadow.cardOpacity),
                radius: Theme.Shadow.cardRadius, y: Theme.Shadow.cardY)
        .opacity(item.isPurchased ? 0.7 : 1.0)
    }
}

#Preview {
    VStack(spacing: 10) {
        WishItemCard(item: PreviewData.sampleItem)
        WishItemCard(item: {
            let i = WishItem(title: "Purchased Item", price: Decimal(49.99), isPurchased: true)
            return i
        }())
    }
    .padding()
    .background(Theme.Colors.background)
    .modelContainer(PreviewData.container)
}

// MARK: - Grid card (2-column view)

struct WishItemGridCard: View {
    let item: WishItem
    var listColor: Color = Theme.Colors.accent
    var onTogglePurchased: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var hasMedia: Bool { item.imageData != nil || (item.imageURL != nil && !(item.imageURL ?? "").isEmpty) }

    private var priceColor: Color {
        colorScheme == .dark ? listColor : listColor.withContrast(atLeast: 4.5, against: Theme.Colors.surfaceElevated)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageArea
            contentArea
        }
        .background(Theme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .opacity(item.isPurchased ? 0.65 : 1.0)
    }

    private var imageArea: some View {
        ZStack {
            ZStack {
                if hasMedia {
                    Theme.Colors.textTertiary.opacity(0.06)
                    AsyncImageView(urlString: item.imageURL, imageData: item.imageData,
                                   cornerRadius: 0, contentMode: .fit)
                } else {
                    Theme.Colors.textTertiary.opacity(0.08)
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Theme.Colors.textTertiary.opacity(0.40))
                }

                // Purchased overlay
                if item.isPurchased {
                    Color.black.opacity(0.3)
                }
            }
            .frame(height: 150)
            .clipped()

            // Priority badge — top-left corner
            VStack {
                HStack {
                    PriorityBadge(priority: item.priority, compact: false, filled: true)
                    Spacer()
                }
                Spacer()
            }
            .padding(8)

            // Purchase toggle — top-right corner
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onTogglePurchased?()
                    } label: {
                        Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.9))
                }
                Spacer()
            }
            .padding(6)
        }
    }

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(item.isPurchased ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                .lineLimit(2)
                .strikethrough(item.isPurchased, color: Theme.Colors.textSecondary)

            if let price = item.price, price > 0 {
                Text(price.formatted(currency: item.currency))
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(item.isPurchased ? Theme.Colors.textSecondary : priceColor)
            } else {
                Text("No price set")
                    .font(.system(.footnote))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            Spacer(minLength: 0)

            if item.isPinned || item.isReservedByFriend {
                HStack(spacing: 4) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.orange)
                            .rotationEffect(.degrees(45))
                    }
                    if item.isReservedByFriend {
                        Text("Reserved")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.Colors.textSecondary.opacity(0.13), in: Capsule())
                    }
                }
            }
        }
        .padding(Theme.Spacing.cardInner)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
    }
}
