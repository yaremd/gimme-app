import Foundation
import Supabase

/// What the verify-purchase Edge Function said about a StoreKit transaction.
///
/// The server checks Apple's signature on the transaction and is the only
/// writer of `profiles.is_pro`, so its answer decides account-level Pro.
enum ProVerificationResult: Equatable, Sendable {
    /// The server verified and recorded the transaction. `isPro` is the
    /// signed-in account's Pro state now (false after a refund).
    case verified(isPro: Bool)
    /// The purchase is already linked to a different Gimme account.
    case claimedByOtherAccount
    /// The server refused the transaction: bad signature, wrong product, or
    /// an environment it doesn't accept (sandbox, Xcode).
    case rejected(code: String)
    /// Nothing is known: signed out, offline, or a server error.
    case unavailable

    /// Interprets a verify-purchase response.
    init(statusCode: Int, body: Data) {
        struct Body: Decodable {
            let isPro: Bool?
            let code: String?
        }
        let decoded = try? JSONDecoder().decode(Body.self, from: body)
        switch statusCode {
        case 200..<300:
            self = decoded?.isPro.map { .verified(isPro: $0) } ?? .unavailable
        case 409 where decoded?.code == "claimed_by_other_account":
            self = .claimedByOtherAccount
        case 400, 422:
            self = .rejected(code: decoded?.code ?? "rejected")
        default:
            // 401 (expired session), 5xx, gateway errors: try again later.
            self = .unavailable
        }
    }

    /// True when the server says this account must not have Pro.
    var keepsAccountFree: Bool {
        switch self {
        case .verified(let isPro): !isPro
        case .claimedByOtherAccount: true
        case .rejected, .unavailable: false
        }
    }
}

/// Body of a verify-purchase request.
struct VerifyPurchaseRequest: Encodable, Equatable {
    /// `VerificationResult.jwsRepresentation` of the transaction.
    let jws: String
}

/// Sends a StoreKit transaction to the server for verification.
protocol ProPurchaseVerifying: Sendable {
    func verify(jws: String) async -> ProVerificationResult
}

/// Calls the verify-purchase Edge Function as the signed-in user.
struct SupabaseProPurchaseVerifier: ProPurchaseVerifying {
    func verify(jws: String) async -> ProVerificationResult {
        do {
            return try await supabase.functions.invoke(
                "verify-purchase",
                // Purchase and restore wait for this answer, so don't hang on a bad network.
                options: FunctionInvokeOptions(body: VerifyPurchaseRequest(jws: jws), timeoutInterval: 15)
            ) { data, response in
                ProVerificationResult(statusCode: response.statusCode, body: data)
            }
        } catch FunctionsError.httpError(let code, let data) {
            return ProVerificationResult(statusCode: code, body: data)
        } catch {
            return .unavailable
        }
    }
}
