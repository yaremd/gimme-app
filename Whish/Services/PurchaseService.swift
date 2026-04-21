import Foundation
import StoreKit

/// Observable StoreKit 2 purchase manager. Inject via @Environment throughout the app.
@Observable
@MainActor
final class PurchaseService {

    // MARK: - Public state

    private(set) var isPro: Bool = UserDefaults.standard.bool(forKey: "isPro")
    private(set) var product: Product?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// Set by WhishApp on sign-in/out so purchase() and handle() can sync to Supabase
    /// without needing a coordinator observer.
    var currentUserID: String?

    // MARK: - Constants

    nonisolated static let productID = "com.yaremchuk.app.pro.lifetime"

    // MARK: - Init

    init() {
        // Task inherits @MainActor from init — no actor-isolation issues.
        // bootstrap() runs forever (Transaction.updates is infinite), which is
        // intentional: the service lives for the app's lifetime.
        Task { await bootstrap() }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product else {
            errorMessage = "Product unavailable. Check your connection and try again."
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
                setPro(true)
                if let uid = currentUserID {
                    claimPro(for: uid)
                    await syncProToSupabase(userID: uid, value: true)
                }
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
            await verifyEntitlement()
            if isPro, let uid = currentUserID {
                claimPro(for: uid)
                await syncProToSupabase(userID: uid, value: true)
            }
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
            product = products.first
        } catch {
            // Non-fatal — price label falls back to "$4.99" in PaywallView.
        }
    }

    func verifyEntitlement() async {
        let found = await Self.checkEntitlementExists()
        setPro(found)
    }

    /// Iterates StoreKit entitlements off @MainActor to avoid blocking UI.
    private nonisolated static func checkEntitlementExists() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == productID,
               tx.revocationDate == nil {
                return true
            }
        }
        return false
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let tx) = result else { return }
        await tx.finish()
        if tx.productID == Self.productID {
            let newValue = tx.revocationDate == nil
            if !newValue {
                clearClaim()
                if let uid = currentUserID {
                    await syncProToSupabase(userID: uid, value: false)
                }
            }
            setPro(newValue)
        }
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
        UserDefaults.standard.set(userID, forKey: Self.claimKey)
    }

    /// Returns the Supabase user ID that has claimed the local StoreKit entitlement,
    /// or nil if the purchase was made anonymously and not yet claimed.
    func claimedByUserID() -> String? {
        UserDefaults.standard.string(forKey: Self.claimKey)
    }

    private func clearClaim() {
        UserDefaults.standard.removeObject(forKey: Self.claimKey)
    }

    // MARK: - Supabase Pro sync

    /// Upserts the user's Pro status to the `profiles` table.
    /// Called after purchase, restore, or refund while the user is signed in.
    func syncProToSupabase(userID: String, value: Bool) async {
        struct ProfileRow: Encodable {
            let id: String
            // swiftlint:disable:next identifier_name
            let is_pro: Bool
            let updated_at: Date
        }
        try? await supabase
            .from("profiles")
            .upsert(ProfileRow(id: userID, is_pro: value, updated_at: .now), onConflict: "id")
            .execute()
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
        UserDefaults.standard.set(value, forKey: "isPro")
    }
}
