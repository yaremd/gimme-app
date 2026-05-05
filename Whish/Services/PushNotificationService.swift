import Foundation
import UIKit
import UserNotifications

/// Manages APNs device token registration and storage in Supabase.
/// Works alongside the existing `NotificationService` (which handles local reminders).
@MainActor
final class PushNotificationService {

    static let shared = PushNotificationService()
    private init() {}

    // MARK: - Registration

    /// Request notification permission and register for remote notifications.
    func registerForPush() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Token management

    /// Convert raw APNs token to hex string and upsert into Supabase `device_tokens` table.
    func uploadToken(_ deviceToken: Data, userID: String) async {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        do {
            try await supabase
                .from("device_tokens")
                .upsert(
                    DeviceTokenRow(userID: userID, token: token),
                    onConflict: "user_id,token"
                )
                .execute()
        } catch {
            #if DEBUG
            print("[Push] Failed to upload device token: \(error)")
            #endif
        }
    }

    /// Remove all tokens for this user from Supabase (called on sign-out).
    func removeTokens(userID: String) async {
        do {
            try await supabase
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userID)
                .execute()
        } catch {
            #if DEBUG
            print("[Push] Failed to remove device tokens: \(error)")
            #endif
        }
    }
}

// MARK: - Codable row for upsert

private struct DeviceTokenRow: Encodable {
    let userID: String
    let token: String
    let platform = "ios"
    let updatedAt = Date()

    enum CodingKeys: String, CodingKey {
        case userID    = "user_id"
        case token
        case platform
        case updatedAt = "updated_at"
    }
}
