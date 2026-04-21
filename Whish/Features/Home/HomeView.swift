import SwiftUI
import SwiftData
import UserNotifications
import PhotosUI

struct HomeView: View {
    @Query(sort: \WishList.createdAt, order: .reverse) private var lists: [WishList]
    @Query private var allItems: [WishItem]

    @State private var viewModel = HomeViewModel()
    @Environment(\.modelContext) private var modelContext
    private var modelContainer: ModelContainer { modelContext.container }

    @State private var listToChangeColor: WishList?
    @State private var listToEdit: WishList?
    @State private var isShowingStats = false
    @State private var isShowingSettings = false
    private var isSearchActive: Bool {
        shouldFocusSearch || isSearchFocused || !viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    @AppStorage("defaultCurrency") private var displayCurrency = "USD"
    @State private var listShareURL: URL?

    // Share Extension hand-off
    @Environment(\.scenePhase) private var scenePhase
    @State private var pendingSharedURL: String?
    @State private var isShowingShareListPicker = false

    // Sync
    @Environment(AuthService.self) private var auth
    @Environment(SyncService.self) private var syncService
    @Environment(PurchaseService.self) private var purchase
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.colorScheme) private var colorScheme

    @State private var isShowingPaywall = false
    @State private var isShowingAuthForShare = false
    @State private var navPath = NavigationPath()
    @State private var isShowingFirstItem = false
    @State private var isShowingListPicker = false
    @State private var addFormTargetList: WishList?
    @State private var pendingNavigationListID: PersistentIdentifier?
    @State private var isShowingMergePrompt = false
    @State private var pendingMergeListCount = 0
    @State private var pendingMergeItemCount = 0
    @AppStorage("wasSignedIn") private var wasSignedIn = false

    @FocusState private var isSearchFocused: Bool
    @State private var shouldFocusSearch = false   // survives the view-transition; @FocusState does not


    @State private var isShowingNotifications = false
    @State private var notificationsViewModel = NotificationsViewModel()
    @State private var pendingNotificationItemID: UUID?

    // Cached aggregates — recomputed once per items change, not on every render.
    @State private var cachedTotalRemaining: Decimal = 0
    @State private var cachedSortedCurrencies: [String] = ["USD"]
    @State private var cachedHasMultipleCurrencies: Bool = false
    @State private var cachedHeroIsEmpty: Bool = true
    @State private var cachedHeroAllDone: Bool = false
    /// Pre-formatted total-value strings keyed by list UUID — avoids per-card O(n) loops on every scroll frame.
    @State private var listTotals: [UUID: String] = [:]

