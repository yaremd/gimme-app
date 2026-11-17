import Foundation
import StoreKit

/// Observable StoreKit 2 purchase manager. Inject via @Environment throughout the app.
///
/// Pro here = this device's StoreKit entitlement OR the signed-in account's
/// Pro on the server (it may have been bought on another device or Apple ID).
/// The two are kept apart, so a StoreKit check on a device without the
/// entitlement can't undo the account's Pro, whichever finishes last. The
/// server's no (a refund, or a purchase that's another account's) and
/// signing out still turn it off.
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

    // MARK: - Where Pro comes from

    /// Whether this device's StoreKit holds the Pro entitlement, as last checked.
    @ObservationIgnored private var deviceHasEntitlement = false
    /// The account the server last said has Pro. Counts only while it's signed in.
    @ObservationIgnored private var proAccountID: String?
    /// The account for which the server turned this device's purchase down
    /// (refunded, or another account's). While it stays signed in, StoreKit
    /// still listing the purchase doesn't unlock Pro.
    @ObservationIgnored private var deviceEntitlementRefusedFor: String?

    // MARK: - Constants

    nonisolated static let productID = "com.yaremchuk.app.pro.lifetime"

    static let claimedByOtherAccountMessage =
        "This purchase is linked to another Gimme account. Sign in to that account to use Pro."

    private static let isProKey = "isPro"

    // MARK: - Dependencies

    private let defaults: UserDefaults
    private let verifier: any ProPurchaseVerifying
    private let entitlements: any ProEntitlementChecking

    // MARK: - Init

    /// - Parameters:
    ///   - defaults: where the Pro flag and the device claim are kept.
    ///   - verifier: checks transactions with the server (verify-purchase).
    ///   - entitlements: this device's StoreKit entitlement and Restore Purchases.
    ///   - observesStoreKit: false in tests: no product load, launch check or
    ///     Transaction.updates listener.
    init(
        defaults: UserDefaults = .standard,
        verifier: any ProPurchaseVerifying = SupabaseProPurchaseVerifier(),
        entitlements: any ProEntitlementChecking = StoreKitProEntitlements(),
        observesStoreKit: Bool = true
    ) {
        self.defaults = defaults
        self.verifier = verifier
        self.entitlements = entitlements
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
                deviceHasEntitlement = true
                // A new purchase: the server judges it afresh.
                deviceEntitlementRefusedFor = nil
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
                updatePro()
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
            try await entitlements.syncWithAppStore()
            let jws = await entitlements.currentEntitlementJWS()
            deviceHasEntitlement = jws != nil
            guard let jws else {
                // Nothing to restore on this Apple ID. Pro the account has on
                // the server (bought elsewhere) stays.
                updatePro()
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
            updatePro()
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

    /// Re-reads this device's StoreKit entitlement. It never takes away Pro
    /// the signed-in account has on the server.
    func verifyEntitlement() async {
        deviceHasEntitlement = await entitlements.currentEntitlementJWS() != nil
        updatePro()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let tx) = result else { return }
        if tx.productID == Self.productID {
            let isActive = tx.revocationDate == nil
            if !isActive { clearClaim() }
            deviceHasEntitlement = isActive
            updatePro()
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
    /// Pro the signed-in account has on the server stays whatever it finds.
    func refreshEntitlement() async {
        await verifyEntitlement()
    }

    /// Pro off: on sign-out, or when another account owns this device's
    /// purchase. Forgets the account's Pro and the last StoreKit check, so
    /// only a new check or server answer turns it back on.
    func resetProStatus() {
        proAccountID = nil
        deviceEntitlementRefusedFor = nil
        deviceHasEntitlement = false
        setPro(false)
    }

    /// The server has Pro on record for `userID`, maybe bought on another
    /// device or Apple ID. Pro here while that account stays signed in,
    /// whatever StoreKit on this device says. Ignored once it has signed out.
    func grantPro(for userID: String) {
        guard currentUserID == userID else { return }
        proAccountID = userID
        updatePro()
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
            proAccountID = uid
            updatePro()
        case .verified(isPro: false), .claimedByOtherAccount:
            // Refunded, or another account's purchase: off for this account,
            // even while StoreKit here still lists the purchase.
            clearClaim()
            proAccountID = nil
            deviceEntitlementRefusedFor = uid
            updatePro()
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
        guard let jws = await entitlements.currentEntitlementJWS() else { return }
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

    /// Sets isPro from its two sources: the signed-in account's Pro on the
    /// server, or this device's own purchase.
    private func updatePro() {
        setPro(accountHasPro || deviceEntitlementCounts)
    }

    private var accountHasPro: Bool {
        currentUserID != nil && proAccountID == currentUserID
    }

    /// Whether this device's StoreKit entitlement unlocks Pro for whoever is
    /// using the app.
    private var deviceEntitlementCounts: Bool {
        guard deviceHasEntitlement else { return false }
        // Signed out: the device's own purchase.
        guard let uid = currentUserID else { return true }
        // The server said no for this account.
        if deviceEntitlementRefusedFor == uid { return false }
        // Claim lock: a purchase another account claimed on this device stays theirs.
        let claimedBy = claimedByUserID()
        return claimedBy == nil || claimedBy == uid
    }

    private func setPro(_ value: Bool) {
        isPro = value
        defaults.set(value, forKey: Self.isProKey)
    }
}

// MARK: - This device's StoreKit

/// This device's view of the Pro purchase in StoreKit. Tests swap in a fake.
protocol ProEntitlementChecking: Sendable {
    /// The signed transaction behind this device's Pro entitlement, if any.
    func currentEntitlementJWS() async -> String?
    /// Asks the App Store for this Apple ID's transactions (Restore Purchases).
    func syncWithAppStore() async throws
}

/// StoreKit 2 on this device. Nonisolated, so the entitlement walk runs off
/// the main actor.
struct StoreKitProEntitlements: ProEntitlementChecking {
    func currentEntitlementJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == PurchaseService.productID,
               tx.revocationDate == nil {
                return result.jwsRepresentation
            }
        }
        return nil
    }

    func syncWithAppStore() async throws {
        try await AppStore.sync()
    }
}
