import SwiftUI

// MARK: - NewListView

struct NewListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var selectedEmoji = "✨"
    @State private var selectedColorHex = Theme.Colors.presets[5].hex
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    @State private var reminders: Set<ReminderOption> = []
    @State private var isShowingRemindersPicker = false

    @State private var isCustomizing = false
    @FocusState private var isNameFocused: Bool

    @Namespace private var ns

    var listToEdit: WishList? = nil
    var onCreated: ((WishList) -> Void)? = nil

    private var isEditing: Bool { listToEdit != nil }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Theme.backgroundGradient.ignoresSafeArea()

                // Main scroll content
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        emojiCircleButton
                            .padding(.top, Theme.Spacing.xl)

                        // Name-only identity card (color lives in customize panel)
                        identityCard

                        deadlineCard
                    }
                    .padding(.horizontal, Theme.Spacing.gridPadding)
                    .padding(.bottom, 120)
                }
                .disabled(isCustomizing) // block scroll interaction while panel is open

                // Add List button — hidden while customizing
                if !isCustomizing {
                    bottomButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Customization overlay
                if isCustomizing {
                    customizeOverlay
                        .zIndex(10)
                        .transition(.opacity)
                }
            }
            .animation(Theme.spring, value: isCustomizing)
            .navigationTitle(isEditing ? "Edit List" : "New List")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { prefillIfEditing() }
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isCustomizing {
                            withAnimation(Theme.spring) { isCustomizing = false }
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Emoji circle button

    private var emojiCircleButton: some View {
        Button {
            withAnimation(Theme.spring) { isCustomizing = true }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: selectedColorHex).opacity(0.18))
                    .frame(width: 110, height: 110)
                    .shadow(color: Color(hex: selectedColorHex).opacity(0.25), radius: 16, y: 4)
                Text(selectedEmoji)
                    .font(.system(size: 52))
            }
            .matchedGeometryEffect(id: "emojiCircle", in: ns, isSource: !isCustomizing)
            .overlay(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.surface)
                        .frame(width: 26, height: 26)
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .offset(x: 4, y: 4)
                .opacity(isCustomizing ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
        .animation(Theme.spring, value: selectedColorHex)
    }

    // MARK: - Customization overlay

    private var customizeOverlay: some View {
        ZStack(alignment: .bottom) {

            // Dim backdrop — tap to close
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(Theme.spring) { isCustomizing = false }
                }

            // Large emoji — flies out of the card via matched geometry
            VStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: selectedColorHex).opacity(0.22))
                        .frame(width: 110, height: 110)
                        .shadow(color: Color(hex: selectedColorHex).opacity(0.45),
                                radius: 32, y: 8)
                    Text(selectedEmoji)
                        .font(.system(size: 58))
                        .animation(Theme.spring, value: selectedEmoji)
                }
                .matchedGeometryEffect(id: "emojiCircle", in: ns, isSource: isCustomizing)
                .animation(Theme.spring, value: selectedColorHex)

                Spacer()
            }
            .padding(.top, 72)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
            .ignoresSafeArea()

            // Sliding panel
            customizePanel
                .transition(.move(edge: .bottom))
        }
    }

    private var customizePanel: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("Choose Icon")
                .font(.rounded(.callout, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.bottom, Theme.Spacing.md)

            // Emoji grid only
            emojiGrid
                .frame(height: 250)

            // Done button
            Button {
                withAnimation(Theme.spring) { isCustomizing = false }
            } label: {
                Text("Done")
                    .font(.rounded(.body, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
                    .primaryGlassBackground(color: Color(hex: selectedColorHex))
                    .animation(Theme.spring, value: selectedColorHex)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Spacing.gridPadding)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)
        }
        .padding(.bottom, 1) // ensure safe area edge attachment
        .background(Theme.Colors.surface, ignoresSafeAreaEdges: .bottom)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: Theme.Radius.sheet,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Theme.Radius.sheet
            )
        )
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // MARK: - Emoji grid

    private var emojiGrid: some View {
        let emojis = [
            "✨","🎂","🎁","💻","📱","🎮","👟","👜","🏠","🌿",
            "📚","🎵","🎨","🍕","☕","🌸","💎","🚀","🏋","🌊",
            "🎯","🧸","🌙","🦋","🍀","🎪","🦄","🍦","🌈","🎭",
            "🏆","💡","🔮","🎬","🎸","🍜","🌺","⚡","🎲","🏄",
            "🎀","🪴","🕯","🧩","🪄","🐾","🌍","🍷","🎓","🛍",
        ]
        return ScrollView(showsIndicators: false) {
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
                                ? Color(hex: selectedColorHex).opacity(0.25)
                                : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(
                                        selectedEmoji == emoji
                                        ? Color(hex: selectedColorHex) : .clear,
                                        lineWidth: 1.5
                                    )
                            )
                            .scaleEffect(selectedEmoji == emoji ? 1.1 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.gridPadding)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Identity card (name + color)

    private var identityCard: some View {
        VStack(spacing: 0) {
            // Name
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "text.cursor")
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 20)
                Text("Name")
                    .font(.system(.body))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                TextField("My Wishlist", text: $name)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .keyboardType(.default)
                    .submitLabel(.done)
                    .focused($isNameFocused)
            }
            .padding(Theme.Spacing.cardInner)
            .contentShape(Rectangle())
            .onTapGesture { isNameFocused = true }

            formDivider

            // Color — independent from icon editing
            formRow(icon: "paintpalette", label: "Color") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Theme.Colors.presets, id: \.hex) { preset in
                            let isSelected = selectedColorHex == preset.hex
                            Button {
                                selectedColorHex = preset.hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: preset.hex))
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Circle().strokeBorder(.white, lineWidth: 2.5)
                                            .opacity(isSelected ? 1 : 0)
                                    )
                                    .scaleEffect(isSelected ? 1.2 : 1.0)
                                    .shadow(
                                        color: Color(hex: preset.hex).opacity(0.6),
                                        radius: isSelected ? 5 : 0
                                    )
                                    .animation(Theme.quickSpring, value: isSelected)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Circle().size(CGSize(width: 44, height: 44)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .background(Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    // MARK: - Deadline card

    private var deadlineCard: some View {
        VStack(spacing: 0) {
            formRow(icon: "calendar", label: "Event Date") {
                Toggle("", isOn: $hasEndDate.animation(Theme.spring))
                    .labelsHidden()
                    .tint(Theme.Colors.accent)
            }

            if hasEndDate {
                formDivider
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .frame(width: 20)
                    Text("Date")
                        .font(.system(.body))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    DatePicker("", selection: $endDate, in: Date.now..., displayedComponents: .date)
                        .labelsHidden()
                        .tint(Theme.Colors.accent)

                }
                .padding(Theme.Spacing.cardInner)

                formDivider

                Button { isShowingRemindersPicker = true } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "bell")
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(width: 20)
                        Text("Reminders")
                            .font(.system(.body))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        Text(remindersSummary)
                            .font(.system(.subheadline))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .contentTransition(.identity)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
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
        .onChange(of: hasEndDate) { _, on in
            if !on { reminders = [] }
        }
        .sheet(isPresented: $isShowingRemindersPicker) {
            RemindersPickerSheet(reminders: $reminders, accentColor: Color(hex: selectedColorHex))
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Theme.Radius.sheet)
                .pageSheet()
        }
    }

    private func toggleReminder(_ option: ReminderOption) {
        if reminders.contains(option) {
            reminders.remove(option)
        } else {
            Task {
                let granted = await NotificationService.shared.requestPermission()
                await MainActor.run {
                    if granted { reminders.insert(option) }
                }
            }
        }
    }

    private var remindersSummary: String {
        if reminders.isEmpty { return "None" }
        let sorted = ReminderOption.allCases.filter { reminders.contains($0) }
        return sorted.map(\.label).joined(separator: ", ")
    }

    // MARK: - Participants card

    private var participantsCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "person.2")
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("Add Participants")
                    .font(.system(.body))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Let friends see and gift items")
                    .font(.system(.caption))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer()
            Text("Phase 3")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Colors.surfaceElevated, in: Capsule())
        }
        .padding(Theme.Spacing.cardInner)
        .background(Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .opacity(0.6)
    }

    // MARK: - Bottom button

    private var bottomButton: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Theme.Colors.backgroundBottom.opacity(0), Theme.Colors.backgroundBottom],
                startPoint: .top,
                endPoint: .center
            )
            .frame(height: 32)
            .allowsHitTesting(false)

            Button { saveOrCreate() } label: {
                Text(isEditing ? "Save Changes" : "Add List")
                    .font(.rounded(.body, weight: .semibold))
                    .foregroundStyle(canCreate ? .white : Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
                    .primaryGlassBackground(color: Color(hex: selectedColorHex), isEnabled: canCreate)
                    .animation(Theme.spring, value: selectedColorHex)
            }
            .buttonStyle(.plain)
            .disabled(!canCreate)
            .animation(Theme.spring, value: canCreate)
            .padding(.horizontal, Theme.Spacing.gridPadding)
            .padding(.bottom, 36)
            .background(Theme.Colors.backgroundBottom)
        }
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func formRow<Content: View>(
        icon: String, label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
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

    private func saveOrCreate() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let resolvedEndDate = hasEndDate ? endDate : nil

        if let list = listToEdit {
            list.name = trimmed
            list.emoji = selectedEmoji
            list.colorHex = selectedColorHex
            list.endDate = resolvedEndDate
            list.reminders = reminders
            scheduleOrCancelReminders(id: list.id, title: trimmed,
                                      endDate: resolvedEndDate, reminders: reminders)
        } else {
            let list = WishList(name: trimmed, emoji: selectedEmoji, colorHex: selectedColorHex,
                                endDate: resolvedEndDate, reminders: reminders)
            modelContext.insert(list)
            scheduleOrCancelReminders(id: list.id, title: trimmed,
                                      endDate: resolvedEndDate, reminders: reminders)
            onCreated?(list)
        }
        Haptics.success()
        dismiss()
    }

    private func scheduleOrCancelReminders(id: UUID, title: String,
                                           endDate: Date?, reminders: Set<ReminderOption>) {
        if let date = endDate, !reminders.isEmpty {
            Task { await NotificationService.shared.scheduleReminders(id: id, title: title, endDate: date, reminders: reminders) }
        } else {
            NotificationService.shared.cancelAll(id: id)
        }
    }

    private func prefillIfEditing() {
        guard let list = listToEdit else { return }
        name = list.name
        selectedEmoji = list.emoji
        selectedColorHex = list.colorHex
        hasEndDate = list.endDate != nil
        endDate = list.endDate ?? Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
        reminders = list.reminders
    }
}

#Preview {
    NewListView()
        .modelContainer(PreviewData.container)
}