    // Debounce task — coalesces rapid item-count changes into a single Spotlight reindex.
    @State private var spotlightDebouncer: Task<Void, Never>?

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack(alignment: .bottom) {
                Theme.backgroundGradient.ignoresSafeArea()

                // Main content or search results
                if isSearchActive {
                    searchResultsContent
                        .transition(.opacity)
                } else {
                    mainContent
                }

                // FABs — hidden during search and on empty state
                if !isSearchActive && !lists.isEmpty {
                    HStack(spacing: Theme.Spacing.md) {
                        newListFab
                        fab
                    }
                    .padding(.bottom, 36)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if isSearchActive {
                    searchBarView
                }
            }
            .animation(Theme.spring, value: isSearchActive)
            .task(id: shouldFocusSearch) {
                guard shouldFocusSearch else { return }
                // Give the view-transition time to place the TextField before focusing.
                try? await Task.sleep(for: .milliseconds(150))
                isSearchFocused = true
            }
            .overlay(alignment: .top) {
                SyncToast(isSyncing: syncService.isSyncing, lastSyncDate: syncService.lastSyncDate)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar(isSearchActive ? .hidden : .visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("GimmeLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 28)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button { isShowingNotifications = true } label: {
                        Image(systemName: "bell")
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .overlay(alignment: .topTrailing) {
                                if notificationsViewModel.unreadCount > 0 {
                                    Circle()
                                        .fill(Theme.Colors.accent)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 4, y: -4)
                                }
                            }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if purchase.isPro { isShowingStats = true }
                        else { isShowingPaywall = true }
                    } label: {
                        Image(systemName: "chart.pie")
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isShowingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowingNewList, onDismiss: {
                if let id = pendingNavigationListID {
                    pendingNavigationListID = nil
                    navPath.append(id)
                }
            }) {
                NewListView { newList in
                    pendingNavigationListID = newList.persistentModelID
                }
                .pageSheet()
            }
            .sheet(isPresented: $isShowingFirstItem, onDismiss: {
                if let id = pendingNavigationListID {
                    pendingNavigationListID = nil
                    navPath.append(id)
                }
            }) {
                FirstItemView { newList in
                    pendingNavigationListID = newList.persistentModelID
                }
                .pageSheet()
            }
            .sheet(isPresented: $isShowingListPicker, onDismiss: {
                addFormTargetList = nil
                if let id = pendingNavigationListID {
                    pendingNavigationListID = nil
                    navPath.append(id)
                }
            }) {
                AddItemView(wishList: addFormTargetList) { savedList in
                    pendingNavigationListID = savedList.persistentModelID
                }
                .pageSheet()
            }
            .sheet(isPresented: $isShowingPaywall) { PaywallView().pageSheet() }
            .sheet(isPresented: $isShowingAuthForShare) { AuthView().pageSheet() }
            .sheet(isPresented: $isShowingStats) {
                StatsView()
                    .presentationDetents([.height(560), .large])
                    .presentationDragIndicator(.visible)
                    .pageSheet()
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
                    .presentationDetents([.large])
                    .presentationCornerRadius(Theme.Radius.sheet)
                    .pageSheet()
            }
            .sheet(isPresented: $isShowingNotifications, onDismiss: {
                if let itemID = pendingNotificationItemID {
                    pendingNotificationItemID = nil
                    if let item = allItems.first(where: { $0.id == itemID }) {
                        navPath.append(item)
                    }
                }
            }) {
                NotificationsView(viewModel: notificationsViewModel) { itemID in
                    pendingNotificationItemID = itemID
                }
            }
            .sheet(item: $listToChangeColor) { ColorPickerSheet(list: $0) }
            .sheet(item: $listToEdit) { NewListView(listToEdit: $0) }
            .sheet(item: $listShareURL) { url in
                ShareSheetView(items: [url])
            }
            .alert("Rename List", isPresented: Binding(
                get: { viewModel.listToRename != nil },
                set: { if !$0 { viewModel.listToRename = nil } }
            )) {
                TextField("List name", text: $viewModel.renameText)
                Button("Save") { viewModel.commitRename() }
                Button("Cancel", role: .cancel) { viewModel.listToRename = nil }
            }
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let list = lists.first(where: { $0.persistentModelID == id }) {
                    WishListDetailView(wishList: list)
                } else {
                    ProgressView()
                        .onAppear { navPath = NavigationPath() }
                }
            }
            .navigationDestination(for: WishItem.self) { item in
                if let list = item.list {
                    WishItemDetailView(item: item, wishList: list)
                } else {
                    ProgressView()
                        .onAppear { navPath = NavigationPath() }
                }
            }
            .task {
                ColorMigrationService.migrateIfNeeded(context: modelContext)
                try? await Task.sleep(for: .milliseconds(500))
                WidgetDataService.scheduleUpdate(context: modelContext)
                SpotlightIndexService.reindex(container: modelContainer)
            }
            .task(id: auth.userID) {
                guard let uid = auth.userID else { return }
                await notificationsViewModel.load(ownerID: uid)
            }
            .onChange(of: allItems.count) { _, _ in
                WidgetDataService.scheduleUpdate(context: modelContext)
                spotlightDebouncer?.cancel()
                spotlightDebouncer = Task {
                    try? await Task.sleep(for: .milliseconds(750))
                    guard !Task.isCancelled else { return }
                    SpotlightIndexService.reindex(container: modelContainer)
                }
            }
            .onChange(of: router.pendingAction) { _, action in
                guard let action else { return }
                handleDeepLink(action)
            }
            .task {
                // On cold launch from Siri/Spotlight, pendingAction is set before
                // this view appears. Wait briefly for @Query to populate, then consume it.
                guard router.pendingAction != nil else { return }
                try? await Task.sleep(for: .milliseconds(300))
                if let action = router.pendingAction {
                    handleDeepLink(action)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                checkForSharedURL()
                if let uid = auth.userID {
                    Task {
                        await syncService.syncAll(container: modelContainer, userID: uid)
                        WidgetDataService.scheduleUpdate(context: modelContext)
                    }
                } else {
                    WidgetDataService.scheduleUpdate(context: modelContext)
                }
            }
            .onChange(of: auth.isSignedIn) { _, signedIn in
                guard signedIn, let uid = auth.userID else {
                    // Sign out: reset UI state immediately on main thread.
                    wasSignedIn = false
                    WidgetDataService.updateSnapshot(context: modelContext)

                    // Delete all local data on a background context so the main thread
                    // doesn't freeze on large datasets (500+ items = multi-second stall).
                    let container = modelContext.container
                    Task.detached {
                        let ctx = ModelContext(container)
                        ctx.autosaveEnabled = false
                        let ls = (try? ctx.fetch(FetchDescriptor<WishList>())) ?? []
                        ls.forEach { ctx.delete($0) }
                        let it = (try? ctx.fetch(FetchDescriptor<WishItem>())) ?? []
                        it.forEach { ctx.delete($0) }
                        try? ctx.save()
                    }
                    return
                }

                // Session restore on launch — wasSignedIn was already true, just sync
                if wasSignedIn {
                    postLoginSync(userID: uid)
                    return
                }

                // Fresh sign-in (wasSignedIn was false)
                wasSignedIn = true
                let isNewAccount = auth.consumeNewAccountFlag()

                // Only guest data (ownerID == nil) is eligible for merge
                let localLists = (try? modelContext.fetch(FetchDescriptor<WishList>()))?.filter { $0.ownerID == nil } ?? []
                let localItems = (try? modelContext.fetch(FetchDescriptor<WishItem>()))?.filter { $0.list?.ownerID == nil } ?? []
                let hasGuestData = !localLists.isEmpty || !localItems.isEmpty

                if isNewAccount || !hasGuestData {
                    // New account or no unsynced guest data — push local up and pull remote
                    postLoginSync(userID: uid)
                } else {
                    // Existing account sign-in with local guest data — ask the user
                    pendingMergeListCount = localLists.count
                    pendingMergeItemCount = localItems.count
                    isShowingMergePrompt = true
                }
            }
            .alert("Import Local Data?", isPresented: $isShowingMergePrompt) {
                Button("Import into Account") {
                    // Keep local data as-is; syncAll will push it to the server.
                    guard let uid = auth.userID else { return }
                    postLoginSync(userID: uid)
                }
                Button("Discard", role: .destructive) {
                    // Delete local data, then pull from remote.
                    let ls = (try? modelContext.fetch(FetchDescriptor<WishList>())) ?? []
                    ls.forEach { modelContext.delete($0) }
                    let it = (try? modelContext.fetch(FetchDescriptor<WishItem>())) ?? []
                    it.forEach { modelContext.delete($0) }
                    try? modelContext.save()
                    guard let uid = auth.userID else { return }
                    postLoginSync(userID: uid)
                }
            } message: {
                let listWord = pendingMergeListCount == 1 ? "list" : "lists"
                let itemWord = pendingMergeItemCount == 1 ? "item" : "items"
                return Text("You have \(pendingMergeListCount) \(listWord) and \(pendingMergeItemCount) \(itemWord) saved locally. Import them into your account, or discard them and load your account data.")
            }
            .sheet(isPresented: $isShowingShareListPicker) {
                ShareListPickerView(sharedURL: pendingSharedURL ?? "") {
                    pendingSharedURL = nil
                }
                .pageSheet()
            }
            // Recompute hero totals and currency lists only when items actually change.
            .onChange(of: itemsSignature, initial: true) { _, _ in recomputeAggregates() }
            .onChange(of: displayCurrency) { _, _ in recomputeAggregates() }
        }
    }

