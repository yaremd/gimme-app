import SwiftUI
import SwiftData
import PhotosUI
import Supabase

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    var wishList: WishList? = nil
    var itemToEdit: WishItem? = nil
    var initialURL: String = ""
    var onSaved: ((WishList) -> Void)? = nil

    @AppStorage("lastUsedListID") private var lastUsedListID = ""
    @State private var selectedList: WishList?
    @State private var isShowingListPicker = false

    @State private var title = ""
    @State private var notes = ""
    @State private var urlString = ""
    @State private var priceText = ""
    @State private var currency = "USD"
    @State private var isShowingPriceInput = false
    @AppStorage("defaultCurrency") private var defaultCurrency = "USD"
    @State private var priority: Priority = .medium
    @State private var imageURL = ""

    // Local image (camera / library / emoji)
    @State private var localImageData: Data? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isShowingImageSourcePicker = false
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingCamera = false
    @State private var isShowingEmojiPicker = false

    // Metadata fetch
    @State private var isFetchingMetadata = false
    @State private var metadataWasFetched = false
    @State private var fetchError: String? = nil
    @State private var alternativeImages: [URL] = []
    @State private var isShowingImageSelector = false
    @State private var fetchedBrand: String? = nil
    @State private var fetchedColor: String? = nil
    @State private var fetchedSize: String? = nil

    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case title, notes, url, listName }

    @State private var isShowingDiscardAlert = false

    // Inline new-list creation (when no lists exist)
    @State private var newListEmoji = "🎁"
    @State private var newListName = "My wishlist"
    @State private var newListColorHex = Theme.Colors.presets[0].hex
    @State private var isShowingNewListEmojiPicker = false
    @State private var isCreatingNewList = false  // true when no lists exist on appear

    @Query(sort: \WishList.createdAt, order: .reverse) private var allLists: [WishList]
    private var activeLists: [WishList] { allLists.filter { !$0.isArchived } }

    private let metadataService: any MetadataService = LiveMetadataService()
    private let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "UAH"]

    var isEditing: Bool { itemToEdit != nil }
    private var accentColor: Color {
        if let hex = selectedList?.colorHex { return Color(hex: hex) }
        if isCreatingNewList { return Color(hex: newListColorHex) }
        return Theme.Colors.accent
    }

    private var hasUnsavedChanges: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !priceText.isEmpty
            || localImageData != nil
            || !imageURL.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Theme.backgroundGradient.ignoresSafeArea()

                LinearGradient(
                    colors: [accentColor.opacity(0.12), .clear],
                    startPoint: .top,
                    endPoint: .init(x: 0.5, y: 0.35)
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Image thumbnail
                        imageThumbnail
                            .padding(.top, Theme.Spacing.xl)
                            .padding(.bottom, Theme.Spacing.md)

                        // URL fetch card
                        urlCard

                        // Details card — title + notes
                        detailsCard

                        // Price card
                        priceCard

                        // List selector card (hidden when editing)
                        if !isEditing {
                            listCard
                        }

                        // Priority card
                        priorityCard

                        // Save button — inline, scrollable
                        inlineBottomButton
                    }
                    .padding(.horizontal, Theme.Spacing.gridPadding)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "New Wish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if !isEditing && hasUnsavedChanges {
                            isShowingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .interactiveDismissDisabled(!isEditing && hasUnsavedChanges)
            .confirmationDialog("You have unsaved changes", isPresented: $isShowingDiscardAlert, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
            .onAppear {
                prefillIfEditing()
                if itemToEdit == nil {
                    currency = defaultCurrency
                    if !initialURL.isEmpty { urlString = initialURL }
                    // Pre-select list: 1) passed list  2) last used  3) first available  4) inline create
                    if let wl = wishList {
                        selectedList = wl
                    } else if !activeLists.isEmpty {
                        selectedList = activeLists.first
                    } else {
                        // No lists exist — enable inline creation
                        isCreatingNewList = true
                    }
                } else {
                    selectedList = itemToEdit?.list
                }
            }
            .onChange(of: selectedList) { _, newList in
                // If user picks a list from the picker, exit inline creation mode
                if newList != nil { isCreatingNewList = false }
            }
            .sheet(isPresented: $isShowingImageSelector) {
                ImageSelectorSheet(
                    images: alternativeImages,
                    currentImageURL: imageURL,
                    accentColor: accentColor,
                    onSelect: { selected in
                        withAnimation(Theme.spring) {
                            imageURL = selected.absoluteString
                            localImageData = nil
                        }
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Theme.Radius.sheet)
                .pageSheet()
            }
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
            .photosPicker(isPresented: $isShowingPhotoLibrary,
                          selection: $selectedPhotoItem,
                          matching: .images)
            .sheet(isPresented: $isShowingCamera) {
                CameraPickerView { data in
                    withAnimation(Theme.spring) {
                        localImageData = data
                        imageURL = ""
                    }
                }
                .pageSheet()
            }
            .sheet(isPresented: $isShowingEmojiPicker) {
                EmojiPickerSheet(accentColor: accentColor) { data in
                    withAnimation(Theme.spring) {
                        localImageData = data
                        imageURL = ""
                    }
                }
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
                .pageSheet()
            }
            .onChange(of: urlString) { oldValue, newValue in
                // Auto-fetch when a URL is pasted (large text change, not typed char-by-char)
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let wasEmpty = oldValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let looksLikeURL = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
                    || trimmed.hasPrefix("www.")
                let isPaste = (newValue.count - oldValue.count) > 5

                if !isFetchingMetadata && looksLikeURL && (wasEmpty || isPaste) {
                    fetchMetadata()
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        let compressed = ImageCompressor.compress(data) ?? data
                        withAnimation(Theme.spring) {
                            localImageData = compressed
                            imageURL = ""
                        }
                    }
                }
            }
        }
    }

    // MARK: - Image thumbnail

    private var imageThumbnail: some View {
        let hasImage = localImageData != nil || !imageURL.isEmpty
        let size: CGFloat = hasImage ? 180 : 120
        return Button { isShowingImageSourcePicker = true } label: {
            ZStack {
                if let data = localImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                } else if !imageURL.isEmpty {
                    AsyncImageView(urlString: imageURL, cornerRadius: Theme.Radius.card)
                        .frame(width: size, height: size)
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                } else {
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "camera")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(Theme.Colors.textTertiary)
                        Text("Add photo")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .frame(width: size, height: size)
                    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if hasImage {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.surface)
                            .frame(width: 30, height: 30)
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .offset(x: 4, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(Theme.spring, value: hasImage)
    }

    private func priorityColor(_ p: Priority) -> Color {
        switch p {
        case .low:    return Color(hex: "#3D9970")
        case .medium: return Color(hex: "#FF851B")
        case .high:   return Color(hex: "#FF4136")
        }
    }

    // MARK: - URL card

    private var urlCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "link")
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 20)

                TextField("Paste a product URL…", text: $urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .focused($focusedField, equals: .url)
                    .onSubmit { fetchMetadata(); focusedField = nil }

                if isFetchingMetadata {
                    ProgressView()
                        .frame(width: 32)
                        .tint(accentColor)
                } else if metadataWasFetched && !urlString.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        urlString = ""
                        imageURL = ""
                        fetchError = nil
                        metadataWasFetched = false
                        focusedField = .url
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .frame(width: 32)
                    }
                }
            }
            .padding(Theme.Spacing.cardInner)

            if let error = fetchError {
                formDivider
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red.opacity(0.8))
                        .frame(width: 20)
                    Text(error)
                        .font(.system(.caption))
                        .foregroundStyle(.red.opacity(0.8))
                    Spacer()
                }
                .padding(Theme.Spacing.cardInner)
            }

            // Variant badges (color / size / brand)
            if fetchedBrand != nil || fetchedColor != nil || fetchedSize != nil {
                formDivider
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if let brand = fetchedBrand {
                            variantBadge(icon: "tag", text: brand)
                        }
                        if let color = fetchedColor {
                            variantBadge(icon: "paintpalette", text: color)
                        }
                        if let size = fetchedSize {
                            variantBadge(icon: "ruler", text: size)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.cardInner)
                    .padding(.vertical, 8)
                }
            }

            // Alternative images button
            if !alternativeImages.isEmpty {
                formDivider
                Button { isShowingImageSelector = true } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundStyle(accentColor)
                            .frame(width: 20)
                        Text("Wrong image? Pick from \(alternativeImages.count + 1) found")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(accentColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .padding(Theme.Spacing.cardInner)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private func variantBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Theme.Colors.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.Colors.surfaceElevated, in: Capsule())
    }

    // MARK: - Details card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            formRow(icon: "text.cursor", label: "Title") {
                TextField("Required", text: $title)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .keyboardType(.default)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .title)
                    .onSubmit { focusedField = nil }
            }

            formDivider

            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "note.text")
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 20)
                        .padding(.top, 1)
                    Text("Notes")
                        .font(.system(.body))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.top, 1)
                }
                .contentShape(Rectangle())
                .onTapGesture { focusedField = .notes }
                TextField("Optional", text: $notes, axis: .vertical)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .keyboardType(.default)
                    .submitLabel(.done)
                    .lineLimit(1...4)
                    .focused($focusedField, equals: .notes)
                    .onChange(of: notes) { oldValue, newValue in
                        if newValue.contains("\n") {
                            notes = newValue.replacingOccurrences(of: "\n", with: "")
                            focusedField = nil
                        }
                    }
            }
            .padding(Theme.Spacing.cardInner)
        }
        .background(Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    // MARK: - Price card

    private var priceCard: some View {
        Button { isShowingPriceInput = true } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "dollarsign.circle")
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 20)
                Text("Price")
                    .font(.system(.body))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text(priceText.isEmpty ? "0.00" : "\(currency) \(priceText)")
                    .font(.system(.body))
                    .foregroundStyle(priceText.isEmpty ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(Theme.Spacing.cardInner)
            .background(Theme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
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

    // MARK: - Priority card

    private var priorityCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "flag")
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 20)
                Text("Priority")
                    .font(.system(.body))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Button {
                            withAnimation(Theme.quickSpring) { priority = p }
                        } label: {
                            Text(p.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(priority == p ? .white : Theme.Colors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    priority == p ? priorityColor(p) : Theme.Colors.surfaceElevated,
                                    in: Capsule()
                                )
                                .scaleEffect(priority == p ? 1.05 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Theme.Spacing.cardInner)
        }
        .background(Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    // MARK: - Participants card (Phase 3)

    // MARK: - Inline bottom button (scrollable, not fixed)

    private var inlineBottomButton: some View {
        Button { saveAndDismiss() } label: {
            Text(isEditing ? "Save Changes" : "Add Wish")
                .font(.rounded(.body, weight: .semibold))
                .foregroundStyle(canSave ? .white : Theme.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .primaryGlassBackground(color: accentColor, isEnabled: canSave)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .animation(Theme.spring, value: canSave)
        .padding(.top, Theme.Spacing.md)
    }

    // MARK: - Helpers

    private var canSave: Bool {
        let hasTitle = !title.trimmingCharacters(in: .whitespaces).isEmpty
        return hasTitle && (isEditing || selectedList != nil || isCreatingNewList)
    }

    private func formRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 20)
            Text(label)
                .font(.system(.body))
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            content()
        }
        .padding(Theme.Spacing.cardInner)
    }

    private var formDivider: some View {
        Rectangle()
            .fill(Theme.Colors.surfaceBorder)
            .frame(height: 0.5)
            .padding(.leading, 52)
    }

    private func fetchMetadata() {
        let raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = raw.extractedURL else {
            fetchError = "Please enter a valid URL starting with http:// or https://"
            return
        }
        urlString = url.absoluteString
        fetchError = nil
        isFetchingMetadata = true

        Task {
            do {
                let metadata = try await metadataService.fetch(url: url)
                // Only fill empty fields — don't overwrite user edits
                if title.trimmingCharacters(in: .whitespaces).isEmpty {
                    title = metadata.title
                }
                if let imgURL = metadata.imageURL?.absoluteString {
                    withAnimation(Theme.spring) {
                        imageURL = imgURL
                        localImageData = nil
                    }
                }
                alternativeImages = metadata.alternativeImageURLs
                if priceText.isEmpty, let price = metadata.price {
                    priceText = "\(price)"
                }
                if let cur = metadata.currency { currency = cur }

                // Store variant info for display
                fetchedBrand = metadata.brand
                fetchedColor = metadata.color
                fetchedSize = metadata.size

                // Append variant info to notes if found
                var variantParts: [String] = []
                if let c = metadata.color { variantParts.append("Color: \(c)") }
                if let s = metadata.size { variantParts.append("Size: \(s)") }
                if !variantParts.isEmpty && notes.isEmpty {
                    notes = variantParts.joined(separator: " · ")
                }
            } catch {
                fetchError = error.localizedDescription
            }
            isFetchingMetadata = false
            metadataWasFetched = true
        }
    }

    private func saveAndDismiss() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        // Auto-create wishlist if using inline creation
        let targetList: WishList
        if isEditing {
            guard let list = itemToEdit?.list ?? selectedList else { return }
            targetList = list
        } else if let list = selectedList {
            targetList = list
        } else if isCreatingNewList {
            let listName = newListName.trimmingCharacters(in: .whitespaces)
            let newList = WishList(
                name: listName.isEmpty ? "My wishlist" : listName,
                emoji: newListEmoji,
                colorHex: newListColorHex
            )
            modelContext.insert(newList)
            targetList = newList
        } else {
            return
        }

        let priceDecimal = Decimal(string: priceText.replacingOccurrences(of: ",", with: "."))
        let cleanURL = urlString.extractedURL?.absoluteString ?? (urlString.isEmpty ? nil : urlString)

        let savedItem: WishItem

        if let existing = itemToEdit {
            existing.title = trimmedTitle
            existing.notes = notes.isEmpty ? nil : notes
            existing.url = cleanURL
            existing.imageURL = imageURL.isEmpty ? nil : imageURL
            existing.imageData = localImageData
            existing.price = priceDecimal
            existing.currency = currency
            existing.priority = priority
            existing.endDate = nil
            existing.reminders = []
            NotificationService.shared.cancelAll(id: existing.id)
            savedItem = existing
        } else {
            let item = WishItem(
                title: trimmedTitle,
                notes: notes.isEmpty ? nil : notes,
                url: cleanURL,
                imageURL: imageURL.isEmpty ? nil : imageURL,
                imageData: localImageData,
                price: priceDecimal,
                currency: currency,
                priority: priority,
                list: targetList
            )
            targetList.items.append(item)
            modelContext.insert(item)
            lastUsedListID = targetList.id.uuidString
            savedItem = item
        }

        // Upload camera/library photo immediately so it appears on shared links
        if let data = localImageData, savedItem.imageURL == nil, let uid = auth.userID {
            let itemID = savedItem.id
            Task {
                // Use lowercase UUID so it matches Supabase auth.uid() in RLS policy
                let path = "\(uid.lowercased())/\(itemID.uuidString.lowercased()).jpg"
                do {
                    try await supabase.storage
                        .from("item-images")
                        .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
                    // Only set imageURL if upload actually succeeded
                    if let url = try? supabase.storage.from("item-images").getPublicURL(path: path) {
                        savedItem.imageURL = url.absoluteString
                        savedItem.updatedAt = .now
                    }
                } catch {
                    // Upload failed — imageURL stays nil, photo renders from local imageData only
                }
            }
        }

        Haptics.success()
        onSaved?(targetList)
        dismiss()
    }

    private func prefillIfEditing() {
        guard let item = itemToEdit else { return }
        title = item.title
        notes = item.notes ?? ""
        urlString = item.url ?? ""
        priceText = item.price.map { "\($0)" } ?? ""
        currency = item.currency ?? "USD"
        priority = item.priority
        imageURL = item.imageURL ?? ""
        localImageData = item.imageData
    }

    // MARK: - Wishlist selector card

    private var listCard: some View {
        Group {
            if isCreatingNewList {
                inlineNewListCard
            } else {
                existingListCard
            }
        }
        .sheet(isPresented: $isShowingListPicker) {
            ListPickerSheet(selectedList: $selectedList)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Theme.Radius.sheet)
                .pageSheet()
        }
    }

    // Existing list selected — simple row with picker
    private var existingListCard: some View {
        Button { isShowingListPicker = true } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "heart.text.square")
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 20)
                Text("Wishlist")
                    .font(.system(.body))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                if let list = selectedList {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: list.colorHex).opacity(0.18))
                                .frame(width: 22, height: 22)
                            Text(list.emoji).font(.system(size: 12))
                        }
                        Text(list.name)
                            .font(.system(.body))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Select a wishlist")
                        .font(.system(.body))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(Theme.Spacing.cardInner)
            .background(Theme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // Inline new wishlist creation — shown when no lists exist
    private var inlineNewListCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "heart.text.square")
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 20)
                Text("Wishlist")
                    .font(.system(.body))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text("New")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: newListColorHex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: newListColorHex).opacity(0.15), in: Capsule())
            }
            .padding(Theme.Spacing.cardInner)

            formDivider

            // Emoji + Name row
            HStack(spacing: Theme.Spacing.md) {
                Button { isShowingNewListEmojiPicker = true } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: newListColorHex).opacity(0.18))
                            .frame(width: 40, height: 40)
                        Text(newListEmoji)
                            .font(.system(size: 20))
                    }
                    .overlay(alignment: .bottomTrailing) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.surface)
                                .frame(width: 16, height: 16)
                            Image(systemName: "pencil")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }
                        .offset(x: 2, y: 2)
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $isShowingNewListEmojiPicker) {
                    WishlistEmojiPickerSheet(
                        selectedEmoji: $newListEmoji,
                        accentColor: Color(hex: newListColorHex)
                    )
                    .presentationDetents([.fraction(0.55)])
                    .presentationDragIndicator(.visible)
                    .pageSheet()
                }

                TextField("My wishlist", text: $newListName)
                    .font(.system(.body))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .focused($focusedField, equals: .listName)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            }
            .padding(Theme.Spacing.cardInner)

            formDivider

            // Color picker row
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "paintpalette")
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 20)
                Text("Color")
                    .font(.system(.body))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(sortedColorPresets, id: \.hex) { preset in
                            Button {
                                withAnimation(Theme.quickSpring) { newListColorHex = preset.hex }
                            } label: {
                                Circle()
                                    .fill(Color(hex: preset.hex))
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Circle().strokeBorder(.white, lineWidth: 2.5)
                                            .opacity(newListColorHex == preset.hex ? 1 : 0)
                                    )
                                    .scaleEffect(newListColorHex == preset.hex ? 1.2 : 1.0)
                                    .shadow(
                                        color: Color(hex: preset.hex).opacity(0.6),
                                        radius: newListColorHex == preset.hex ? 5 : 0
                                    )
                                    .frame(width: 44, height: 44)
                                    .contentShape(Circle().size(CGSize(width: 44, height: 44)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(Theme.Spacing.cardInner)
        }
        .background(Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .animation(Theme.spring, value: newListColorHex)
    }

    /// Color presets with selected color moved to front
    private var sortedColorPresets: [(hex: String, name: String)] {
        let presets = Theme.Colors.presets
        guard let idx = presets.firstIndex(where: { $0.hex == newListColorHex }), idx > 0 else {
            return presets
        }
        var sorted = presets
        let selected = sorted.remove(at: idx)
        sorted.insert(selected, at: 0)
        return sorted
    }
}

// MARK: - Camera picker

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let raw = image.jpegData(compressionQuality: 1.0),
               let data = ImageCompressor.compress(raw) {
                parent.onCapture(data)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Emoji picker sheet

struct EmojiPickerSheet: View {
    let accentColor: Color
    let onSelect: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEmoji: String? = nil

    private let emojis = [
        "✨","🎂","🎁","💻","📱","🎮","👟","👜","🏠","🌿",
        "📚","🎵","🎨","🍕","☕","🌸","💎","🚀","🏋","🌊",
        "🎯","🧸","🌙","🦋","🍀","🎪","🦄","🍦","🌈","🎭",
        "🏆","💡","🔮","🎬","🎸","🍜","🌺","⚡","🎲","🏄",
        "🎀","🪴","🕯","🧩","🪄","🐾","🌍","🍷","🎓","🛍",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text("Pick an Emoji")
                .font(.rounded(.callout, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.md)

            ScrollView(showsIndicators: false) {
                LazyVGrid(
                    columns: Array(repeating: .init(.flexible(), spacing: 6), count: 8),
                    spacing: 6
                ) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            withAnimation(Theme.quickSpring) { selectedEmoji = emoji }
                        } label: {
                            Text(emoji)
                                .font(.system(size: 26))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    selectedEmoji == emoji
                                    ? accentColor.opacity(0.25)
                                    : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(
                                            selectedEmoji == emoji ? accentColor : .clear,
                                            lineWidth: 1.5
                                        )
                                )
                                .scaleEffect(selectedEmoji == emoji ? 1.1 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.gridPadding)
            }
            .padding(.bottom, Theme.Spacing.md)

            Button {
                if let emoji = selectedEmoji, let data = emojiToImageData(emoji) {
                    onSelect(data)
                }
                dismiss()
            } label: {
                Text(selectedEmoji == nil ? "Cancel" : "Use Emoji")
                    .font(.rounded(.body, weight: .semibold))
                    .foregroundStyle(selectedEmoji == nil
                                     ? Theme.Colors.textSecondary
                                     : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
                    .background(
                        selectedEmoji == nil ? Theme.Colors.surfaceElevated : accentColor,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .animation(Theme.quickSpring, value: selectedEmoji)
            .padding(.horizontal, Theme.Spacing.gridPadding)
            .padding(.bottom, 36)
        }
        .background(Theme.Colors.surface)
    }

    private func emojiToImageData(_ emoji: String) -> Data? {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 140)
            ]
            let string = emoji as NSString
            let textSize = string.size(withAttributes: attributes)
            let point = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            string.draw(at: point, withAttributes: attributes)
        }
        return image.pngData()
    }
}

// MARK: - Reminders picker sheet

struct RemindersPickerSheet: View {
    @Binding var reminders: Set<ReminderOption>
    var accentColor: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ForEach(ReminderOption.allCases, id: \.self) { option in
                        let isSelected = reminders.contains(option)
                        Button {
                            if isSelected {
                                reminders.remove(option)
                            } else {
                                Task {
                                    let granted = await NotificationService.shared.requestPermission()
                                    if granted { reminders.insert(option) }
                                }
                            }
                        } label: {
                            HStack {
                                Text(option.label)
                                    .font(.system(.body))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(isSelected ? accentColor : Theme.Colors.textTertiary)
                            }
                            .padding(.horizontal, Theme.Spacing.gridPadding)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if option != ReminderOption.allCases.last {
                            Divider()
                                .background(Theme.Colors.surfaceBorder)
                                .padding(.leading, Theme.Spacing.gridPadding)
                        }
                    }
                }
                .background(Theme.Colors.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .padding(.horizontal, Theme.Spacing.gridPadding)
                .padding(.top, Theme.Spacing.lg)
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
            }
        }
    }
}

