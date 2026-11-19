import SwiftUI

/// Where the shop search for an identified product is up to.
enum OffersPhase: Equatable {
    case idle
    case searching
    /// Offers cheapest first; `selected` is the one in the form.
    case found([ShopOffer], selected: ShopOffer.ID)
    /// Nothing confirmed, or the search failed: the card falls back to "Find it online".
    case none
}

/// Runs photo identification for an add-item form: the sign-in gate, the
/// consent step, the request, and dropping results for a photo that has since
/// changed. When a specific product is identified it then searches shops for it
/// and hands the cheapest offer to the form. The form owns the photo and decides
/// how a result or an offer fills its fields. Shared by `AddItemView` and `FirstItemView`.
@Observable
@MainActor
final class IdentifyController {

    static let consentKey = "photoIdentifyConsent"

    private(set) var phase: IdentifyPhase = .idle
    private(set) var offers: OffersPhase = .idle
    /// The latest monthly allowance the server reported.
    private(set) var usage: IdentifyUsage?
    /// The current result came from a signed-out user's free try, so the card invites them to sign in.
    private(set) var lastWasTrial = false
    /// Drives the consent sheet (see `identifyConsentSheet(_:accentColor:)`).
    var isShowingConsent = false

    @ObservationIgnored private let service: any ProductIdentificationService
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let shoppingCountry: @Sendable () async -> String?
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var pending: Pending?
    @ObservationIgnored private var applyOffer: ((ShopOffer) -> Void)?

    private struct Pending {
        let imageData: Data
        let currency: String
        let apply: (ProductIdentification) -> Void
        let applyOffer: (ShopOffer) -> Void
    }

    /// `shoppingCountry` says where the user shops (ISO 3166 code); the App Store
    /// country by default, with `locale` covering anything it can't tell.
    init(service: any ProductIdentificationService = ProductIdentifier.makeService(),
         defaults: UserDefaults = .standard,
         locale: Locale = .current,
         shoppingCountry: @escaping @Sendable () async -> String? = { await ShoppingCountry.current() }) {
        self.service = service
        self.defaults = defaults
        self.locale = locale
        self.shoppingCountry = shoppingCountry
    }

    /// Explicit permission to send photos to a third-party AI (App Review 5.1.2(i)).
    /// Same key as the Settings switch, which reads it through `@AppStorage`.
    var hasConsent: Bool { defaults.bool(forKey: Self.consentKey) }

    /// A signed-out user can still identify one photo on this device.
    var offersTrial: Bool { service.offersTrial }

    /// Forgets the current result and its shop search, e.g. when the photo changes or is removed.
    func reset() {
        requestID = UUID()
        pending = nil
        applyOffer = nil
        lastWasTrial = false
        phase = .idle
        offers = .idle
    }

    /// Puts another of the found offers in the form ("Change" on the card).
    func selectOffer(_ offer: ShopOffer) {
        guard case .found(let list, _) = offers, list.contains(offer) else { return }
        applyOffer?(offer)
        withAnimation(Theme.spring) { offers = .found(list, selected: offer.id) }
        Haptics.selection()
    }

    /// Clears the sign-in prompts once the user has signed in.
    func signedInChanged(_ signedIn: Bool) {
        guard signedIn else { return }
        lastWasTrial = false
        if phase == .failed(.notSignedIn) || phase == .failed(.trialUsed) { phase = .idle }
    }

    /// Identifies `imageData`, asking to sign in or for consent first when needed.
    /// Signed-out users get one free try per device before they're asked to sign in.
    /// `apply` receives the result before the card shows it, so the form can fill its fields;
    /// `applyOffer` later receives the cheapest shop found for it, and any offer the user picks instead.
    func start(imageData: Data, currency: String, isSignedIn: Bool,
               apply: @escaping (ProductIdentification) -> Void,
               applyOffer: @escaping (ShopOffer) -> Void = { _ in }) {
        if service.requiresSignIn && !isSignedIn && !service.offersTrial {
            withAnimation(Theme.spring) { phase = .failed(.notSignedIn) }
            return
        }
        guard hasConsent else {
            pending = Pending(imageData: imageData, currency: currency, apply: apply, applyOffer: applyOffer)
            isShowingConsent = true
            return
        }
        run(imageData: imageData, currency: currency, apply: apply, applyOffer: applyOffer)
    }

    /// The consent sheet's Allow button: remembers the answer and runs what was waiting on it.
    func grantConsent() {
        defaults.set(true, forKey: Self.consentKey)
        guard let waiting = pending else { return }
        pending = nil
        run(imageData: waiting.imageData, currency: waiting.currency,
            apply: waiting.apply, applyOffer: waiting.applyOffer)
    }

    private func run(imageData: Data, currency: String,
                     apply: @escaping (ProductIdentification) -> Void,
                     applyOffer: @escaping (ShopOffer) -> Void) {
        let thisRequest = UUID()
        requestID = thisRequest
        self.applyOffer = applyOffer
        withAnimation(Theme.spring) {
            phase = .running
            offers = .idle
        }

        Task {
            let next: IdentifyPhase
            var offersToken: String?
            do {
                let response = try await service.identify(imageData: imageData, currency: currency)
                guard requestID == thisRequest else { return }
                if let reported = response.usage { usage = reported }
                lastWasTrial = response.trial == true
                apply(response.result)
                next = .done(response.result)
                offersToken = response.offersToken
                if response.result.foundProduct { Haptics.success() } else { Haptics.warning() }
            } catch let error as ProductIdentificationError {
                guard requestID == thisRequest else { return }
                if case .quotaExceeded(let reported?) = error { usage = reported }
                next = .failed(error)
                Haptics.error()
            } catch {
                guard requestID == thisRequest else { return }
                next = .failed(.network)
                Haptics.error()
            }
            withAnimation(Theme.spring) {
                phase = next
                if offersToken != nil { offers = .searching }
            }
            if let offersToken {
                await searchOffers(token: offersToken, fallbackCurrency: currency, request: thisRequest)
            }
        }
    }

    /// Shops are searched where the user shops (their App Store country) and in that
    /// country's currency, which is what local shops price in, whatever currency the
    /// form started with.
    private func searchOffers(token: String, fallbackCurrency: String, request: UUID) async {
        let next: OffersPhase
        do {
            let country = await shoppingCountry() ?? locale.region?.identifier
            let currency = country.flatMap(ShoppingCountry.currency(for:))
                ?? locale.currency?.identifier
                ?? fallbackCurrency
            let found = try await service.findOffers(token: token, country: country, currency: currency)
            guard requestID == request else { return }
            if let best = found.first(where: \.best) ?? found.first {
                applyOffer?(best)
                next = .found(found, selected: best.id)
            } else {
                next = .none
            }
        } catch {
            guard requestID == request else { return }
            next = .none
        }
        withAnimation(Theme.spring) { offers = next }
    }
}

extension View {
    /// The consent sheet an `IdentifyController` raises before the first photo is sent.
    func identifyConsentSheet(_ controller: IdentifyController, accentColor: Color) -> some View {
        sheet(isPresented: Binding(
            get: { controller.isShowingConsent },
            set: { controller.isShowingConsent = $0 }
        )) {
            IdentifyConsentSheet(accentColor: accentColor) { controller.grantConsent() }
                .presentationDetents([.height(590), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Theme.Radius.sheet)
                .pageSheet()
        }
    }
}