    // MARK: - FAB

    private var hasActiveLists: Bool {
        lists.contains { !$0.isArchived }
    }

    private var fab: some View {
        Button {
            Haptics.light()
            if hasActiveLists {
                isShowingListPicker = true
            } else {
                isShowingFirstItem = true
            }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.25))
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Add Wish")
                    .font(.rounded(.body, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.leading, Theme.Spacing.md)
            .padding(.trailing, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .primaryGlassBackground(color: Theme.Colors.accent)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var newListFab: some View {
        Button {
            Haptics.light()
            viewModel.showNewList()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.07))
                        .frame(width: 32, height: 32)
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .white : Theme.Colors.textPrimary)
                }
                Text("New List")
                    .font(.rounded(.body, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? .white : Theme.Colors.textPrimary)
            }
            .padding(.leading, Theme.Spacing.md)
            .padding(.trailing, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
            .glassCapsuleBackground()
            .shadow(color: .black.opacity(0.14), radius: 16, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
        .contentShape(Capsule())
    }

    // MARK: - Main content
    // List is the root scroll container — required for .swipeActions to work.

    @ViewBuilder
    private var mainContent: some View {
        if lists.isEmpty {
            emptyState
        } else {
            let displayedLists = viewModel.showArchivedLists
                ? viewModel.archivedLists(lists)
                : viewModel.filteredLists(lists)
            let archivedCount = viewModel.archivedLists(lists).count

            ScrollViewReader { proxy in
            List {
                // ── Pull-down search trigger ──────────────────────────────────
                // _SearchBarHider walks up to the UIScrollView after its first
                // layout pass and bumps contentOffset.y by exactly one row height,
                // pushing this row above the fold without any timing race.
                Button {
                    shouldFocusSearch = true
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(.callout, weight: .medium))
                        Text("Search lists & items…")
                            .foregroundStyle(.tertiary)
                            .font(.system(.body))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Theme.Colors.surfaceElevated, in: Capsule())
                    .background(_SearchBarHider())   // UIKit one-shot offset setter
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.gridPadding)
                .padding(.vertical, Theme.Spacing.sm)
                .id("search-bar")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .onAppear {
                    // Fires when this row enters the viewport.
                    // The UIKit hider keeps it above fold at launch so this
                    // only triggers on real user pull-downs.
                    Haptics.light()
                }

                // ── Hero ──────────────────────────────────────────
                heroSection
                    .id("hero")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 24, leading: 0, bottom: 0, trailing: 0))

                // ── Section header row ─────────────────────────────
                HStack {
                    Text(viewModel.showArchivedLists ? "Archived" : "My Lists")
                        .font(.rounded(.title3, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    HStack(spacing: 12) {
                        Text("\(displayedLists.count) \(displayedLists.count == 1 ? "list" : "lists")")
                            .font(.system(.subheadline))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        if archivedCount > 0 || viewModel.showArchivedLists {
                            Button {
                                withAnimation(Theme.spring) { viewModel.showArchivedLists.toggle() }
                            } label: {
                                Text(viewModel.showArchivedLists ? "Current" : "Archived")
                                    .font(.system(.subheadline, weight: .medium))
                                    .foregroundStyle(Theme.Colors.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.gridPadding)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: Theme.Spacing.xl,
                    leading: 0,
                    bottom: Theme.Spacing.md,
                    trailing: 0
                ))

                // ── List rows ─────────────────────────────────────
                ForEach(displayedLists) { list in
                    ZStack {
                        NavigationLink(value: list.persistentModelID) { EmptyView() }
                            .opacity(0)
                        WishListCard(list: list, totalText: listTotals[list.id])
                            .opacity(viewModel.showArchivedLists ? 0.6 : 1.0)
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if viewModel.showArchivedLists {
                            Button(role: .destructive) {
                                Haptics.heavy()
                                let id = list.id
                                withAnimation(Theme.spring) { viewModel.deleteList(list, in: modelContext) }
                                if auth.isSignedIn {
                                    Task { await syncService.deleteList(id: id) }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } else {
                            Button {
                                Haptics.light()
                                withAnimation(Theme.spring) { viewModel.archiveList(list) }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.gray)
                            Button { listToEdit = list } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if viewModel.showArchivedLists {
                            Button {
                                Haptics.light()
                                withAnimation(Theme.spring) { viewModel.unarchiveList(list) }
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.left")
                            }
                            .tint(.blue)
                        } else {
                            Button {
                                Haptics.light()
                                withAnimation(Theme.spring) { viewModel.pinList(list) }
                            } label: {
                                Label(list.isPinned ? "Unpin" : "Pin",
                                      systemImage: list.isPinned ? "pin.slash.fill" : "pin.fill")
                            }
                            .tint(.orange)
                        }
                    }
                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    .contextMenu {
                        if !viewModel.showArchivedLists {
                            Button {
                                let sharedCount = lists.filter { $0.isShared }.count
                                let canShareFree = list.isShared || sharedCount < 2
                                guard purchase.isPro || canShareFree else { isShowingPaywall = true; return }
                                guard auth.isSignedIn else { isShowingAuthForShare = true; return }
                                let url = list.ensureShareToken()
                                if let uid = auth.userID {
                                    Task { await syncService.syncAll(container: modelContainer, userID: uid, force: true) }
                                }
                                listShareURL = url
                            } label: {
                                Label("Share List", systemImage: "square.and.arrow.up")
                            }
                            if list.isShared, let url = list.shareURL {
                                Button {
                                    UIPasteboard.general.url = url
                                    Haptics.success()
                                } label: {
                                    Label("Copy Link", systemImage: "doc.on.doc")
                                }
                            }
                            Divider()
                            Button { listToEdit = list } label: {
                                Label("Edit List", systemImage: "pencil")
                            }
                            Button { listToChangeColor = list } label: {
                                Label("Change Color", systemImage: "paintpalette")
                            }
                            Button {
                                withAnimation(Theme.spring) { viewModel.pinList(list) }
                            } label: {
                                Label(list.isPinned ? "Unpin" : "Pin",
                                      systemImage: list.isPinned ? "pin.slash" : "pin")
                            }
                            Divider()
                            Button {
                                withAnimation(Theme.spring) { viewModel.archiveList(list) }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
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
            .onChange(of: isSearchActive) { _, active in
                if !active {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        proxy.scrollTo("hero", anchor: .top)
                    }
                }
            }
            } // end ScrollViewReader
        }
    }

    // MARK: - Search bar

    private var searchBarView: some View {
        HStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(.callout, weight: .medium))
                TextField("Search lists & items…", text: $viewModel.searchText)
                    .focused($isSearchFocused)
                    .foregroundStyle(.primary)
                    .font(.system(.body))
                    .autocorrectionDisabled()
                    .submitLabel(.search)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .glassCapsuleBackground()

            if isSearchActive {
                Button {
                    isSearchFocused = false
                    shouldFocusSearch = false
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .glassCircleBackground()
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: isSearchActive)
        .padding(.horizontal, Theme.Spacing.gridPadding)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    // MARK: - Search results content

    @ViewBuilder
    private var searchResultsContent: some View {
        if viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            searchIdleState
        } else {
            let filteredL = viewModel.filteredLists(lists)
            let filteredI = viewModel.filteredItems(allItems)
            if filteredL.isEmpty && filteredI.isEmpty {
                searchNoResults
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !filteredL.isEmpty {
                            searchSectionLabel("Lists")
                            VStack(spacing: Theme.Spacing.cardGap) {
                                ForEach(filteredL) { list in
                                    NavigationLink(value: list.persistentModelID) {
                                        WishListCard(list: list, totalText: listTotals[list.id])
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .simultaneousGesture(TapGesture().onEnded {
                                        isSearchFocused = false
                                        shouldFocusSearch = false
                                        viewModel.searchText = ""
                                    })
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.gridPadding)
                        }

                        if !filteredI.isEmpty {
                            searchSectionLabel("Items")
                            VStack(spacing: Theme.Spacing.cardGap) {
                                ForEach(filteredI) { item in
                                    NavigationLink(value: item) {
                                        searchItemRow(item)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .simultaneousGesture(TapGesture().onEnded {
                                        isSearchFocused = false
                                        shouldFocusSearch = false
                                        viewModel.searchText = ""
                                    })
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.gridPadding)
                        }
                    }
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, 32)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    private func searchSectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(.caption, weight: .semibold))
            .foregroundStyle(Theme.Colors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.gridPadding)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.sm)
    }

    private func searchItemRow(_ item: WishItem) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: item.list?.colorHex ?? "#888888").opacity(0.25))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(item.list?.emoji ?? "•")
                        .font(.system(size: 16))
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(item.list?.name ?? "")
                    .font(.system(.caption))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer()
            if let price = item.price, let currency = item.currency {
                Text(price.formatted(currency: currency))
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            if item.isPurchased {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.accent.opacity(0.7))
            }
        }
        .padding(Theme.Spacing.cardInner)
        .background(Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    // Search overlay — nothing typed yet
    private var searchIdleState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer(minLength: 80)

            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.Colors.textTertiary.opacity(0.6))

            VStack(spacing: 6) {
                Text("Find your wishes")
                    .font(.rounded(.title3, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Search across all lists and items")
                    .font(.system(.subheadline))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // Search overlay — query typed but nothing matches
    private var searchNoResults: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer(minLength: 60)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.textTertiary)

            VStack(spacing: 6) {
                Text("No results")
                    .font(.rounded(.title3, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Nothing matched \"\(viewModel.searchText)\"")
                    .font(.system(.subheadline))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Button {
                viewModel.searchText = ""
                isSearchFocused = true
            } label: {
                Text("Clear search")
                    .font(.rounded(.callout, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.surfaceElevated, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Remaining Value")
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)

            heroValueDisplay
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 0)
        .padding(.bottom, Theme.Spacing.xl)
        .padding(.horizontal, Theme.Spacing.gridPadding)
    }

    @ViewBuilder
    private var heroValueDisplay: some View {
        if cachedHeroIsEmpty {
            Text("Add your first item")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textTertiary)
        } else if cachedHeroAllDone {
            Text("All done 🎉")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.purchased.opacity(0.7))
        } else {
            Text(cachedTotalRemaining.formatted(currency: displayCurrency))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.70))
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.25), value: cachedTotalRemaining)
                .overlay {
                    Menu {
                        ForEach(cachedSortedCurrencies, id: \.self) { currency in
                            Button {
                                withAnimation(Theme.spring) { displayCurrency = currency }
                            } label: {
                                if currency == displayCurrency {
                                    Label(currency, systemImage: "checkmark")
                                } else {
                                    Text(currency)
                                }
                            }
                        }
                    } label: {
                        Color.clear
                    }
                }
        }
    }

    // MARK: - Deep link handler

    private func handleDeepLink(_ action: DeepLinkRouter.Action) {
        router.pendingAction = nil
        switch action {
        case .openList(let id):
            if let list = lists.first(where: { $0.id == id }) {
                navPath = NavigationPath()
                Task { try? await Task.sleep(for: .milliseconds(300)); navPath.append(list.persistentModelID) }
            }
        case .openStats:
            isShowingStats = true
        case .addItem(let title, let listID):
            // Find the target list
            let targetList: WishList?
            if let listID {
                targetList = lists.first { $0.id == listID }
            } else {
                // Use last-used list, or the only list, or the first
                let lastID = UserDefaults.standard.string(forKey: "lastUsedListID")
                targetList = lists.first(where: { $0.id.uuidString == lastID })
                    ?? (lists.count == 1 ? lists.first : nil)
            }

            if let targetList {
                // Create the item in SwiftData
                let item = WishItem(title: title, list: targetList)
                targetList.items.append(item)
                modelContext.insert(item)
                try? modelContext.save()
                // Navigate to the list
                navPath.append(targetList.persistentModelID)
                // Sync + update widget
                syncAfterChange()
            } else if !lists.isEmpty {
                // Multiple lists, none specified — show list picker
                isShowingListPicker = true
            }

        case .showAddForm(let listID):
            // Open add-item sheet, optionally pre-selecting a list
            if let listID {
                addFormTargetList = lists.first { $0.id == listID }
            } else {
                addFormTargetList = nil
            }
            isShowingListPicker = true
        }
    }

    private func syncAfterChange() {
        guard let uid = auth.userID else { return }
        Task {
            await syncService.syncAll(container: modelContainer, userID: uid)
            WidgetDataService.scheduleUpdate(context: modelContext)
            SpotlightIndexService.reindex(container: modelContainer)
        }
    }

    /// Runs entitlement check and sync concurrently in a single Task,
    /// then updates widget data once after both complete.
    private func postLoginSync(userID: String) {
        Task {
            async let entitlement: Void = purchase.refreshEntitlement()
            async let sync: Void = syncService.syncAll(container: modelContainer, userID: userID, force: true)
            _ = await (entitlement, sync)
            WidgetDataService.scheduleUpdate(context: modelContext)
        }
    }

    // MARK: - Empty state (no lists at all)

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.10))
                    .frame(width: 100, height: 100)
                Image(systemName: "sparkles")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Theme.Colors.accent)
            }

            Spacer().frame(height: 28)

            // Title
            Text("Add Your First Wish")
                .font(.rounded(.title2, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer().frame(height: 12)

            // Description
            Text("Tell us what you want — we'll create\nyour first list around it.")
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer().frame(height: 28)

            // Add Wish button (same style as FAB)
            Button { isShowingFirstItem = true } label: {
                HStack(spacing: Theme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.25))
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("Add Wish")
                        .font(.rounded(.body, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.leading, Theme.Spacing.md)
                .padding(.trailing, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.md)
                .primaryGlassBackground(color: Theme.Colors.accent)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Currency & FX

    /// Cheap fingerprint over the fields that affect aggregate display.
    /// Changes only when something visually meaningful actually changes.
    private var itemsSignature: Int {
        var h = Hasher()
        h.combine(allItems.count)
        for it in allItems {
            h.combine(it.isPurchased)
            h.combine(it.price?.description)
            h.combine(it.currency)
            h.combine(it.list?.isArchived ?? false)
        }
        return h.finalize()
    }

    private func recomputeAggregates() {
        let sp = Perf.begin("home-total-remaining")
        defer { Perf.end("home-total-remaining", sp) }

        let active = allItems.filter { $0.list?.isArchived != true }
        let withPrice = active.filter { !$0.isPurchased && $0.price != nil }

        cachedHeroIsEmpty = active.isEmpty
        cachedHeroAllDone = !active.isEmpty && withPrice.isEmpty && active.allSatisfy { $0.isPurchased }

        cachedTotalRemaining = active
            .filter { !$0.isPurchased }
            .compactMap { item -> Decimal? in
                guard let price = item.price else { return nil }
                return convertCurrency(price, from: item.currency ?? "USD", to: displayCurrency)
            }
            .reduce(0, +)

        var currencies = Set(allItems.compactMap { $0.currency })
        currencies.insert(displayCurrency)
        cachedSortedCurrencies = currencies.sorted()

        cachedHasMultipleCurrencies = Set(
            allItems.filter { !$0.isPurchased && $0.price != nil }.map { $0.currency ?? "USD" }
        ).count > 1

        // Pre-format per-list totals so WishListCard renders O(1) instead of iterating items.
        var totals: [UUID: String] = [:]
        for list in lists {
            let priced = list.items.compactMap { item -> Decimal? in
                guard let price = item.price else { return nil }
                return convertCurrency(price, from: item.currency ?? "USD", to: displayCurrency)
            }
            if !priced.isEmpty {
                totals[list.id] = priced.reduce(Decimal(0), +).formatted(currency: displayCurrency)
            }
        }
        listTotals = totals
    }

    private func checkForSharedURL() {
        let defaults = UserDefaults(suiteName: "group.com.yaremchuk.app")
        guard let urlString = defaults?.string(forKey: "pendingSharedURL"),
              !urlString.isEmpty else { return }
        defaults?.removeObject(forKey: "pendingSharedURL")
        pendingSharedURL = urlString
        isShowingShareListPicker = true
    }

}

// MARK: - Color Picker Sheet

private struct ColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let list: WishList
    @State private var selectedHex: String

    init(list: WishList) {
        self.list = list
        _selectedHex = State(initialValue: list.colorHex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                VStack(spacing: Theme.Spacing.xl) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: selectedHex).opacity(0.2))
                            .frame(width: 80, height: 80)
                        Text(list.emoji).font(.largeTitle)
                    }
                    .padding(.top)
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5),
                              spacing: Theme.Spacing.lg) {
                        ForEach(Theme.Colors.presets, id: \.hex) { preset in
                            let isSelected = selectedHex == preset.hex
                            Button {
                                selectedHex = preset.hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: preset.hex))
                                    .frame(height: 50)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: 3)
                                        .opacity(isSelected ? 1 : 0))
                                    .shadow(color: Color(hex: preset.hex).opacity(0.5),
                                            radius: isSelected ? 8 : 0)
                                    .scaleEffect(isSelected ? 1.1 : 1.0)
                                    .animation(Theme.quickSpring, value: isSelected)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.Spacing.gridPadding)
                    Spacer()
                }
            }
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { list.colorHex = selectedHex; dismiss() }
                        .font(.rounded(.body, weight: .semibold))
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Share list picker