// MARK: - Wishlist emoji picker sheet (string-based, for WishList.emoji)

struct WishlistEmojiPickerSheet: View {
    @Binding var selectedEmoji: String
    var accentColor: Color
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String

    init(selectedEmoji: Binding<String>, accentColor: Color) {
        self._selectedEmoji = selectedEmoji
        self.accentColor = accentColor
        self._draft = State(initialValue: selectedEmoji.wrappedValue)
    }

    private let emojis = [
        "✨","🎂","🎁","💻","📱","🎮","👟","👜","🏠","🌿",
        "📚","🎵","🎨","🍕","☕","🌸","💎","🚀","🏋","🌊",
        "🎯","🧸","🌙","🦋","🍀","🎪","🦄","🍦","🌈","🎭",
        "🏆","💡","🔮","🎬","🎸","🍜","🌺","⚡","🎲","🏄",
        "🎀","🪴","🕯","🧩","🪄","🐾","🌍","🍷","🎓","🛍",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text("Wishlist Icon")
                .font(.rounded(.callout, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.md)

            ScrollView(showsIndicators: false) {
                LazyVGrid(
                    columns: Array(repeating: .init(.flexible(), spacing: 6), count: 8),
                    spacing: 6
                ) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            withAnimation(Theme.quickSpring) { draft = emoji }
                        } label: {
                            Text(emoji)
                                .font(.system(size: 26))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    draft == emoji
                                    ? accentColor.opacity(0.25)
                                    : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(
                                            draft == emoji ? accentColor : .clear,
                                            lineWidth: 1.5
                                        )
                                )
                                .scaleEffect(draft == emoji ? 1.1 : 1.0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.gridPadding)
            }
            .padding(.bottom, Theme.Spacing.md)

            Button {
                selectedEmoji = draft
                dismiss()
            } label: {
                Text("Done")
                    .font(.rounded(.body, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
                    .background(
                        accentColor,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Spacing.gridPadding)
            .padding(.bottom, 36)
        }
        .background(Theme.Colors.surface)
    }
}

// MARK: - List picker sheet

struct ListPickerSheet: View {
    @Binding var selectedList: WishList?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WishList.createdAt, order: .reverse) private var allLists: [WishList]
    @State private var isShowingNewList = false

    private var lists: [WishList] { allLists.filter { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                if lists.isEmpty {
                    VStack(spacing: Theme.Spacing.lg) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.Colors.textTertiary)
                        Text("No lists yet")
                            .font(.rounded(.headline, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("Create a new list to get started.")
                            .font(.system(.subheadline))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                        Button { isShowingNewList = true } label: {
                            Label("New List", systemImage: "plus")
                                .font(.rounded(.body, weight: .semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Theme.Colors.accent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    .padding()
                } else {
                    List {
                        Button { isShowingNewList = true } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.Colors.accent.opacity(0.18))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.Colors.accent)
                                }
                                Text("New List")
                                    .font(.rounded(.body, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.accent)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Theme.Colors.surface)

                        ForEach(lists) { list in
                            Button {
                                selectedList = list
                                dismiss()
                            } label: {
                                HStack(spacing: Theme.Spacing.md) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: list.colorHex).opacity(0.18))
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
                                    if selectedList?.id == list.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color(hex: list.colorHex))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Theme.Colors.surface)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Select List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .sheet(isPresented: $isShowingNewList) {
                NewListView(onCreated: { list in
                    selectedList = list
                    dismiss()
                })
                .pageSheet()
            }
        }
    }
}

#Preview {
    AddItemView(wishList: PreviewData.sampleList)
        .modelContainer(PreviewData.container)
}

// MARK: - Price input sheet

struct PriceInputSheet: View {
    @Binding var priceText: String
    @Binding var currency: String
    var accentColor: Color = .accentColor
    @Environment(\.dismiss) private var dismiss

