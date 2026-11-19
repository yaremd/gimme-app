import SwiftUI

/// Where a photo identification is up to in the Add Item form.
enum IdentifyPhase: Equatable {
    case idle
    case running
    case done(ProductIdentification)
    case failed(ProductIdentificationError)
}

/// The "Identify from a photo" card in the add-item forms. Stateless: the form's
/// `IdentifyController` owns the phase, and the form performs the actions and
/// supplies the card background (solid in Add Item, glass in the first-wish form).
struct IdentifyPhotoCard: View {
    let phase: IdentifyPhase
    let hasPhoto: Bool
    let usage: IdentifyUsage?
    let isPro: Bool
    /// Signed out, with this device's free try still unused.
    var trialAvailable: Bool = false
    /// The current result was the free try; invite the user to sign in for more.
    var wasTrial: Bool = false
    let accentColor: Color
    /// nil when the device has no camera.
    let onTakePhoto: (() -> Void)?
    let onChooseFromLibrary: () -> Void
    let onIdentify: () -> Void
    let onUseEstimate: (ProductIdentification.PriceEstimate) -> Void
    let onFindOnline: (URL) -> Void
    let onUpgrade: () -> Void
    let onSignIn: () -> Void
    /// The shop search that follows an identified product.
    var offers: OffersPhase = .idle
    var onOpenOffer: (URL) -> Void = { _ in }
    var onSelectOffer: (ShopOffer) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            switch phase {
            case .idle:
                if hasPhoto {
                    actionRow(icon: "sparkles", title: "Identify this photo",
                              subtitle: trialAvailable
                                  ? "Free try, no account needed"
                                  : allowanceText ?? "Fills in the name and details",
                              action: onIdentify)
                } else {
                    // A menu, not a dialog: it anchors to the card, and presenting the
                    // photo picker from a confirmation dialog inside a sheet dismisses
                    // the sheet on iOS 26.
                    photoSourceMenu {
                        row(icon: "sparkles", title: "Identify from a photo",
                            subtitle: trialAvailable
                                ? "Your first one is free, no account needed"
                                : "Snap or pick a photo and Gimme fills in the details") {
                            chevron("chevron.right")
                        }
                        .contentShape(Rectangle())
                    }
                }

            case .running:
                // A nil icon shows a spinner in the icon slot.
                row(icon: nil, title: "Identifying…", subtitle: "This takes a few seconds") { EmptyView() }

            case .done(let result) where result.foundProduct:
                foundRows(result)

            case .done(let result):
                row(icon: "questionmark.circle",
                    title: result.status == .notAProduct ? "No product spotted" : "Couldn't make it out",
                    subtitle: "Try a closer, well-lit photo of the item") {
                    photoSourceMenu { capsuleLabel("Try another") }
                }

            case .failed(let error):
                failureRow(error)
            }
        }
        .animation(Theme.spring, value: phase)
        .animation(Theme.spring, value: offers)
    }

    // MARK: - States

    @ViewBuilder
    private func foundRows(_ result: ProductIdentification) -> some View {
        row(icon: "checkmark.seal.fill",
            title: "Looks like \(result.title)",
            subtitle: result.status == .identified
                ? "Details filled in below"
                : "Not an exact match, so check the details")

        switch offers {
        case .found(let list, let selectedID):
            if let selected = list.first(where: { $0.id == selectedID }) ?? list.first {
                divider
                offerRow(list, selected: selected)
            }
        case .searching:
            estimateRow(result)
            divider
            row(icon: nil, title: "Finding the best price…", subtitle: "Checking shops for this item") { EmptyView() }
        case .idle, .none:
            estimateRow(result)
            if let url = result.shoppingSearchURL {
                divider
                actionRow(icon: "magnifyingglass", title: "Find it online",
                          subtitle: "Paste a store link above to track its price",
                          trailingSymbol: "arrow.up.right") { onFindOnline(url) }
            }
        }

        if wasTrial {
            divider
            row(icon: "person.crop.circle.badge.plus", title: "That was your free try",
                subtitle: Self.keepGoing) {
                trailingButton("Sign In", action: onSignIn)
            }
        }
    }

    @ViewBuilder
    private func estimateRow(_ result: ProductIdentification) -> some View {
        if let estimate = result.estimatedPrice {
            divider
            row(icon: "tag", title: "Usually \(estimate.rangeText)", subtitle: "Typical price new") {
                trailingButton("Use") { onUseEstimate(estimate) }
            }
        }
    }

    /// The offer in the form, with the others behind "Change".
    private func offerRow(_ list: [ShopOffer], selected: ShopOffer) -> some View {
        row(icon: "cart",
            title: "\(selected.priceText) at \(selected.store)",
            subtitle: Self.offerSubtitle(selected, in: list)) {
            HStack(spacing: Theme.Spacing.sm) {
                if list.count > 1 {
                    Menu {
                        ForEach(list) { offer in
                            Button { onSelectOffer(offer) } label: {
                                if offer.id == selected.id {
                                    Label(Self.menuTitle(offer), systemImage: "checkmark")
                                } else {
                                    Text(Self.menuTitle(offer))
                                }
                            }
                        }
                    } label: {
                        capsuleLabel("Change")
                    }
                    .buttonStyle(.plain)
                }
                Button { onOpenOffer(selected.url) } label: {
                    chevron("arrow.up.right")
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(selected.store)")
            }
        }
    }

    /// What the offer row says about the offer in the form. A price only the search saw
    /// is flagged, since it wasn't checked on the shop's page and can be out of date.
    static func offerSubtitle(_ selected: ShopOffer, in list: [ShopOffer]) -> String {
        guard selected.checked else { return "Price from search, may be out of date" }
        guard selected.best else { return "Link and price added" }
        // The best checked price, but the search saw a lower one that couldn't be checked.
        return list.contains { $0.price < selected.price }
            ? "Best confirmed price, link added"
            : "Best price found, link added"
    }

    /// An offer in the Change menu, e.g. "$109.99 · Walmart · from search".
    static func menuTitle(_ offer: ShopOffer) -> String {
        let title = "\(offer.priceText) · \(offer.store)"
        return offer.checked ? title : "\(title) · from search"
    }

    // Keep the number in step with IDENTIFY_FREE_MONTHLY_LIMIT on the identify-product function.
    private static let keepGoing = "Sign in to keep going, with 5 free a month"

    @ViewBuilder
    private func failureRow(_ error: ProductIdentificationError) -> some View {
        switch error {
        case .quotaExceeded(let usage):
            row(icon: "sparkles",
                title: "No identifications left this month",
                subtitle: isPro || usage == nil
                    ? resetText(usage) ?? "Your allowance resets next month"
                    : "Go Pro for more each month") {
                if !isPro { trailingButton("Upgrade", action: onUpgrade) }
            }
        case .notSignedIn:
            row(icon: "person.crop.circle", title: "Sign in to identify photos",
                subtitle: "Free, and your lists sync across devices") {
                trailingButton("Sign In", action: onSignIn)
            }
        case .trialUsed:
            row(icon: "person.crop.circle", title: "You've used your free try",
                subtitle: Self.keepGoing) {
                trailingButton("Sign In", action: onSignIn)
            }
        default:
            row(icon: "exclamationmark.triangle",
                title: error.errorDescription ?? "Something went wrong",
                subtitle: nil) {
                if error.isRetryable { trailingButton("Try again", action: onIdentify) }
            }
        }
    }

    // MARK: - Copy

    private var allowanceText: String? {
        guard let usage, usage.limit > 0 else { return nil }
        return "\(usage.remaining) of \(usage.limit) left this month"
    }

    private func resetText(_ usage: IdentifyUsage?) -> String? {
        guard let usage else { return nil }
        return "Resets \(usage.periodEnd.formatted(.dateTime.month(.abbreviated).day()))"
    }

    // MARK: - Building blocks

    private func actionRow(icon: String, title: String, subtitle: String?,
                           trailingSymbol: String = "chevron.right",
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            row(icon: icon, title: title, subtitle: subtitle) { chevron(trailingSymbol) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func photoSourceMenu<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Menu {
            if let onTakePhoto {
                Button(action: onTakePhoto) { SwiftUI.Label("Take Photo", systemImage: "camera") }
            }
            Button(action: onChooseFromLibrary) {
                SwiftUI.Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            label()
        }
        .buttonStyle(.plain)
    }

    private func chevron(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.Colors.textTertiary)
    }

    private func row(icon: String, title: String, subtitle: String?) -> some View {
        row(icon: icon, title: title, subtitle: subtitle) { EmptyView() }
    }

    private func row<Trailing: View>(icon: String? = nil, title: String, subtitle: String?,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Group {
                if let icon {
                    Image(systemName: icon).foregroundStyle(accentColor)
                } else {
                    ProgressView().tint(accentColor)
                }
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.caption))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            trailing()
        }
        .padding(Theme.Spacing.cardInner)
    }

    private func trailingButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { capsuleLabel(label) }
            .buttonStyle(.plain)
    }

    private func capsuleLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(accentColor.opacity(0.12), in: Capsule())
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Colors.surfaceBorder)
            .frame(height: 0.5)
            .padding(.leading, 52)
    }
}

