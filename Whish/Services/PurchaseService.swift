import Foundation
import StoreKit

/// Observable StoreKit 2 purchase manager. Inject via @Environment throughout the app.
@Observable
@MainActor
final class PurchaseService {

    // MARK: - Public state

    private(set) var isPro: Bool
    private(set) var product: Product?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// Set by WhishApp on sign-in/out so purchase() and handle() can sync to Supabase
    /// without needing a coordinator observer.
    var currentUserID: String?

    // MARK: - Constants

    nonisolated static let productID = "com.yaremchuk.app.pro.lifetime"

    static let claimedByOtherAccountMessage =
        "This purchase is linked to another Gimme account. Sign in to that account to use Pro."

    private static let isProKey = "isPro"

    // MARK: - Dependencies

    private let defaults: UserDefaults
    private let verifier: any ProPurchaseVerifying

    // MARK: - Init

    /// - Parameters:
    ///   - defaults: where the Pro flag and the device claim are kept.
    ///   - verifier: checks transactions with the server (verify-purchase).
    ///   - observesStoreKit: false in tests, which drive the service without StoreKit.
    init(
        defaults: UserDefaults = .standard,
        verifier: any ProPurchaseVerifying = SupabaseProPurchaseVerifier(),
        observesStoreKit: Bool = true
    ) {
        self.defaults = defaults
        self.verifier = verifier
        self.isPro = defaults.bool(forKey: Self.isProKey)
        guard observesStoreKit else { return }
        // Task inherits @MainActor from init — no actor-isolation issues.
        // bootstrap() runs forever (Transaction.updates is infinite), which is
        // intentional: the service lives for the app's lifetime.
        Task { await bootstrap() }
    }

    // MARK: - Purchase

