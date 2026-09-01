import SwiftUI
import SwiftData
import UIKit
import UserNotifications

struct WishItemDetailView: View {
    let item: WishItem
    let wishList: WishList

    @State private var viewModel = ItemDetailViewModel()
    @State private var isShowingClearReservationConfirm = false
    @State private var isCheckingPrice = false
    @State private var isShowingPricePaywall = false
    @State private var isShowingTargetInput = false
    @State private var targetInputText = ""
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @AppStorage("priceAlertsEnabled") private var priceAlertsEnabled = true
    @Environment(\.modelContext) private var modelContext
    private var modelContainer: ModelContainer { modelContext.container }
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(SyncService.self) private var syncService
    @Environment(PurchaseService.self) private var purchaseService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

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

                    // Price tracking
                    if item.url != nil, !item.isPurchased,
                       item.price != nil || !item.priceHistory.isEmpty {
                        priceTrackingCard
                    }

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
        .sheet(isPresented: $isShowingPricePaywall) { PaywallView().pageSheet() }
        .alert("Alert below", isPresented: $isShowingTargetInput) {
            TextField("Target price", text: $targetInputText)
                .keyboardType(.decimalPad)
            Button("Set") { applyTargetPrice() }
            if item.targetPrice != nil {
                Button("Remove", role: .destructive) { item.targetPrice = nil }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let low = item.priceHistory.map(\.price).min(), item.priceHistory.count >= 2 {
                Text("Get notified when the price falls to this amount. Lowest seen: \(Decimal(low).formatted(currency: item.currency)).")
            } else {
                Text("Get notified when the price falls to this amount.")
            }
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

            // Price — shows "was/now" once tracking detects a drop
            if let price = item.price, price > 0 {
                HStack(spacing: Theme.Spacing.sm) {
                    if item.hasPriceDrop, let baseline = item.baselinePrice {
                        Text(baseline.formatted(currency: item.currency))
                            .font(.rounded(.subheadline, weight: .medium))
                            .strikethrough(true, color: Theme.Colors.textTertiary)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    Text(price.formatted(currency: item.currency))
                        .font(.rounded(.title3, weight: .semibold))
                        .foregroundStyle(item.hasPriceDrop ? Theme.Colors.purchased : accessibleGlowText)
                    if item.hasPriceDrop, let drop = item.priceDropFraction {
                        PriceDropBadge(fraction: drop)
                    }
                }
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


    // MARK: - Price tracking

    private var priceTrackingCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .foregroundStyle(accessibleGlowText)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Price tracking")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    if !purchaseService.isPro {
                        Text("\(PriceTrackingService.trackedCount(in: modelContext))/\(PriceTrackingService.freeTrackedLimit) free items")
                            .font(.system(.caption2))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                Spacer()
                Toggle("Price tracking", isOn: Binding(
                    get: { item.isPriceTrackingEnabled },
                    set: { setPriceTracking($0) }
                ))
                .labelsHidden()
                .tint(accessibleGlow)
            }
            .padding(Theme.Spacing.cardInner)

            if item.isPriceTrackingEnabled {
                Divider().background(Theme.Colors.surfaceBorder)
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    // Verdict + where the current price sits in the seen range.
                    if let verdict = item.priceVerdict {
                        PriceVerdictChip(verdict: verdict)
                        if let current = item.price.map({ NSDecimalNumber(decimal: $0).doubleValue }),
                           let low = item.priceHistory.map(\.price).min(),
                           let high = item.priceHistory.map(\.price).max() {
                            PriceRangeBar(low: low, high: high, current: current,
                                          currency: item.currency, dotColor: verdict.color)
                        }
                    }

                    // History — labelled with its span so the sparkline has scale.
                    if item.priceHistory.count >= 2 {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Price history")
                                Spacer()
                                if let since = item.priceHistory.first?.date {
                                    Text("since \(since.formatted(.dateTime.day().month(.abbreviated)))")
                                }
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Colors.textTertiary)

                            PriceHistoryChart(history: item.priceHistory,
                                              currency: item.currency,
                                              tint: accessibleGlow)
                        }
                    } else {
                        Text("Watching this price — you'll get an alert when it drops.")
                            .font(.system(.caption))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    // Alerts can't reach the user — say so instead of failing silently.
                    if let reason = alertBlockReason {
                        PriceAlertPermissionRow(message: reason,
                                                opensSettings: notificationStatus == .denied) {
                            resolveAlertPermission()
                        }
                    }

                    // Two equal-weight actions: configure the alert, or refresh now.
                    HStack(spacing: Theme.Spacing.sm) {
                        PriceActionButton(
                            icon: item.targetPrice == nil ? "bell" : "bell.fill",
                            title: item.targetPrice.map { "Below \($0.formatted(currency: item.currency))" }
                                ?? "Set alert",
                            tint: isTargetMet ? Theme.Colors.purchased : accessibleGlowText,
                            isFilled: item.targetPrice != nil
                        ) {
                            presentTargetInput()
                        }
                        PriceActionButton(
                            icon: "arrow.clockwise",
                            title: "Check now",
                            tint: accessibleGlowText,
                            isBusy: isCheckingPrice
                        ) {
                            checkPriceNow()
                        }
                    }

                    if let checked = item.lastPriceCheckAt {
                        Text("Checked \(checked.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(Theme.Spacing.cardInner)
            }
        }
        .background(Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .animation(Theme.quickSpring, value: item.isPriceTrackingEnabled)
        .task(id: item.isPriceTrackingEnabled) { await refreshNotificationStatus() }
        .onChange(of: scenePhase) { _, phase in
            // Catches the user granting permission over in iOS Settings.
            if phase == .active { Task { await refreshNotificationStatus() } }
        }
    }

    /// Current price is at or below the user's alert target.
    private var isTargetMet: Bool {
        guard let target = item.targetPriceDouble,
              let current = item.price.map({ NSDecimalNumber(decimal: $0).doubleValue })
        else { return false }
        return current <= target + PriceDropRule.epsilon
    }

    // MARK: Alert deliverability

    /// Why a price drop wouldn't reach the user, or nil when alerts will land.
    private var alertBlockReason: String? {
        if !priceAlertsEnabled {
            return "Price Drop Alerts are switched off in Settings."
        }
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return nil
        case .denied:
            return "Allow notifications in Settings to hear about drops."
        default:
            return "Turn on notifications to hear about drops."
        }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await NotificationService.shared.authorizationStatus()
    }

    /// One tap fixes whatever is blocking alerts: the master switch, the
    /// permission prompt, or a trip to iOS Settings once denied.
    private func resolveAlertPermission() {
        if !priceAlertsEnabled { priceAlertsEnabled = true }
        Task {
            if notificationStatus == .denied {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    _ = await UIApplication.shared.open(url)
                }
            } else {
                _ = await NotificationService.shared.requestPermission()
                Haptics.selection()
            }
            await refreshNotificationStatus()
        }
    }

    // MARK: Target price

    private func presentTargetInput() {
        targetInputText = item.targetPrice.map { Self.plainAmount($0) } ?? suggestedTargetText
        isShowingTargetInput = true
        Haptics.selection()
    }

    /// Seeds the prompt with something worth accepting: the lowest price seen,
    /// or 10% under today's price when there's no history to go on.
    private var suggestedTargetText: String {
        let lowSeen = item.priceHistory.map(\.price).min()
        let current = item.price.map { NSDecimalNumber(decimal: $0).doubleValue }
        guard let anchor = [lowSeen, current].compactMap({ $0 }).min(), anchor > 0 else { return "" }
        // Nothing lower than today has been seen — suggest 10% under instead of
        // a target that's already met.
        let isAtCurrentPrice = lowSeen == nil || (current.map { anchor >= $0 } ?? false)
        let suggestion = isAtCurrentPrice ? anchor * 0.9 : anchor
        return Self.plainAmount(Decimal(round(suggestion)))
    }

    /// Currency-free, group-separator-free digits for the text field.
    private static func plainAmount(_ value: Decimal) -> String {
        let rounded = NSDecimalNumber(decimal: value).doubleValue
        return rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.2f", rounded)
    }

    private func applyTargetPrice() {
        let normalized = targetInputText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Decimal(string: normalized), value > 0 else { return }
        item.targetPrice = value
        Haptics.selection()
    }

    private func setPriceTracking(_ enabled: Bool) {
        if enabled {
            guard PriceTrackingService.canTrackMore(isPro: purchaseService.isPro, in: modelContext) else {
                isShowingPricePaywall = true
                return
            }
            item.isPriceTrackingEnabled = true
            item.seedPriceHistoryIfNeeded()
            Haptics.selection()
            // Opting in is the moment to ask — otherwise drops are detected
            // and then dropped on the floor.
            Task {
                if await NotificationService.shared.authorizationStatus() == .notDetermined {
                    _ = await NotificationService.shared.requestPermission()
                }
                await refreshNotificationStatus()
            }
        } else {
            item.isPriceTrackingEnabled = false
            Haptics.selection()
        }
    }

    private func checkPriceNow() {
        guard !isCheckingPrice else { return }
        isCheckingPrice = true
        Task {
            let succeeded = await PriceTrackingService.shared.checkNow(item, context: modelContext)
            isCheckingPrice = false
            if succeeded {
                Haptics.success()
                pushThisItem()   // fetched price may have changed — sync it
            } else {
                Haptics.error()
            }
        }
    }

    // MARK: - Actions

    private var itemURL: URL? {
        item.url.flatMap { URL(string: $0) }
    }

    /// A live drop on an unpurchased item makes buying the moment's action.
    private var showsBuyCTA: Bool {
        !item.isPurchased && item.hasPriceDrop && item.price != nil && itemURL != nil
    }

    private func togglePurchased() {
        Haptics.medium()
        viewModel.togglePurchased(item)
        pushThisItem()
    }

    private func actionLabel(icon: String, title: String, foreground: Color) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
            Text(title)
                .font(.rounded(.body, weight: .semibold))
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
    }

