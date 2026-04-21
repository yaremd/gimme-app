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
            setPro(tx.revocationDate == nil)
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
