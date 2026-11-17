import Foundation
import Testing
@testable import Whish

// MARK: - Reading verify-purchase responses

struct ProVerificationResponseTests {

    private func result(_ status: Int, _ body: String) -> ProVerificationResult {
        ProVerificationResult(statusCode: status, body: Data(body.utf8))
    }

    @Test func aVerifiedPurchaseMeansPro() {
        #expect(result(200, #"{"isPro":true,"status":"active"}"#) == .verified(isPro: true))
    }

    @Test func aRefundMeansFree() {
        #expect(result(200, #"{"isPro":false,"status":"revoked"}"#) == .verified(isPro: false))
    }

    @Test func theAccountsProWinsOverTheTransactionsStatus() {
        // One purchase refunded, another still standing.
        #expect(result(200, #"{"isPro":true,"status":"revoked"}"#) == .verified(isPro: true))
    }

    @Test func aPurchaseOwnedByAnotherAccount() {
        let body = #"{"code":"claimed_by_other_account","error":"…","isPro":false}"#
        #expect(result(409, body) == .claimedByOtherAccount)
    }

    @Test func refusalsCarryTheServersCode() {
        #expect(result(422, #"{"code":"invalid_signature","error":"…"}"#) == .rejected(code: "invalid_signature"))
        #expect(result(422, #"{"code":"wrong_environment","error":"…"}"#) == .rejected(code: "wrong_environment"))
        #expect(result(400, #"{"code":"bad_request","error":"…"}"#) == .rejected(code: "bad_request"))
        #expect(result(422, "") == .rejected(code: "rejected"))
    }

    @Test func anythingElseIsUnknown() {
        #expect(result(401, #"{"code":"unauthorized","error":"…"}"#) == .unavailable)
        #expect(result(500, #"{"code":"server_error","error":"…"}"#) == .unavailable)
        #expect(result(503, "<html>gateway</html>") == .unavailable)
        #expect(result(409, #"{"code":"something_else"}"#) == .unavailable)
        #expect(result(200, "not json") == .unavailable)
        #expect(result(200, #"{"status":"active"}"#) == .unavailable)
    }

    @Test func onlyAServerNoKeepsTheAccountFree() {
        #expect(ProVerificationResult.verified(isPro: false).keepsAccountFree)
        #expect(ProVerificationResult.claimedByOtherAccount.keepsAccountFree)
        #expect(!ProVerificationResult.verified(isPro: true).keepsAccountFree)
        #expect(!ProVerificationResult.rejected(code: "invalid_signature").keepsAccountFree)
        #expect(!ProVerificationResult.unavailable.keepsAccountFree)
    }

    @Test func theRequestCarriesTheJWS() throws {
        let data = try JSONEncoder().encode(VerifyPurchaseRequest(jws: "header.payload.signature"))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(object == ["jws": "header.payload.signature"])
    }
}

// MARK: - Applying the server's answer

/// Records what PurchaseService sent and answers with a canned result.
private final class FakeVerifier: ProPurchaseVerifying, @unchecked Sendable {
    private let lock = NSLock()
    private var sent: [String] = []
    private let outcome: ProVerificationResult
    private let whileVerifying: (@MainActor @Sendable () -> Void)?

    init(_ outcome: ProVerificationResult, whileVerifying: (@MainActor @Sendable () -> Void)? = nil) {
        self.outcome = outcome
        self.whileVerifying = whileVerifying
    }

    var received: [String] { lock.withLock { sent } }

    func verify(jws: String) async -> ProVerificationResult {
        lock.withLock { sent.append(jws) }
        if let whileVerifying { await whileVerifying() }
        return outcome
    }
}

@MainActor
struct PurchaseServiceSyncTests {

    private static let user = "user-1"
    private static let jws = "header.payload.signature"

