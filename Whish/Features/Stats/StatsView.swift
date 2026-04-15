import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var allItems: [WishItem]
    @Query(sort: \WishList.createdAt, order: .reverse) private var lists: [WishList]

    @AppStorage("defaultCurrency") private var defaultCurrency = "USD"
    @State private var viewModel = StatsViewModel()
    @State private var isShowingCurrencyPicker = false

    private var windowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first
    }
    private var deviceCornerRadius: CGFloat {
        let r = windowScene?.windows.first?.layer.cornerRadius ?? 0
        return r > 0 ? r : 44
    }

    /// Active items only (excludes archived lists), filtered by selected list.
    private var items: [WishItem] {
        let active = allItems.filter { $0.list?.isArchived != true }
        return viewModel.filteredItems(from: active)
    }

    /// Non-archived lists for the list picker and segments.
    private var activeLists: [WishList] {
        lists.filter { !$0.isArchived }
    }

    /// Accent color — app primary when "All", list color when a specific list is selected.
    private var accentColor: Color {
        if let list = viewModel.selectedList {
            return Color(hex: list.colorHex)
        }
        return Theme.Colors.accent
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .top) {
                // Ambient glow
                RadialGradient(
                    colors: [accentColor.opacity(0.15), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 320
                )
                .frame(height: 300)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(Theme.spring, value: viewModel.selectedList?.id)

                VStack(spacing: 0) {
                    Text("Statistics")
                        .font(.rounded(.title2, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)

                    heroSection
                        .padding(.top, Theme.Spacing.xl)

                    listPicker
                        .padding(.top, Theme.Spacing.xl)

                    overviewStrip
                        .padding(.horizontal, Theme.Spacing.gridPadding)
                        .padding(.top, Theme.Spacing.md)

                    breakdownCard
                        .padding(.horizontal, Theme.Spacing.gridPadding)
                        .padding(.top, Theme.Spacing.lg)

                    insightsFeed
                        .padding(.horizontal, Theme.Spacing.gridPadding)
                        .padding(.top, Theme.Spacing.lg)

                    statCards
                        .padding(.horizontal, Theme.Spacing.gridPadding)
                        .padding(.top, Theme.Spacing.lg)
                        .padding(.bottom, 100)
                }
            }
        }
        .background(.clear)
        .presentationCornerRadius(deviceCornerRadius)
        .presentationBackground {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Theme.Colors.background.opacity(0.85)
            }
        }
        .confirmationDialog("Display Currency", isPresented: $isShowingCurrencyPicker) {
            ForEach(viewModel.availableCurrencies(items: allItems), id: \.self) { currency in
                Button(currency) {
                    withAnimation(Theme.spring) { viewModel.displayCurrency = currency }
                }
            }
        } message: {
            Text("Amounts are converted using approximate exchange rates.")
        }
        .onAppear {
            viewModel.displayCurrency = defaultCurrency
        }
    }

    // MARK: - Hero (Ring + Value)

    private var heroSection: some View {
        let fraction = viewModel.completionFraction(items: items)
        let bought = viewModel.purchasedCount(items: items)
        let total = items.count
        let remaining = viewModel.remainingValue(items: items)
        let cur = viewModel.displayCurrency

        return HStack(spacing: Theme.Spacing.xl) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        accentColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(Theme.spring, value: fraction)

                Text("\(Int(fraction * 100))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }

            // Value + subtitle
            VStack(alignment: .leading, spacing: 4) {
                if remaining > 0 {
                    Button { isShowingCurrencyPicker = true } label: {
                        Text(remaining.formatted(currency: cur))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .buttonStyle(GlowPressStyle(color: Theme.Colors.accent))
                    .animation(Theme.spring, value: remaining)
                    .animation(Theme.spring, value: cur)
                } else if total == 0 {
                    Text("No wishes yet")
                        .font(.rounded(.title3, weight: .semibold))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("No price data")
                        .font(.rounded(.title3, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                if total > 0 {
                    Text("\(bought) of \(total) wishes fulfilled")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.gridPadding + 4)
    }

    // MARK: - List picker

    private var listPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                listChip(label: "All", emoji: nil, color: Theme.Colors.accent,
                         isSelected: viewModel.selectedList == nil) {
                    withAnimation(Theme.spring) { viewModel.selectedList = nil }
                }
                ForEach(activeLists) { list in
                    let isSelected = viewModel.selectedList?.persistentModelID == list.persistentModelID
                    listChip(label: list.name, emoji: list.emoji,
                             color: Color(hex: list.colorHex), isSelected: isSelected) {
                        withAnimation(Theme.spring) {
                            viewModel.selectedList = isSelected ? nil : list
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.gridPadding)
        }
    }

    private func listChip(label: String, emoji: String?, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let emoji {
                    Text(emoji).font(.system(size: 14))
                }
                Text(label)
                    .font(.system(.subheadline, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                isSelected ? color : Theme.Colors.surface,
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Overview strip

    private var overviewStrip: some View {
        let reserved = viewModel.reservedCount(items: items)
        let showReserved = reserved > 0

        return HStack(spacing: 0) {
            if viewModel.selectedList == nil {
                stripStat(label: activeLists.count == 1 ? "List" : "Lists", value: "\(activeLists.count)")
                Divider().frame(height: 28)
            }
            stripStat(label: items.count == 1 ? "Item" : "Items", value: "\(items.count)")
            Divider().frame(height: 28)
            stripStat(label: "Bought", value: "\(items.filter { $0.isPurchased }.count)")
            Divider().frame(height: 28)
            stripStat(label: "Wanted", value: "\(items.filter { !$0.isPurchased }.count)")
            if showReserved {
                Divider().frame(height: 28)
                stripStat(label: "Reserved", value: "\(reserved)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .background(
            Theme.Colors.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.2), lineWidth: 0.5)
        )
    }

    private func stripStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.rounded(.footnote, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Breakdown card (horizontal bars)

    private var breakdownCard: some View {
        let segs = viewModel.segments(items: items, lists: activeLists)
        let totalCount = segs.map(\.count).reduce(0, +)
        let cur = viewModel.displayCurrency

        return VStack(spacing: 0) {
            // Group picker pills
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(StatsGroupBy.allCases, id: \.self) { group in
                    let isActive = viewModel.groupBy == group
                    Button {
                        withAnimation(Theme.spring) { viewModel.groupBy = group }
                    } label: {
                        Text(group.rawValue)
                            .font(.system(.subheadline, weight: isActive ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                isActive ? Theme.Colors.accent : Color(.tertiarySystemFill),
                                in: Capsule()
                            )
                            .foregroundStyle(isActive ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)

            if segs.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.quaternary)
                    Text("No data")
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xl)
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(segs) { seg in
                        BreakdownRow(
                            segment: seg,
                            totalCount: totalCount,
                            currency: cur
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .background(
            Theme.Colors.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Insights feed

    @ViewBuilder
    private var insightsFeed: some View {
        let computed = viewModel.insights(items: items, lists: activeLists)
        if !computed.isEmpty {
            VStack(spacing: Theme.Spacing.cardGap) {
                ForEach(computed) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
    }

    // MARK: - Stat cards

    private var statCards: some View {
        let cur = viewModel.displayCurrency
        return HStack(spacing: Theme.Spacing.cardGap) {
            StatCard(
                title: "Total",
                value: viewModel.totalValue(items: items).formatted(currency: cur),
                icon: "sum",
                color: Theme.Colors.accent
            )
            StatCard(
                title: "Purchased",
                value: viewModel.purchasedValue(items: items).formatted(currency: cur),
                icon: "checkmark.circle.fill",
                color: Theme.Colors.purchased
            )
            StatCard(
                title: "Remaining",
                value: viewModel.remainingValue(items: items).formatted(currency: cur),
                icon: "heart.fill",
                color: Color(hex: "#FF6B6B")
            )
        }
    }
}

// MARK: - Breakdown Row

private struct BreakdownRow: View {
    let segment: StatSegment
    let totalCount: Int
    let currency: String

    private var fraction: CGFloat {
        totalCount > 0 ? CGFloat(segment.count) / CGFloat(totalCount) : 0
    }

    private var pct: Int {
        Int((fraction * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                if !segment.emoji.isEmpty {
                    Text(segment.emoji)
                        .font(.system(size: 14))
                }
                Text(segment.label)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text("\(segment.count)")
                    .font(.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(.primary)

                Text("· \(pct)%")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(.systemFill))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(segment.color)
                        .frame(width: max(6, geo.size.width * fraction), height: 6)
                        .animation(Theme.spring, value: fraction)
                }
            }
            .frame(height: 6)

            // Value subtitle (if items have prices)
            if segment.value > 0 {
                HStack {
                    Text(segment.value.formatted(currency: currency))
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Insight Card

private struct InsightCard: View {
    let insight: StatsInsight

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: insight.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(insight.color)
                .frame(width: 36, height: 36)
                .background(insight.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let subtitle = insight.subtitle {
                    Text(subtitle)
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.cardInner)
        .background(
            Theme.Colors.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.rounded(.callout, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
        }
        .padding(Theme.Spacing.cardInner)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.Colors.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Glow Press Style

private struct GlowPressStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(
                color: configuration.isPressed ? color.opacity(0.45) : .clear,
                radius: configuration.isPressed ? 28 : 0
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    Text("Open Stats")
        .sheet(isPresented: .constant(true)) {
            StatsView()
                .presentationDetents([.height(600), .large])
                .presentationDragIndicator(.visible)
        }
        .modelContainer(PreviewData.container)
}
