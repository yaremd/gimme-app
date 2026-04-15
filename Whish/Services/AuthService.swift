import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

/// Observable auth state manager. Inject via @Environment throughout the app.
@Observable
@MainActor
final class AuthService {

    // MARK: - State

    private(set) var session: Session?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private var justCreatedAccount = false
    private var pendingNonce: String?

    var isSignedIn: Bool   { session != nil }
    var userEmail: String? { session?.user.email }
    var userID: String?    { session?.user.id.uuidString }

    // MARK: - Init

    init() {
        Task { await bootstrap() }
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        // Restore persisted session
        session = try? await supabase.auth.session

        // Stream auth state changes for real-time UI updates
        for await (event, newSession) in await supabase.auth.authStateChanges {
            switch event {
            case .signedIn, .tokenRefreshed, .userUpdated:
                session = newSession
            case .signedOut, .passwordRecovery:
                session = nil
            default:
                break
            }
        }
    }

    // MARK: - Actions

    func signIn(email: String, password: String) async {
        await run {
            session = try await supabase.auth.signIn(email: email, password: password)
        }
    }

    func signUp(email: String, password: String) async {
        await run {
            let response = try await supabase.auth.signUp(email: email, password: password)
            justCreatedAccount = true
            session = response.session
        }
    }

    /// Returns true (and resets the flag) if the last auth action was a sign-up.
    func consumeNewAccountFlag() -> Bool {
        let was = justCreatedAccount
        justCreatedAccount = false
        return was
    }

    func signOut() async {
        // Remove push tokens before clearing session
        if let uid = userID {
            await PushNotificationService.shared.removeTokens(userID: uid)
        }
        await run { try await supabase.auth.signOut() }
        session = nil
    }

    // Called synchronously from SignInWithAppleButton's onRequest closure
    func prepareAppleNonce() -> String {
        let nonce = randomNonceString()
        pendingNonce = nonce
        return sha256(nonce)
    }

    // Called from SignInWithAppleButton's onCompletion closure
    func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        await run {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = pendingNonce else {
                throw NSError(domain: "AppleSignIn", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid Apple credential."])
            }
            pendingNonce = nil
            try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
        }
    }

    func resetPassword(email: String) async {
        await run {
            try await supabase.auth.resetPasswordForEmail(email)
        }
    }

    /// Permanently deletes the account from Supabase and clears all local SwiftData.
    func deleteAccount(clearData: () throws -> Void) async {
        await run {
            try await supabase.functions.invoke("delete-account", options: .init())
            try clearData()
            session = nil
        }
    }

    // MARK: - Helpers

    private func run(_ body: () async throws -> Void) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await body()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() { errorMessage = nil }

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return randomBytes.map { String(format: "%02hhx", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let data = SHA256.hash(data: Data(input.utf8))
        return data.compactMap { String(format: "%02x", $0) }.joined()
    }
}
