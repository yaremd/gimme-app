import SwiftUI

/// Runs photo identification for an add-item form: the sign-in gate, the
/// consent step, the request, and dropping results for a photo that has since
/// changed. The form owns the photo and decides how a result fills its fields.
/// Shared by `AddItemView` and `FirstItemView`.
@Observable
@MainActor
final class IdentifyController {

    static let consentKey = "photoIdentifyConsent"

    private(set) var phase: IdentifyPhase = .idle
    /// The latest monthly allowance the server reported.
    private(set) var usage: IdentifyUsage?
    /// The current result came from a signed-out user's free try, so the card invites them to sign in.
    private(set) var lastWasTrial = false
    /// Drives the consent sheet (see `identifyConsentSheet(_:accentColor:)`).
    var isShowingConsent = false

    @ObservationIgnored private let service: any ProductIdentificationService
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var pending: Pending?

    private struct Pending {
        let imageData: Data
        let currency: String
        let apply: (ProductIdentification) -> Void
    }

    init(service: any ProductIdentificationService = ProductIdentifier.makeService(),
         defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
    }

    /// Explicit permission to send photos to a third-party AI (App Review 5.1.2(i)).
    /// Same key as the Settings switch, which reads it through `@AppStorage`.
    var hasConsent: Bool { defaults.bool(forKey: Self.consentKey) }

    /// A signed-out user can still identify one photo on this device.
    var offersTrial: Bool { service.offersTrial }

    /// Forgets the current result, e.g. when the photo changes or is removed.
    func reset() {
        requestID = UUID()
        pending = nil
        lastWasTrial = false
        phase = .idle
    }

    /// Clears the sign-in prompts once the user has signed in.
    func signedInChanged(_ signedIn: Bool) {
        guard signedIn else { return }
        lastWasTrial = false
        if phase == .failed(.notSignedIn) || phase == .failed(.trialUsed) { phase = .idle }
    }

    /// Identifies `imageData`, asking to sign in or for consent first when needed.
    /// Signed-out users get one free try per device before they're asked to sign in.
    /// `apply` receives the result before the card shows it, so the form can fill its fields.
    func start(imageData: Data, currency: String, isSignedIn: Bool,
               apply: @escaping (ProductIdentification) -> Void) {
        if service.requiresSignIn && !isSignedIn && !service.offersTrial {
            withAnimation(Theme.spring) { phase = .failed(.notSignedIn) }
            return
        }
        guard hasConsent else {
            pending = Pending(imageData: imageData, currency: currency, apply: apply)
            isShowingConsent = true
            return
        }
        run(imageData: imageData, currency: currency, apply: apply)
    }

    /// The consent sheet's Allow button: remembers the answer and runs what was waiting on it.
    func grantConsent() {
        defaults.set(true, forKey: Self.consentKey)
        guard let waiting = pending else { return }
        pending = nil
        run(imageData: waiting.imageData, currency: waiting.currency, apply: waiting.apply)
    }

    private func run(imageData: Data, currency: String, apply: @escaping (ProductIdentification) -> Void) {
        let thisRequest = UUID()
        requestID = thisRequest
        withAnimation(Theme.spring) { phase = .running }

        Task {
            let next: IdentifyPhase
            do {
                let response = try await service.identify(imageData: imageData, currency: currency)
                guard requestID == thisRequest else { return }
                if let reported = response.usage { usage = reported }
                lastWasTrial = response.trial == true
                apply(response.result)
                next = .done(response.result)
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
            withAnimation(Theme.spring) { phase = next }
        }
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
                .presentationDetents([.height(540), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(Theme.Radius.sheet)
                .pageSheet()
        }
    }
}