    private var actionsSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // While a drop is live, buying leads and the purchase toggle steps
            // back to the secondary outline — two filled buttons of the same
            // weight (and, on a green list, the same colour) compete.
            if showsBuyCTA, let url = itemURL, let price = item.price {
                Link(destination: url) {
                    actionLabel(icon: "cart.fill",
                                title: "Buy at \(price.formatted(currency: item.currency))",
                                foreground: .white)
                }
                .primaryGlassBackground(color: Theme.Colors.purchased)
            }

            if item.isPurchased {
                // Mark as Wanted — faded primary (undo action)
                Button(action: togglePurchased) {
                    actionLabel(icon: "arrow.uturn.left.circle.fill",
                                title: "Mark as Wanted",
                                foreground: .white)
                }
                .buttonStyle(.plain)
                .primaryGlassBackground(color: accessibleGlow.opacity(colorScheme == .dark ? 0.45 : 0.7))
            } else if showsBuyCTA {
                // Demoted — the buy CTA above is the primary action.
                Button(action: togglePurchased) {
                    actionLabel(icon: "checkmark.circle.fill",
                                title: "Mark as Purchased",
                                foreground: Theme.Colors.textPrimary)
                }
                .buttonStyle(.plain)
                .glassCapsuleBackground()
            } else {
                // Mark as Purchased — primary glass
                Button(action: togglePurchased) {
                    actionLabel(icon: "checkmark.circle.fill",
                                title: "Mark as Purchased",
                                foreground: .white)
                }
                .buttonStyle(.plain)
                .primaryGlassBackground(color: accessibleGlow)
            }

            // Plain browser link — the buy CTA already covers this when shown.
            if !showsBuyCTA, let url = itemURL {
                Link(destination: url) {
                    actionLabel(icon: "safari",
                                title: "Open in Browser",
                                foreground: Theme.Colors.textPrimary)
                }
                .glassCapsuleBackground()
            }
        }
        .animation(Theme.quickSpring, value: showsBuyCTA)
    }


}

#Preview {
    NavigationStack {
        WishItemDetailView(item: PreviewData.sampleItem, wishList: PreviewData.sampleList)
    }
    .modelContainer(PreviewData.container)
}
