import AppIntents
import SwiftUI
import SwiftData
import UIKit

// MARK: - AppDelegate (push notification token handling)

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Temporarily holds the APNs token until auth is ready to upload it.
    var deviceToken: Data?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        self.deviceToken = deviceToken
        // If the user is already signed in, upload immediately.
        Task { @MainActor in
            guard let userID = currentUserID else { return }
            await PushNotificationService.shared.uploadToken(deviceToken, userID: userID)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Push] Registration failed: \(error.localizedDescription)")
    }

    /// Set by WhishApp once auth is bootstrapped.
    @MainActor var currentUserID: String?
}

// MARK: - App

@main
struct WhishApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let container: ModelContainer
    @State private var authService = AuthService()
    @State private var syncService = SyncService()
    @State private var purchaseService = PurchaseService()

    init() {
        // Set default currency from device locale on first launch
        if UserDefaults.standard.string(forKey: "defaultCurrency") == nil {
            let localeCurrency = Locale.current.currency?.identifier ?? "USD"
            let supported = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "UAH"]
            let resolved = supported.contains(localeCurrency) ? localeCurrency : "USD"
            UserDefaults.standard.set(resolved, forKey: "defaultCurrency")
        }

        let schema = Schema([WishList.self, WishItem.self])

        func buildConfig() -> ModelConfiguration {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, allowsSave: true)
        }

        // First attempt
        if let c = try? ModelContainer(for: schema, configurations: [buildConfig()]) {
            container = c
            return
        }

        // Schema evolved — wipe all persistent store files SwiftData may have written,
        // then build a completely fresh Schema + Config to avoid "invalid reuse" errors.
        let fm = FileManager.default
        if let appSupport = fm.urls(for: .applicationSupportDirectory,
                                    in: .userDomainMask).first,
           let files = try? fm.contentsOfDirectory(at: appSupport,
                                                   includingPropertiesForKeys: nil) {
            for file in files {
                let name = file.lastPathComponent
                if name.hasSuffix(".store")
                    || name.hasSuffix(".store-wal")
                    || name.hasSuffix(".store-shm")
                    || name.hasSuffix(".sqlite")
                    || name.hasSuffix(".sqlite-wal")
                    || name.hasSuffix(".sqlite-shm") {
                    try? fm.removeItem(at: file)
                }
            }
        }

        do {
            let freshSchema = Schema([WishList.self, WishItem.self])
            let freshConfig = ModelConfiguration(schema: freshSchema, isStoredInMemoryOnly: false, allowsSave: true)
            container = try ModelContainer(for: freshSchema, configurations: [freshConfig])
        } catch {
            // Last resort: run in-memory so the app doesn't crash
            let memSchema = Schema([WishList.self, WishItem.self])
            let memConfig = ModelConfiguration(schema: memSchema, isStoredInMemoryOnly: true, allowsSave: true)
            container = try! ModelContainer(for: memSchema, configurations: [memConfig])
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
                .environment(syncService)
                .environment(purchaseService)
                .task {
                    Haptics.prepare()
                    await CurrencyRateService.refreshIfNeeded()
                    GimmeShortcuts.updateAppShortcutParameters()

                    // Register for push notifications
                    await PushNotificationService.shared.registerForPush()

                    // If already signed in, sync the device token
                    if let userID = authService.userID {
                        appDelegate.currentUserID = userID
                        if let token = appDelegate.deviceToken {
                            await PushNotificationService.shared.uploadToken(token, userID: userID)
                        }
                    }

                    // Prewarm UIActivityViewController so first share doesn't freeze.
                    // iOS caches the extension enumeration after the first init.
                    try? await Task.sleep(for: .seconds(2))
                    _ = await MainActor.run {
                        UIActivityViewController(activityItems: [""], applicationActivities: nil)
                    }
                }
                .onChange(of: authService.isSignedIn) { _, isSignedIn in
                    Task {
                        if isSignedIn, let userID = authService.userID {
                            // Upload device token on sign-in
                            appDelegate.currentUserID = userID
                            if let token = appDelegate.deviceToken {
                                await PushNotificationService.shared.uploadToken(token, userID: userID)
                            }
                        } else {
                            // Clean up on sign-out
                            appDelegate.currentUserID = nil
                        }
                    }
                }
        }
        .modelContainer(container)
    }
}
