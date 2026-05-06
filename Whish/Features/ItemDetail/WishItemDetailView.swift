import SwiftUI
import SwiftData

struct WishItemDetailView: View {
    let item: WishItem
    let wishList: WishList

    @State private var viewModel = ItemDetailViewModel()
    @State private var isShowingClearReservationConfirm = false
    @Environment(\.modelContext) private var modelContext
    private var modelContainer: ModelContainer { modelContext.container }
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(SyncService.self) private var syncService
    @Environment(\.colorScheme) private var colorScheme

    /// Schedule a single-row upsert after mutating this view's item.
    private func pushThisItem() {
        guard let uid = auth.userID else { return }
        syncService.schedulePushItem(item, container: modelContainer, userID: uid)
    }

    // Accent glow colour — list colour or fallback accent
    private var glowColor: Color { Color(hex: wishList.colorHex) }

    // On light theme: darken until 3:1 contrast against cream surface
    private var accessibleGlow: Color {
        colorScheme == .dark ? glowColor : glowColor.withContrast(atLeast: 3.0, against: Theme.Colors.surfaceElevated)
    }
    // 4.5:1 for inline text (price, status dot)
    private var accessibleGlowText: Color {
        colorScheme == .dark ? glowColor : glowColor.withContrast(atLeast: 4.5, against: Theme.Colors.surfaceElevated)
    }

    var body: some View {
        ZStack {
            // Base
            Theme.backgroundGradient.ignoresSafeArea()

            // Glow radial gradient behind hero
            RadialGradient(
                colors: [glowColor.opacity(0.35), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 340
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Title + price block
                    titleBlock

                    // Hero image (only if available)
                    if item.imageData != nil || (item.imageURL != nil && !(item.imageURL!.isEmpty)) {
                        imageBlock
                    }

                    // Info card
                    infoCard

                    // Actions
                    actionsSection
                }
                .padding(Theme.Spacing.gridPadding)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if let urlString = item.url, !urlString.isEmpty,
                       let url = URL(string: urlString) {
                        Button {
                            UIPasteboard.general.url = url
                            Haptics.success()
                        } label: {
                            Label("Copy Link", systemImage: "doc.on.doc")
                        }
                        Divider()
                    }
                    Button { viewModel.isShowingEditSheet = true } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) { viewModel.isShowingDeleteConfirm = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .menuIndicator(.hidden)
            }
        }
        .sheet(isPresented: $viewModel.isShowingEditSheet) {
            AddItemView(wishList: wishList, itemToEdit: item)
                .pageSheet()
        }
        .alert("Clear Reservation?", isPresented: $isShowingClearReservationConfirm) {
            Button("Clear", role: .destructive) {
                viewModel.clearReservation(item)
                pushThisItem()
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This will mark the item as no longer reserved.") }
        .alert("Delete \"\(item.title)\"?", isPresented: $viewModel.isShowingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                let id = item.id
                viewModel.deleteItem(item, in: modelContext) { dismiss() }
                if auth.isSignedIn {
                    Task { await syncService.deleteItem(id: id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This action cannot be undone.") }
    }

    // MARK: - Title block
    private var titleBlock: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Status + priority row
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.isPurchased ? Theme.Colors.purchased : accessibleGlowText)
                        .frame(width: 8, height: 8)
                    Text(item.isPurchased ? "Purchased" : "Wanted")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(item.isPurchased ? Theme.Colors.purchased : accessibleGlowText)
                }
                Spacer()
                PriorityBadge(priority: item.priority)
            }

            // Title
            Text(item.title)
                .font(.rounded(.title2, weight: .bold))
                .foregroundStyle(item.isPurchased ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                .strikethrough(item.isPurchased, color: Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Price
            if let price = item.price, price > 0 {
                Text(price.formatted(currency: item.currency))
                    .font(.rounded(.title3, weight: .semibold))
                    .foregroundStyle(accessibleGlowText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No price set")
                    .font(.system(.subheadline))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Image block
    @ViewBuilder
    private var imageBlock: some View {
        ZStack {
            // Blurred fill — stable size via AsyncImageView (Color.clear base), no layout jump on load
            AsyncImageView(urlString: item.imageURL, imageData: item.imageData,
                           cornerRadius: 0, contentMode: .fill)
                .blur(radius: 28)
                .scaleEffect(1.15)
                .overlay(Color.black.opacity(0.18))

            // Sharp image fitted without cropping
            AsyncImageView(urlString: item.imageURL, imageData: item.imageData,
                           cornerRadius: 0, contentMode: .fit)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .drawingGroup()
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(glowColor.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Info card
    private var infoCard: some View {
        VStack(spacing: 0) {
            if let notes = item.notes, !notes.isEmpty {
                infoRow(label: "Notes", value: notes)
                Divider().background(Theme.Colors.surfaceBorder)
            }
            if item.isReservedByFriend {
                if wishList.anonymousReservations {
                    infoRow(label: "Reserved by", value: "Someone 🤫") {
                        isShowingClearReservationConfirm = true
                    }
                    Divider().background(Theme.Colors.surfaceBorder)
                } else {
                    infoRow(label: "Reserved by", value: item.reservedByName ?? "A friend") {
                        isShowingClearReservationConfirm = true
                    }
                    Divider().background(Theme.Colors.surfaceBorder)
                    if let comment = item.reservedComment, !comment.isEmpty {
                        infoRow(label: "Their message", value: comment)
                        Divider().background(Theme.Colors.surfaceBorder)
                    }
                }
            }
            infoRow(label: "List", value: "\(wishList.emoji)  \(wishList.name)")
            Divider().background(Theme.Colors.surfaceBorder)
            if let url = item.url {
                infoRow(label: "URL", value: url)
                Divider().background(Theme.Colors.surfaceBorder)
            }
            infoRow(label: "Added", value: item.createdAt.formatted(date: .abbreviated, time: .omitted))
        }
        .background(Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private func infoRow(label: String, value: String, clearAction: (() -> Void)? = nil) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
            if let clearAction {
                Button("Clear", action: clearAction)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(Theme.Spacing.cardInner)
    }


    // MARK: - Actions
    private var actionsSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            if item.isPurchased {
                // Mark as Wanted — faded primary (undo action)
                Button { Haptics.medium(); viewModel.togglePurchased(item); pushThisItem() } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "arrow.uturn.left.circle.fill")
                        Text("Mark as Wanted")
                            .font(.rounded(.body, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.lg)
                }
                .buttonStyle(.plain)
                .primaryGlassBackground(color: accessibleGlow.opacity(colorScheme == .dark ? 0.45 : 0.7))
            } else {
                // Mark as Purchased — primary glass
                Button { Haptics.medium(); viewModel.togglePurchased(item); pushThisItem() } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Mark as Purchased")
                            .font(.rounded(.body, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.lg)
                }
                .buttonStyle(.plain)
                .primaryGlassBackground(color: accessibleGlow)
            }

            // Open in browser — secondary glass outline
            if let urlString = item.url, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "safari")
                        Text("Open in Browser")
                            .font(.rounded(.body, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.lg)
                }
                .glassCapsuleBackground()
            }
        }
    }


}

#Preview {
    NavigationStack {
        WishItemDetailView(item: PreviewData.sampleItem, wishList: PreviewData.sampleList)
    }
    .modelContainer(PreviewData.container)
}
