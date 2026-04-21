import SwiftUI
import SwiftData

struct WishListDetailView: View {
    let wishList: WishList

    @Query private var items: [WishItem]
    @Query private var allLists: [WishList]
    @State private var viewModel = ListDetailViewModel()
    @State private var isShowingEditList = false
    @State private var shareURL: URL?
    @State private var pendingShareURL: URL?
    @State private var isShowingPaywall = false
    @State private var isShowingRevokeAlert = false
    @State private var showCopiedFeedback = false
    @State private var isShowingAuthForShare = false
    @AppStorage("defaultCurrency") private var defaultCurrency = "USD"
    @AppStorage("itemViewMode") private var isGridMode = true
    @State private var showNavTitle = false
    @State private var pendingNavigationListID: UUID?
    @State private var syncDebounceTask: Task<Void, Never>?

@Environment(\.modelContext) private var modelContext
    private var modelContainer: ModelContainer { modelContext.container }
    @Environment(SyncService.self) private var syncService
    @Environment(AuthService.self) private var auth
    @Environment(PurchaseService.self) private var purchase
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.colorScheme) private var colorScheme

    init(wishList: WishList) {
        self.wishList = wishList
        let id = wishList.persistentModelID
        _items = Query(
            filter: #Predicate<WishItem> { $0.list?.persistentModelID == id },
            sort: \WishItem.createdAt,
            order: .reverse
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.backgroundGradient.ignoresSafeArea()

            LinearGradient(
                colors: [Color(hex: wishList.colorHex).opacity(0.12), .clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.35)
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            if items.isEmpty {
                emptyState
            } else if isGridMode {
                gridContent
            } else {
                listContent
            }

            if !items.isEmpty {
                fabButton.padding(.bottom, 32)
            }
        }
        .navigationTitle(showNavTitle ? "\(wishList.emoji) \(wishList.name)" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                shareButton
                    .overlay(alignment: .top) {
                        if showCopiedFeedback {
                            Text("Link Copied")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.accent, in: Capsule())
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .offset(y: 40)
                        }
                    }
                    .animation(Theme.spring, value: showCopiedFeedback)
            }
        }
        .sheet(item: $shareURL) { url in
            ShareSheetView(items: [url])
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView()
                .pageSheet()
        }
        .sheet(isPresented: $isShowingAuthForShare) {
            AuthView()
                .pageSheet()
        }
        .alert("Stop Sharing?", isPresented: $isShowingRevokeAlert) {
            Button("Stop Sharing", role: .destructive) {
                wishList.revokeShare()
                if let uid = auth.userID {
                    Task { await syncService.syncAll(container: modelContainer, userID: uid, force: true) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Anyone with the current link will no longer be able to view this list.")
        }
        .sheet(isPresented: $viewModel.isShowingAddItem, onDismiss: {
            debouncedSync()
            if let targetID = pendingNavigationListID {
                pendingNavigationListID = nil
                router.pendingAction = .openList(targetID)
            }
        }) {
            AddItemView(wishList: wishList, itemToEdit: viewModel.itemToEdit) { savedList in
                if savedList.id != wishList.id {
                    pendingNavigationListID = savedList.id
                }
            }
            .pageSheet()
        }
        .sheet(isPresented: $isShowingEditList, onDismiss: { debouncedSync() }) {
            NewListView(listToEdit: wishList)
                .pageSheet()
        }
        .onChange(of: pendingShareURL) { _, url in
            guard let url else { return }
            pendingShareURL = nil
            // Brief delay so the Button→Menu swap settles before presenting
            Task { try? await Task.sleep(for: .milliseconds(150)); shareURL = url }
        }
    }

    // MARK: - Shared header rows

    // MARK: - Share button
    // Uses @State isSharedSnapshot to keep the view identity stable during the share flow.
    // Without this, ensureShareToken() flips wishList.isShared mid-presentation,
    // SwiftUI swaps Button↔Menu, destroys the view tree, and the sheet dismisses.

    @ViewBuilder
    private var shareButton: some View {
        if wishList.isShared {
            Menu {
                if let url = wishList.shareURL {
                    Button {
                        UIPasteboard.general.url = url
                        showCopiedFeedback = true
                        Haptics.success()
                        Task { try? await Task.sleep(for: .milliseconds(1500)); showCopiedFeedback = false }
                    } label: {
                        Label("Copy Link", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button(role: .destructive) {
                        isShowingRevokeAlert = true
                    } label: {
                        Label("Stop Sharing", systemImage: "link.badge.plus")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Shared")
                }
            }
        } else {
            Button {
                let sharedCount = allLists.filter { $0.isShared }.count
                let canShareFree = wishList.isShared || sharedCount < 2
                guard purchase.isPro || canShareFree else {
                    isShowingPaywall = true
                    return
                }
                guard auth.isSignedIn else {
                    isShowingAuthForShare = true
                    return
                }
                pendingShareURL = wishList.ensureShareToken()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
            }
        }
    }

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button { isShowingEditList = true } label: {
                    Text("\(wishList.emoji) \(wishList.name)")
                        .font(.rounded(.largeTitle, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            if let endDate = wishList.endDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                    Text(endDate.formatted(.dateTime.day().month(.wide).year()))
                        .font(.system(.subheadline, weight: .medium))
                    if let days = daysUntilEvent(endDate) {
                        Text("(\(days)d left)")
                            .font(.system(.subheadline))
                    }
                }
                .foregroundStyle(eventDateColor(for: endDate))
            }
        }
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.lg)
        .padding(.horizontal, Theme.Spacing.gridPadding)
    }

    private func eventDateColor(for date: Date) -> Color {
        if date < .now { return .red }
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        return days <= 7 ? .red : Theme.Colors.textSecondary
    }

    private func daysUntilEvent(_ date: Date) -> Int? {
        guard date > .now else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: date).day
    }

    private var filterAndStatsRow: some View {
        VStack(spacing: Theme.Spacing.md) {
            filterPicker
            if viewModel.filter == .all { statsStrip }
        }
        .padding(.horizontal, Theme.Spacing.gridPadding)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.lg)
        .contentShape(Rectangle())
    }

    // MARK: - List content
    // List is the root scroll container — required for .swipeActions to work on iOS.
    private var listContent: some View {
        let displayed = viewModel.filteredAndSorted(items)
        return List {
            titleRow
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            filterAndStatsRow
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparatorTint(.clear)

            // ── Empty state ───────────────────────────────────────
            if displayed.isEmpty {
                ContentUnavailableView(
                    "No \(viewModel.filter.rawValue) Items",
                    systemImage: "tray",
                    description: Text("Switch filters or add more items.")
                )
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.top, 60)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // ── Active items ──────────────────────────────────────
            ForEach(displayed) { item in
                ZStack {
                    NavigationLink(value: item) { EmptyView() }.opacity(0)
                    WishItemCard(item: item, listColor: Color(hex: wishList.colorHex)) {
                        Haptics.medium()
                        viewModel.togglePurchased(item)
                        debouncedSync()
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Haptics.heavy()
                        let id = item.id
                        withAnimation(Theme.spring) { viewModel.deleteItem(item, in: modelContext) }
                        debouncedSync()
                        if auth.isSignedIn {
                            Task { await syncService.deleteItem(id: id) }
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button { viewModel.showEditItem(item) } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                    Button {
                        Haptics.medium()
                        viewModel.togglePurchased(item)
                        debouncedSync()
                    } label: {
                        Label(item.isPurchased ? "Unmark" : "Purchased",
                              systemImage: item.isPurchased ? "arrow.uturn.left" : "checkmark")
                    }
                    .tint(item.isPurchased ? .orange : Theme.Colors.purchased)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Haptics.light()
                        withAnimation(Theme.spring) { viewModel.pinItem(item) }
                        debouncedSync()
                    } label: {
                        Label(item.isPinned ? "Unpin" : "Pin",
                              systemImage: item.isPinned ? "pin.slash.fill" : "pin.fill")
                    }
                    .tint(.orange)
                }
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .contextMenu {
                    Button { viewModel.showEditItem(item) } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button {
                        Haptics.medium()
                        viewModel.togglePurchased(item)
                        debouncedSync()
                    } label: {
                        Label(item.isPurchased ? "Mark Wanted" : "Mark Purchased",
                              systemImage: item.isPurchased ? "arrow.uturn.left" : "checkmark.circle")
                    }
                    Button {
                        Haptics.light()
                        viewModel.pinItem(item)
                        debouncedSync()
                    } label: {
                        Label(item.isPinned ? "Unpin" : "Pin",
                              systemImage: item.isPinned ? "pin.slash" : "pin")
                    }
                    Divider()
                    Button(role: .destructive) {
                        Haptics.heavy()
                        let id = item.id
                        withAnimation(Theme.spring) { viewModel.deleteItem(item, in: modelContext) }
                        debouncedSync()
                        if auth.isSignedIn {
                            Task { await syncService.deleteItem(id: id) }
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: Theme.Spacing.cardGap / 2,
                    leading: Theme.Spacing.gridPadding,
                    bottom: Theme.Spacing.cardGap / 2,
                    trailing: Theme.Spacing.gridPadding
                ))
            }

        }
        .listStyle(.plain)
        .refreshable {
            if let uid = auth.userID {
                await syncService.syncAll(container: modelContainer, userID: uid, force: true)
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 100, for: .scrollContent)
        .background(
            ListScrollObserver { offset in
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNavTitle = offset > 60
                }
            }
        )
    }

    // MARK: - Grid content

    private var gridContent: some View {
        let displayed = viewModel.filteredAndSorted(items)
        let columns   = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        let listColor = Color(hex: wishList.colorHex)

        return ScrollView {
            VStack(spacing: 0) {
                titleRow
                filterAndStatsRow

                if displayed.isEmpty {
                    ContentUnavailableView(
                        "No \(viewModel.filter.rawValue) Items",
                        systemImage: "tray",
                        description: Text("Switch filters or add more items.")
                    )
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, 60)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(displayed) { item in
                        NavigationLink(value: item) {
                            WishItemGridCard(item: item, listColor: listColor) {
                                Haptics.medium()
                                viewModel.togglePurchased(item)
                                debouncedSync()
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                        .contextMenu {
                            Button { viewModel.showEditItem(item) } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                Haptics.medium()
                                viewModel.togglePurchased(item)
                                debouncedSync()
                            } label: {
                                Label(item.isPurchased ? "Mark Wanted" : "Mark Purchased",
                                      systemImage: item.isPurchased ? "arrow.uturn.left" : "checkmark.circle")
                            }
                            Button {
                                Haptics.light()
                                viewModel.pinItem(item)
                                debouncedSync()
                            } label: {
                                Label(item.isPinned ? "Unpin" : "Pin",
                                      systemImage: item.isPinned ? "pin.slash" : "pin")
                            }
                            Divider()
                            Button(role: .destructive) {
                                Haptics.heavy()
                                let id = item.id
                                withAnimation(Theme.spring) { viewModel.deleteItem(item, in: modelContext) }
                                debouncedSync()
                                if auth.isSignedIn {
                                    Task { await syncService.deleteItem(id: id) }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.gridPadding)
                .padding(.top, Theme.Spacing.sm)
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 100, for: .scrollContent)
        .background(
            ListScrollObserver { offset in
                withAnimation(.easeInOut(duration: 0.2)) { showNavTitle = offset > 60 }
            }
        )
    }

    // MARK: - Filter picker
    private var filterPicker: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(ItemFilter.allCases, id: \.self) { f in
                Button {
                    Haptics.selection()
                    withAnimation(Theme.spring) { viewModel.filter = f }
                } label: {
                    Text(f.rawValue)
                        .font(.system(.subheadline, weight: viewModel.filter == f ? .semibold : .regular))
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.sm)
                        .foregroundStyle(
                            viewModel.filter == f
                            ? .white
                            : Theme.Colors.textSecondary
                        )
                        .background(
                            viewModel.filter == f
                            ? Color(hex: wishList.colorHex)
                            : Theme.Colors.surfaceElevated,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Menu {
                sortMenu
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Theme.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            Button {
                Haptics.selection()
                withAnimation(Theme.spring) { isGridMode.toggle() }
            } label: {
                Image(systemName: isGridMode ? "list.bullet" : "square.grid.2x2")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Theme.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Stats strip
    private var statsStrip: some View {
        let purchasedCount = items.lazy.filter(\.isPurchased).count
        let wantCount = items.count - purchasedCount
        return HStack(spacing: 0) {
            if let total = totalPrice {
                stripStat(label: defaultCurrency, value: total, flexible: true)
                Divider().frame(height: 28)
            }
            stripStat(label: "Total",  value: "\(items.count)")
            Divider().frame(height: 28)
            stripStat(label: "Want",   value: "\(wantCount)")
            Divider().frame(height: 28)
            stripStat(label: "Got",    value: "\(purchasedCount)")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .background(Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
    }

    private func stripStat(label: String, value: String, flexible: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.rounded(.footnote, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: flexible ? .infinity : 56)
        .padding(.horizontal, flexible ? 0 : 4)
    }

    private var totalPrice: String? {
        let priced = items.compactMap { item -> Decimal? in
            guard let price = item.price else { return nil }
            return convertCurrency(price, from: item.currency ?? "USD", to: defaultCurrency)
        }
        guard !priced.isEmpty else { return nil }
        return priced.reduce(Decimal(0), +).formatted(currency: defaultCurrency)
    }

        // MARK: - Sync helper

    private func debouncedSync() {
        syncDebounceTask?.cancel()
        syncDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            syncAfterChange()
        }
    }

    private func syncAfterChange() {
        guard let uid = auth.userID else { return }
        Task {
            await syncService.syncAll(container: modelContainer, userID: uid)
            WidgetDataService.scheduleUpdate(context: modelContext)
        }
    }

    // MARK: - FAB
    private var fabButton: some View {
        Button { Haptics.light(); viewModel.showAddItem() } label: {
            let c = Color(hex: wishList.colorHex)
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Add Item")
                    .font(.rounded(.body, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.leading, Theme.Spacing.md)
            .padding(.trailing, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .primaryGlassBackground(color: c)
            .shadow(color: .black.opacity(0.28), radius: 20, y: 8)
            .shadow(color: c.opacity(0.35), radius: 12, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            titleRow

            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: wishList.colorHex))
            Text("Nothing here yet")
                .font(.rounded(.title3, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Add your first wish to get started.")
                .foregroundStyle(Theme.Colors.textSecondary)
            Button { viewModel.showAddItem() } label: {
                Text("Add Wish")
                    .font(.rounded(.body, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.md)
                    .primaryGlassBackground(color: Color(hex: wishList.colorHex))
                    .shadow(color: .black.opacity(0.28), radius: 20, y: 8)
                    .shadow(color: Color(hex: wishList.colorHex).opacity(0.35), radius: 12, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sort menu
    private var sortMenu: some View {
        ForEach(ItemSort.allCases, id: \.self) { s in
            Button {
                withAnimation(Theme.spring) { viewModel.sort = s }
            } label: {
                if viewModel.sort == s {
                    Label(s.rawValue, systemImage: "checkmark")
                } else {
                    Text(s.rawValue)
                }
            }
        }
    }
}

// MARK: - Scroll offset observer (KVO on underlying UIScrollView)

private struct ListScrollObserver: UIViewRepresentable {
    let onChange: @MainActor (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }
    func makeUIView(context: Context) -> UIView { context.coordinator.probe }
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.attach()
    }

    @MainActor
    final class Coordinator: NSObject {
        let probe = UIView()
        let onChange: @MainActor (CGFloat) -> Void
        private var observation: NSKeyValueObservation?

        init(onChange: @escaping @MainActor (CGFloat) -> Void) {
            self.onChange = onChange
        }

        func attach() {
            guard observation == nil else { return }
            var v: UIView? = probe.superview
            while let current = v {
                if let scrollView = current as? UIScrollView {
                    observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] sv, _ in
                        let y = sv.contentOffset.y
                        Task { @MainActor [weak self] in self?.onChange(y) }
                    }
                    return
                }
                v = current.superview
            }
        }

        deinit { observation?.invalidate() }
    }
}

#Preview {
    NavigationStack {
        WishListDetailView(wishList: WishList(name: "Tech Gear", emoji: "💻", colorHex: "#B3D9FF"))
    }
    .modelContainer(PreviewData.container)
}