// MARK: - Consent

/// Explicit permission before any photo goes to a third-party AI (App Review 5.1.2(i)).
struct IdentifyConsentSheet: View {
    let accentColor: Color
    let onAllow: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 60, height: 60)
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
                .padding(.top, Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.sm) {
                    Text("Identify items from photos")
                        .font(.rounded(.title3, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Gimme sends the photo you choose to Claude, an AI model made by Anthropic. It recognises the item, suggests a name, details and a typical price, and looks for shops that sell it.")
                        .font(.system(.subheadline))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    point("hand.tap", "Only photos you choose to identify are sent")
                    point("person.crop.circle.badge.checkmark", "Sent without your name or email")
                    point("cart", "Shops are searched by the item's name, never the photo")
                    point("gearshape", "Turn it off anytime in Settings")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.cardInner)
                .background(Theme.Colors.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))

                Link("Privacy Policy", destination: URL(string: "https://gimmelist.com/privacy")!)
                    .font(.system(.footnote, weight: .medium))
                    .foregroundStyle(accentColor)

                VStack(spacing: Theme.Spacing.sm) {
                    Button {
                        onAllow()
                        dismiss()
                    } label: {
                        Text("Allow and Identify")
                            .font(.rounded(.body, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.lg)
                            .primaryGlassBackground(color: accentColor)
                    }
                    .buttonStyle(.plain)

                    Button("Not Now") { dismiss() }
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.vertical, Theme.Spacing.sm)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    private func point(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(accentColor)
                .frame(width: 22)
            Text(text)
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }
}

#if DEBUG
#Preview("Card states") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(Array([
                IdentifyPhase.idle,
                .running,
                .done(MockProductIdentificationService.sneakers),
                .failed(.quotaExceeded(nil)),
                .failed(.network),
            ].enumerated()), id: \.offset) { _, phase in
                IdentifyPhotoCard(phase: phase, hasPhoto: true, usage: nil, isPro: false,
                                  accentColor: Theme.Colors.accent,
                                  onTakePhoto: {}, onChooseFromLibrary: {}, onIdentify: {},
                                  onUseEstimate: { _ in }, onFindOnline: { _ in },
                                  onUpgrade: {}, onSignIn: {})
                .background(Theme.Colors.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            }
            ForEach(Array([
                OffersPhase.searching,
                .found(MockProductIdentificationService.offers,
                       selected: MockProductIdentificationService.offers[0].id),
            ].enumerated()), id: \.offset) { _, offers in
                IdentifyPhotoCard(phase: .done(MockProductIdentificationService.sneakers), hasPhoto: true,
                                  usage: nil, isPro: false, accentColor: Theme.Colors.accent,
                                  onTakePhoto: {}, onChooseFromLibrary: {}, onIdentify: {},
                                  onUseEstimate: { _ in }, onFindOnline: { _ in },
                                  onUpgrade: {}, onSignIn: {}, offers: offers)
                .background(Theme.Colors.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            }
        }
        .padding()
    }
    .background(Theme.backgroundGradient)
}

#Preview("Consent") {
    IdentifyConsentSheet(accentColor: Theme.Colors.accent, onAllow: {})
}
#endif