/// Presented when the app is opened after using the Share Extension.
/// The user picks a list; then AddItemView opens with the URL pre-filled.
private struct ShareListPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishList.createdAt, order: .reverse) private var lists: [WishList]
    @Environment(\.dismiss) private var dismiss

    let sharedURL: String
    let onDismiss: () -> Void

    @State private var selectedList: WishList?
    @State private var isShowingAddItem = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if lists.isEmpty {
                    VStack(spacing: Theme.Spacing.lg) {
                        Text("No lists yet")
                            .font(.rounded(.headline, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("Create a list first, then share items to it.")
                            .font(.system(.subheadline))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(lists) { list in
                        Button {
                            selectedList = list
                            isShowingAddItem = true
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: list.colorHex).opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Text(list.emoji)
                                        .font(.title3)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(list.name)
                                        .font(.rounded(.body, weight: .semibold))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Text("\(list.items.count) items")
                                        .font(.system(.caption))
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Theme.Colors.surface)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Add to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .sheet(item: $selectedList) { list in
                AddItemView(wishList: list, initialURL: sharedURL)
                    .onDisappear {
                        onDismiss()
                        dismiss()
                    }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(Theme.Radius.sheet)
    }
}

#Preview {
    HomeView().modelContainer(PreviewData.container)
}

// MARK: - Add Wish list picker (FAB → pick list → AddItemView)

private struct AddWishListPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WishList.createdAt, order: .reverse) private var lists: [WishList]
    @Environment(\.dismiss) private var dismiss

    var onNavigate: ((WishList) -> Void)? = nil

    @State private var selectedList: WishList?
    @State private var isShowingAddItem = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                List(lists.filter { !$0.isArchived }) { list in
                    Button {
                        selectedList = list
                        isShowingAddItem = true
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: list.colorHex).opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Text(list.emoji).font(.title3)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(list.name)
                                    .font(.rounded(.body, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text("\(list.items.count) items")
                                    .font(.system(.caption))
                                    .foregroundStyle(Theme.Colors.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Theme.Colors.surface)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .sheet(item: $selectedList) { list in
                AddItemView(wishList: list)
                    .onDisappear { dismiss() }
            }
        }
    }
}

// MARK: - First item view (no-lists onboarding)

struct FirstItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultCurrency") private var defaultCurrency = "USD"

    var onCreated: ((WishList) -> Void)? = nil

    @State private var title = ""
    @State private var notes = ""
    @State private var urlString = ""
    @State private var priceText = ""
    @State private var currency = "USD"
    @State private var priority: Priority = .medium
    @State private var imageURL = ""
    @State private var localImageData: Data? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isShowingImageSourcePicker = false
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingCamera = false
    @State private var isShowingEmojiPicker = false
    @State private var isShowingPriceInput = false
    @State private var isFetchingMetadata = false
    @State private var fetchError: String? = nil
    @State private var metadataDebouncer: Task<Void, Never>?
    @FocusState private var isTitleFocused: Bool

    @State private var listName = "My Wishlist"
    @State private var selectedColorHex = Theme.Colors.presets[0].hex
    @State private var selectedEmoji = "🎁"
    @State private var isShowingListEmojiPicker = false
    @FocusState private var isListNameFocused: Bool

    private let metadataService: any MetadataService = LiveMetadataService()
    private var accentColor: Color { Color(hex: selectedColorHex) }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            mainStack
        }
    }

    private var mainStack: some View {
        ZStack(alignment: .bottom) {
            Theme.backgroundGradient.ignoresSafeArea()
            RadialGradient(colors: [accentColor.opacity(0.2), .clear],
                           center: .top, startRadius: 0, endRadius: 360)
                .ignoresSafeArea().allowsHitTesting(false)
                .animation(Theme.spring, value: selectedColorHex)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        imageThumbnail.padding(.top, Theme.Spacing.xl)
                        urlCard
                        detailsCard
                        priceCard
                        priorityCard
                        listSetupCard.id("listSetupCard")
                        inlineBottomButton
                    }
                    .padding(.horizontal, Theme.Spacing.gridPadding)
                    .padding(.bottom, 40)
                }
                .onChange(of: isListNameFocused) { _, focused in
                    if focused {
                        Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            withAnimation(Theme.spring) {
                                proxy.scrollTo("listSetupCard", anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Your First Wish")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.foregroundStyle(Theme.Colors.textSecondary)
            }
        }
            .onAppear { currency = defaultCurrency }
            .sheet(isPresented: $isShowingImageSourcePicker) {
                ImageSourcePickerSheet(
                    hasImage: localImageData != nil || !imageURL.isEmpty,
                    onPhotoLibrary: { isShowingPhotoLibrary = true },
                    onCamera:       { isShowingCamera = true },
                    onEmoji:        { isShowingEmojiPicker = true },
                    onRemove: {
                        withAnimation(Theme.spring) { localImageData = nil; imageURL = "" }
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Theme.Radius.sheet)
                .pageSheet()
            }
            .photosPicker(isPresented: $isShowingPhotoLibrary, selection: $selectedPhotoItem, matching: .images)
            .sheet(isPresented: $isShowingCamera) {
                CameraPickerView { data in
                    withAnimation(Theme.spring) { localImageData = data; imageURL = "" }
                }
                .pageSheet()
            }
            .sheet(isPresented: $isShowingEmojiPicker) {
                EmojiPickerSheet(accentColor: accentColor) { data in
                    withAnimation(Theme.spring) { localImageData = data; imageURL = "" }
                }
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
                .pageSheet()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        withAnimation(Theme.spring) { localImageData = data; imageURL = "" }
                    }
                }
            }
            .onChange(of: urlString) { oldValue, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let wasEmpty = oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let looksLikeURL = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
                    || trimmed.hasPrefix("www.")
                let isPaste = (newValue.count - oldValue.count) > 5
                if !isFetchingMetadata && looksLikeURL && (wasEmpty || isPaste) {
                    metadataDebouncer?.cancel()
                    metadataDebouncer = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        fetchMetadata()
                    }
                }
            }
    }

    private var imageThumbnail: some View {
        let hasImage = localImageData != nil || !imageURL.isEmpty
        return Button { isShowingImageSourcePicker = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.image, style: .continuous)
                    .fill(accentColor.opacity(0.12)).frame(width: 96, height: 96)
                    .shadow(color: accentColor.opacity(hasImage ? 0.2 : 0.1), radius: 12, y: 4)
                if let data = localImageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.image, style: .continuous))
                } else if !imageURL.isEmpty {
                    AsyncImageView(urlString: imageURL, cornerRadius: Theme.Radius.image).frame(width: 96, height: 96)
                } else {
                    Image(systemName: "photo").font(.system(size: 28, weight: .light))
                        .foregroundStyle(accentColor.opacity(0.5))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                ZStack {
                    Circle().fill(Theme.Colors.surface).frame(width: 26, height: 26)
                    Image(systemName: hasImage ? "pencil" : "plus")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.Colors.textSecondary)
                }
                .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(.plain).animation(Theme.spring, value: hasImage)
    }

    private var urlCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "link").foregroundStyle(Theme.Colors.textSecondary).frame(width: 20)
                TextField("Paste a product URL…", text: $urlString)
                    .keyboardType(.URL).textInputAutocapitalization(.never)
                    .autocorrectionDisabled().submitLabel(.done)
                    .foregroundStyle(Theme.Colors.textPrimary).onSubmit { fetchMetadata() }
                if isFetchingMetadata {
                    ProgressView().frame(width: 32).tint(accentColor)
                } else if !urlString.trimmingCharacters(in: .whitespaces).isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .frame(width: 32)
                }
            }
            .padding(Theme.Spacing.cardInner)
            if let error = fetchError {
                fiCardDivider
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red.opacity(0.8)).frame(width: 20)
                    Text(error).font(.system(.caption)).foregroundStyle(.red.opacity(0.8))
                    Spacer()
                }
                .padding(Theme.Spacing.cardInner)
            }
        }
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            fiFormRow(icon: "text.cursor", label: "Title") {
                TextField("What do you want?", text: $title)
                    .multilineTextAlignment(.trailing).foregroundStyle(Theme.Colors.textPrimary)
                    .focused($isTitleFocused).submitLabel(.next)
            }
            fiCardDivider
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: "note.text").foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 20).padding(.top, 1)
                Text("Notes").font(.system(.body)).foregroundStyle(Theme.Colors.textSecondary).padding(.top, 1)
                Spacer()
                TextField("Optional", text: $notes, axis: .vertical)
                    .multilineTextAlignment(.trailing).foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1...4).frame(maxWidth: 200)
            }
            .padding(Theme.Spacing.cardInner)
        }
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var priceCard: some View {
        Button { isShowingPriceInput = true } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "dollarsign.circle").foregroundStyle(Theme.Colors.textSecondary).frame(width: 20)
                Text("Price").font(.system(.body)).foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text(priceText.isEmpty ? "0.00" : "\(currency) \(priceText)")
                    .font(.system(.body))
                    .foregroundStyle(priceText.isEmpty ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
            }
            .padding(Theme.Spacing.cardInner)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isShowingPriceInput) {
            PriceInputSheet(priceText: $priceText, currency: $currency, accentColor: accentColor)
                .presentationDetents([PresentationDetent.height(560)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.ultraThinMaterial)
                .pageSheet()
        }
    }

    private var priorityCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "flag").foregroundStyle(Theme.Colors.textSecondary).frame(width: 20)
            Text("Priority").font(.system(.body)).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Priority.allCases, id: \.self) { p in
                    Button { withAnimation(Theme.quickSpring) { priority = p } } label: {
                        Text(p.label).font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(priority == p ? .white : Theme.Colors.textSecondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(priority == p ? fiPriorityColor(p) : Theme.Colors.surfaceElevated, in: Capsule())
                            .scaleEffect(priority == p ? 1.05 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Theme.Spacing.cardInner)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    /// Color presets with selected color moved to front
    private var sortedColorPresets: [(hex: String, name: String)] {
        let presets = Theme.Colors.presets
        guard let idx = presets.firstIndex(where: { $0.hex == selectedColorHex }), idx > 0 else {
            return presets
        }
        var sorted = presets
        let selected = sorted.remove(at: idx)
        sorted.insert(selected, at: 0)
        return sorted
    }

    private var listSetupCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Wishlist").font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary).textCase(.uppercase).tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.cardInner)
            .padding(.top, Theme.Spacing.cardInner)
            .padding(.bottom, Theme.Spacing.sm)

            HStack(spacing: Theme.Spacing.md) {
                Button { isShowingListEmojiPicker = true } label: {
                    ZStack {
                        Circle().fill(accentColor.opacity(0.15)).frame(width: 44, height: 44)
                        Text(selectedEmoji).font(.system(size: 22))
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $isShowingListEmojiPicker) {
                    WishlistEmojiPickerSheet(
                        selectedEmoji: $selectedEmoji,
                        accentColor: accentColor
                    )
                    .presentationDetents([.fraction(0.55)])
                    .presentationDragIndicator(.visible)
                    .pageSheet()
                }
                TextField("List name", text: $listName)
                    .font(.system(.body)).foregroundStyle(Theme.Colors.textPrimary)
                    .focused($isListNameFocused).submitLabel(.done)
            }
            .padding(.horizontal, Theme.Spacing.cardInner)

            fiCardDivider.padding(.top, Theme.Spacing.sm)

            fiFormRow(icon: "paintpalette", label: "Color") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sortedColorPresets, id: \.hex) { preset in
                            Button { withAnimation(Theme.quickSpring) { selectedColorHex = preset.hex } } label: {
                                Circle().fill(Color(hex: preset.hex)).frame(width: 24, height: 24)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: 2.5)
                                        .opacity(selectedColorHex == preset.hex ? 1 : 0))
                                    .scaleEffect(selectedColorHex == preset.hex ? 1.2 : 1.0)
                                    .shadow(color: Color(hex: preset.hex).opacity(0.6),
                                            radius: selectedColorHex == preset.hex ? 5 : 0)
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var inlineBottomButton: some View {
        Button { saveAndDismiss() } label: {
            Text("Add Wish").font(.rounded(.body, weight: .semibold))
                .foregroundStyle(canSave ? .white : Theme.Colors.textTertiary)
                .frame(maxWidth: .infinity).padding(.vertical, Theme.Spacing.lg)
                .primaryGlassBackground(color: accentColor, isEnabled: canSave)
                .animation(Theme.spring, value: selectedColorHex)
        }
        .buttonStyle(.plain).disabled(!canSave).animation(Theme.spring, value: canSave)
        .padding(.top, Theme.Spacing.md)
    }

    private func fiPriorityColor(_ p: Priority) -> Color {
        switch p {
        case .low:    return Color(hex: "#3D9970")
        case .medium: return Color(hex: "#FF851B")
        case .high:   return Color(hex: "#FF4136")
        }
    }

    private var fiCardDivider: some View {
        Rectangle().fill(Theme.Colors.surfaceBorder).frame(height: 0.5).padding(.leading, 52)
    }

    private func fiFormRow<C: View>(icon: String, label: String, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon).foregroundStyle(Theme.Colors.textSecondary).frame(width: 20)
            Text(label).font(.system(.body)).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            content()
        }
        .padding(Theme.Spacing.cardInner)
    }

    private func fetchMetadata() {
        let raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = raw.extractedURL else {
            fetchError = "Please enter a valid URL starting with http:// or https://"
            return
        }
        urlString = url.absoluteString; fetchError = nil; isFetchingMetadata = true
        Task {
            do {
                let metadata = try await metadataService.fetch(url: url)
                title = metadata.title
                if let img = metadata.imageURL?.absoluteString {
                    withAnimation(Theme.spring) { imageURL = img; localImageData = nil }
                }
                if let price = metadata.price { priceText = "\(price)" }
                if let cur = metadata.currency { currency = cur }
            } catch {
                fetchError = error.localizedDescription
            }
            isFetchingMetadata = false
        }
    }

    private func saveAndDismiss() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedList  = listName.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let list = WishList(
            name: trimmedList.isEmpty ? "My Wishlist" : trimmedList,
            emoji: selectedEmoji, colorHex: selectedColorHex
        )
        modelContext.insert(list)

        let priceDecimal = Decimal(string: priceText.replacingOccurrences(of: ",", with: "."))
        let cleanURL = urlString.extractedURL?.absoluteString ?? (urlString.isEmpty ? nil : urlString)
        let item = WishItem(
            title: trimmedTitle, notes: notes.isEmpty ? nil : notes,
            url: cleanURL, imageURL: imageURL.isEmpty ? nil : imageURL,
            imageData: localImageData, price: priceDecimal, currency: currency,
            priority: priority, list: list
        )
        list.items.append(item)
        modelContext.insert(item)
        dismiss()
        onCreated?(list)
    }
}