    private let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "UAH"]

    @State private var draft: String
    @State private var draftCurrency: String

    init(priceText: Binding<String>, currency: Binding<String>, accentColor: Color = .accentColor) {
        self._priceText = priceText
        self._currency = currency
        self.accentColor = accentColor
        self._draft = State(initialValue: priceText.wrappedValue)
        self._draftCurrency = State(initialValue: currency.wrappedValue)
    }

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"],
    ]

    var body: some View {
        ZStack {
            // Accent glow bleed at the top
            RadialGradient(
                colors: [accentColor.opacity(0.25), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(Color.primary.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Menu {
                        ForEach(currencies, id: \.self) { c in
                            Button {
                                withAnimation(Theme.quickSpring) { draftCurrency = c }
                            } label: {
                                if draftCurrency == c { Label(c, systemImage: "checkmark") }
                                else { Text(c) }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text("\(draftCurrency) (\(currencySymbol(for: draftCurrency)))")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .frame(height: 44)
                        .padding(.horizontal, 14)
                        .background(Color.primary.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.gridPadding)
                .padding(.top, Theme.Spacing.lg)

                // Amount display
                VStack(spacing: 4) {
                    Text("Amount")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text(displayText)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(draft.isEmpty ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(Theme.quickSpring, value: draft)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.md)

                // Keypad
                VStack(spacing: 10) {
                    ForEach(keys, id: \.self) { row in
                        HStack(spacing: 10) {
                            ForEach(row, id: \.self) { key in
                                PriceKeypadButton(key: key) { handleKey(key) }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.gridPadding)

                // Done
                Button {
                    priceText = draft
                    currency = draftCurrency
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.rounded(.body, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.lg)
                        .primaryGlassBackground(color: accentColor)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.gridPadding)
                .padding(.top, 16)
                .padding(.bottom, 52)
            }
        }
    }

    private var displayText: String {
        let sym = currencySymbol(for: draftCurrency)
        return draft.isEmpty ? "\(sym)0" : "\(sym)\(draft)"
    }

    private func currencySymbol(for code: String) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = code
        if code == "USD" { fmt.currencySymbol = "$" }
        return fmt.currencySymbol ?? code
    }

    private func handleKey(_ key: String) {
        switch key {
        case "⌫":
            if !draft.isEmpty { draft.removeLast() }
        case ".":
            guard !draft.contains(".") else { return }
            draft = draft.isEmpty ? "0." : draft + "."
        default:
            if draft == "0" { draft = key; return }
            if let dotIdx = draft.firstIndex(of: ".") {
                let decimals = draft.distance(from: draft.index(after: dotIdx), to: draft.endIndex)
                if decimals >= 2 { return }
            }
            draft += key
        }
    }
}

private struct PriceKeypadButton: View {
    let key: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if key == "⌫" {
                    Image(systemName: "delete.left")
                        .font(.system(size: 20, weight: .medium))
                } else {
                    Text(key)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                }
            }
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(Color.primary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Image source picker sheet

struct ImageSourcePickerSheet: View {
    let hasImage: Bool
    let onPhotoLibrary: () -> Void
    let onCamera: () -> Void
    let onEmoji: () -> Void
    let onRemove: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                List {
                    Section {
                        row(icon: "photo.on.rectangle", label: "Photo Library") {
                            onPhotoLibrary(); dismiss()
                        }
                        row(icon: "camera", label: "Camera") {
                            onCamera(); dismiss()
                        }
                        row(icon: "face.smiling", label: "Emoji") {
                            onEmoji(); dismiss()
                        }
                    }
                    if hasImage {
                        Section {
                            Button(role: .destructive) {
                                onRemove(); dismiss()
                            } label: {
                                Label("Remove Image", systemImage: "trash")
                            }
                            .listRowBackground(Theme.Colors.surface)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private func row(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .listRowBackground(Theme.Colors.surface)
    }
}

// MARK: - Image selector sheet (pick from fetched product images)

struct ImageSelectorSheet: View {
    let images: [URL]
    let currentImageURL: String
    let accentColor: Color
    let onSelect: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    private var allImages: [URL] {
        var all: [URL] = []
        if let current = URL(string: currentImageURL) { all.append(current) }
        for img in images where img.absoluteString != currentImageURL {
            all.append(img)
        }
        return all
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                    ], spacing: 10) {
                        ForEach(allImages, id: \.absoluteString) { url in
                            let isSelected = url.absoluteString == currentImageURL
                            Button {
                                onSelect(url)
                                dismiss()
                            } label: {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    case .failure:
                                        ZStack {
                                            Color(Theme.Colors.surfaceElevated)
                                            Image(systemName: "photo")
                                                .foregroundStyle(Theme.Colors.textTertiary)
                                        }
                                    default:
                                        ZStack {
                                            Color(Theme.Colors.surfaceElevated)
                                            ProgressView()
                                                .tint(Theme.Colors.textTertiary)
                                        }
                                    }
                                }
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.image, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.image, style: .continuous)
                                        .strokeBorder(isSelected ? accentColor : .clear, lineWidth: 3)
                                )
                                .overlay(alignment: .topTrailing) {
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(accentColor)
                                            .background(Circle().fill(.white).padding(2))
                                            .padding(8)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.Spacing.gridPadding)
                }
            }
            .navigationTitle("Choose Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }
}