    func purchase() async {
        if product == nil { await loadProduct() }
        guard let product else {
            if errorMessage == nil {
                errorMessage = "Product unavailable. Check your connection and try again."
            }
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                if let uid = currentUserID {
                    claimPro(for: uid)
                    // Hear from the server before unlocking (and celebrating):
                    // a purchase linked to another account leaves this one free.
                    let outcome = await syncProToSupabase(jws: verification.jwsRepresentation)
                    if outcome.keepsAccountFree {
                        if outcome == .claimedByOtherAccount {
                            errorMessage = Self.claimedByOtherAccountMessage
                        }
                        return
                    }
                }
                setPro(true)
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            guard let jws = await Self.currentEntitlementJWS() else {
                setPro(false)
                return
            }
            if let uid = currentUserID {
                claimPro(for: uid)
                let outcome = await syncProToSupabase(jws: jws)
                if outcome.keepsAccountFree {
                    if outcome == .claimedByOtherAccount {
                        errorMessage = Self.claimedByOtherAccountMessage
                    }
                    return
                }
            }
            setPro(true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    func clearError() { errorMessage = nil }

    // MARK: - Private

    /// Loads product info, verifies existing entitlement, then listens for
    /// ongoing transaction updates (subscription renewals, refunds, etc.).
    private func bootstrap() async {
        await loadProduct()
        await verifyEntitlement()
        for await verificationResult in Transaction.updates {
            await handle(verificationResult)
        }
    }

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            if products.isEmpty {
                // Product ID not found in App Store Connect — IAP not yet approved
                // or the Paid Apps agreement is incomplete.
                errorMessage = "Purchase setup is incomplete. Please try again later or contact support."
            } else {
                product = products.first
                errorMessage = nil
            }
        } catch {
            // Network or StoreKit framework error — transient.
            // price label falls back to "$4.99" in PaywallView.
        }
    }

    func verifyEntitlement() async {
        let found = await Self.currentEntitlementJWS() != nil
        setPro(found)
    }

    /// The signed transaction behind this device's Pro entitlement, if any.
    /// Iterates StoreKit entitlements off @MainActor to avoid blocking UI.
    private nonisolated static func currentEntitlementJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == productID,
               tx.revocationDate == nil {
                return result.jwsRepresentation
            }
        }
        return nil
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let tx) = result else { return }
        if tx.productID == Self.productID {
            let isActive = tx.revocationDate == nil
            if !isActive { clearClaim() }
            setPro(isActive)
            // A refund has to reach the account, not just this device. An
            // active transaction (Ask to Buy, a purchase finishing late) is
            // linked to the signed-in account unless another one claimed it here.
            if let uid = currentUserID {
                let claimedBy = claimedByUserID()
                if !isActive || claimedBy == nil || claimedBy == uid {
                    if isActive { claimPro(for: uid) }
                    await syncProToSupabase(jws: result.jwsRepresentation)
                }
            }
        }
        // Finish after the sync, so a transaction interrupted mid-sync is
        // delivered again on next launch.
        await tx.finish()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value): return value
        }
    }

    /// Re-checks local StoreKit entitlements silently. No Apple ID prompt.
    func refreshEntitlement() async {
        await verifyEntitlement()
    }

    func resetProStatus() {
        setPro(false)
    }

    /// Forces Pro = true locally. Used when Supabase confirms Pro but StoreKit
    /// has no entitlement on this device (e.g. purchased on a different device).
    func grantPro() {
        setPro(true)
    }

    // MARK: - Claim lock (anonymous purchase ownership)

    private static let claimKey = "proClaimedByUserID"

    /// Stamps this device's anonymous purchase as belonging to `userID`.
    func claimPro(for userID: String) {
        defaults.set(userID, forKey: Self.claimKey)
    }

    /// Returns the Supabase user ID that has claimed the local StoreKit entitlement,
    /// or nil if the purchase was made anonymously and not yet claimed.
    func claimedByUserID() -> String? {
        defaults.string(forKey: Self.claimKey)
    }

    private func clearClaim() {
        defaults.removeObject(forKey: Self.claimKey)
    }

    // MARK: - Supabase Pro sync

    /// Sends a StoreKit transaction (its `jwsRepresentation`) to the
    /// verify-purchase Edge Function, which checks Apple's signature and
    /// records the purchase, or its refund, on the signed-in account.
    /// Clients can't write `profiles.is_pro` themselves (migration v10); the
    /// server's answer is applied here and returned.
    /// Called after purchase, restore, sign-in, and Transaction.updates.
    @discardableResult
    func syncProToSupabase(jws: String) async -> ProVerificationResult {
        guard let uid = currentUserID else { return .unavailable }
        let outcome = await verifier.verify(jws: jws)
        // Signed out or switched accounts while waiting: the answer was for someone else.
        guard currentUserID == uid else { return .unavailable }
        switch outcome {
        case .verified(isPro: true):
            claimPro(for: uid)
            setPro(true)
        case .verified(isPro: false), .claimedByOtherAccount:
            clearClaim()
            setPro(false)
        case .rejected, .unavailable:
            // Nothing new is known: keep what StoreKit says on this device.
            // The next sign-in sync tries again.
            break
        }
        return outcome
    }

    /// Sends this device's Pro entitlement, if it has one, to the server.
    /// Used on sign-in when the account has no Pro on record yet.
    func syncCurrentEntitlementToSupabase() async {
        guard let jws = await Self.currentEntitlementJWS() else { return }
        await syncProToSupabase(jws: jws)
    }

    /// Fetches the user's Pro status from `profiles`. Returns false if the row
    /// doesn't exist yet (new account that has never purchased).
    func fetchProFromSupabase(userID: String) async -> Bool {
        struct ProfileRow: Decodable {
            // swiftlint:disable:next identifier_name
            let is_pro: Bool
        }
        let rows: [ProfileRow]? = try? await supabase
            .from("profiles")
            .select("is_pro")
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows?.first?.is_pro ?? false
    }

    #if DEBUG
    func debugTogglePro() {
        setPro(!isPro)
    }
    #endif

    private func setPro(_ value: Bool) {
        isPro = value
        defaults.set(value, forKey: Self.isProKey)
    }
}