// MARK: - UIKit one-shot: push the search-bar row above the initial fold
//
// scrollPosition(id:) / proxy.scrollTo() both race the List's first layout.
// This UIViewRepresentable sidesteps the race: it waits for layoutSubviews
// (guaranteed post-layout), walks up to the UIScrollView, reads the actual
// first-row height from UITableView / UICollectionView, and shifts contentOffset
// by exactly that amount — once, atomically.

private struct _SearchBarHider: UIViewRepresentable {
    func makeUIView(context: Context) -> _SearchBarHiderView { _SearchBarHiderView() }
    func updateUIView(_ uiView: _SearchBarHiderView, context: Context) {}
}

private final class _SearchBarHiderView: UIView {
    private var applied = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !applied else { return }

        var v: UIView? = superview
        while let view = v {
            if let sv = view as? UIScrollView {
                let rowH = firstRowHeight(in: sv)
                guard rowH > 0 else { return }   // not laid out yet — retry next pass
                sv.contentOffset.y += rowH
                applied = true
                return
            }
            v = view.superview
        }
    }

    private func firstRowHeight(in sv: UIScrollView) -> CGFloat {
        if let tv = sv as? UITableView,
           tv.numberOfSections > 0, tv.numberOfRows(inSection: 0) > 0 {
            return tv.rectForRow(at: IndexPath(row: 0, section: 0)).height
        }
        if let cv = sv as? UICollectionView,
           cv.numberOfSections > 0, cv.numberOfItems(inSection: 0) > 0,
           let attr = cv.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)) {
            return attr.frame.height
        }
        return 0
    }
}