    /// A PurchaseService on a throwaway defaults suite, never touching StoreKit.
    private func withService(
        _ verifier: FakeVerifier,
        startingPro: Bool = false,
        claimedBy: String? = nil,
        signedInAs: String? = user,
        _ body: @MainActor (PurchaseService, UserDefaults) async throws -> Void
    ) async rethrows {
        let suiteName = "PurchaseServiceSyncTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        defaults.set(startingPro, forKey: "isPro")
        if let claimedBy { defaults.set(claimedBy, forKey: "proClaimedByUserID") }

        let service = PurchaseService(defaults: defaults, verifier: verifier, observesStoreKit: false)
        service.currentUserID = signedInAs
        try await body(service, defaults)
    }

    @Test func aVerifiedPurchaseUnlocksProAndClaimsTheDevice() async {
        let verifier = FakeVerifier(.verified(isPro: true))
        await withService(verifier) { service, defaults in
            let outcome = await service.syncProToSupabase(jws: Self.jws)

            #expect(outcome == .verified(isPro: true))
            #expect(verifier.received == [Self.jws])
            #expect(service.isPro)
            #expect(defaults.bool(forKey: "isPro"))
            #expect(service.claimedByUserID() == Self.user)
        }
    }

    @Test func aRefundTakesProAway() async {
        let verifier = FakeVerifier(.verified(isPro: false))
        await withService(verifier, startingPro: true, claimedBy: Self.user) { service, defaults in
            #expect(service.isPro)
            await service.syncProToSupabase(jws: Self.jws)

            #expect(!service.isPro)
            #expect(!defaults.bool(forKey: "isPro"))
            #expect(service.claimedByUserID() == nil)
        }
    }

    @Test func anotherAccountsPurchaseLeavesThisOneFree() async {
        let verifier = FakeVerifier(.claimedByOtherAccount)
        await withService(verifier, startingPro: true, claimedBy: Self.user) { service, _ in
            let outcome = await service.syncProToSupabase(jws: Self.jws)

            #expect(outcome == .claimedByOtherAccount)
            #expect(!service.isPro)
            #expect(service.claimedByUserID() == nil)
        }
    }

    @Test func serverTroubleKeepsWhatTheDeviceHas() async {
        let verifier = FakeVerifier(.unavailable)
        await withService(verifier, startingPro: true, claimedBy: Self.user) { service, _ in
            await service.syncProToSupabase(jws: Self.jws)

            #expect(service.isPro)
            #expect(service.claimedByUserID() == Self.user)
        }
    }

    @Test func aRefusedTransactionKeepsWhatTheDeviceHas() async {
        // e.g. a sandbox purchase sent to the production backend.
        let verifier = FakeVerifier(.rejected(code: "wrong_environment"))
        await withService(verifier, startingPro: true, claimedBy: Self.user) { service, _ in
            await service.syncProToSupabase(jws: Self.jws)

            #expect(service.isPro)
            #expect(service.claimedByUserID() == Self.user)
        }
    }

    @Test func signedOutNeverCallsTheServer() async {
        let verifier = FakeVerifier(.verified(isPro: true))
        await withService(verifier, signedInAs: nil) { service, _ in
            let outcome = await service.syncProToSupabase(jws: Self.jws)

            #expect(outcome == .unavailable)
            #expect(verifier.received.isEmpty)
            #expect(!service.isPro)
        }
    }

    @Test func ignoresAnAnswerThatArrivesAfterSignOut() async {
        final class Box: @unchecked Sendable { var service: PurchaseService? }
        let box = Box()
        let verifier = FakeVerifier(.verified(isPro: true)) { box.service?.currentUserID = nil }
        await withService(verifier) { service, _ in
            box.service = service
            let outcome = await service.syncProToSupabase(jws: Self.jws)

            #expect(outcome == .unavailable)
            #expect(!service.isPro)
            #expect(service.claimedByUserID() == nil)
        }
    }

    @Test func readsTheProFlagFromItsOwnDefaults() async {
        await withService(FakeVerifier(.unavailable), startingPro: true) { service, _ in
            #expect(service.isPro)
        }
        await withService(FakeVerifier(.unavailable), startingPro: false) { service, _ in
            #expect(!service.isPro)
        }
    }
}
