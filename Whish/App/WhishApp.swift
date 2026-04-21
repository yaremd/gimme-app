import AppIntents
import SwiftUI
import SwiftData
import UIKit
import UserNotifications

// MARK: - AppDelegate (push notification token handling)

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Temporarily holds the APNs token until auth is ready to upload it.
    var deviceToken: Data?
    /// Set by WhishApp once auth is bootstrapped.
    var currentUserID: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        self.deviceToken = deviceToken
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
}

// MARK: - UNUserNotificationCenterDelegate
// Separated so the system can call these from a non-isolated context (Swift 6 requirement).

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Show banner + sound even when the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Navigate to the relevant list when the user taps the notification.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let userInfo = response.notification.request.content.userInfo
        guard let listIDString = userInfo["list_id"] as? String,
              let listID = UUID(uuidString: listIDString) else { return }
        Task { @MainActor in
            DeepLinkRouter.shared.pendingAction = .openList(listID)
        }
    }
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
                .overlay {
                    if authService.isPasswordRecovery || authService.isPendingPasswordReset {
                        ResetPasswordView()
                            .environment(authService)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(Theme.quickSpring, value: authService.isPasswordRecovery || authService.isPendingPasswordReset)
                .task {
                    let sp = Perf.begin("cold-launch-task")

                    // Haptics must stay on MainActor — fast, fine here.
                    Haptics.prepare()

                    // Everything else deferred to background so the first frame renders immediately.
                    Task.detached(priority: .utility) {
                        await CurrencyRateService.refreshIfNeeded()
                    }
                    Task.detached(priority: .background) {
                        await MainActor.run { GimmeShortcuts.updateAppShortcutParameters() }
                    }
                    Task.detached(priority: .utility) { [appDelegate] in
                        await PushNotificationService.shared.registerForPush()
                        // Sync device token if already signed in.
                        let userID = await MainActor.run { authService.userID }
                        if let userID {
                            await MainActor.run { appDelegate.currentUserID = userID }
                            let token = await MainActor.run { appDelegate.deviceToken }
                            if let token {
                                await PushNotificationService.shared.uploadToken(token, userID: userID)
                            }
                        }
                    }

                    Perf.end("cold-launch-task", sp)
                    // Note: UIActivityViewController prewarm removed.
                    // On iOS 17+ the share sheet is fast enough on first presentation.
                }
                .onChange(of: authService.isSignedIn) { _, isSignedIn in
                    Task {
                        if isSignedIn, let userID = authService.userID {
                            // Upload device token on sign-in
                            appDelegate.currentUserID = userID
                            if let token = appDelegate.deviceToken {
                                await PushNotificationService.shared.uploadToken(token, userID: userID)
                            }

                            // Pro is Supabase-account-level.
                            // Check both StoreKit and Supabase; whichever says Pro wins.
                            await purchaseService.refreshEntitlement()
                            let storeKitPro = purchaseService.isPro
                            let supabasePro = await purchaseService.fetchProFromSupabase(userID: userID)

                            if supabasePro && !storeKitPro {
                                // Purchased on another device or Apple ID — Supabase is the record
                                purchaseService.grantPro()
                            }
                            if storeKitPro && !supabasePro {
                                let claimedBy = purchaseService.claimedByUserID()
                                if claimedBy == nil || claimedBy == userID {
                                    // Unclaimed anonymous purchase, or same user on a new device → claim + sync
                                    purchaseService.claimPro(for: userID)
                                    await purchaseService.syncProToSupabase(userID: userID, value: true)
                                }
                                // else: claimed by a different account on this device → stay free
                            }
                        } else {
                            // Clean up on sign-out — Pro resets so Account B starts free
                            appDelegate.currentUserID = nil
                            purchaseService.resetProStatus()
                        }
                    }
                }
                .onChange(of: purchaseService.isPro) { _, isPro in
                    guard let userID = authService.userID else { return }
                    if isPro {
                        // Purchase or restore succeeded while logged in — claim + persist to Supabase
                        purchaseService.claimPro(for: userID)
                        Task { await purchaseService.syncProToSupabase(userID: userID, value: true) }
                    } else if purchaseService.lastChangeWasRevocation {
                        // Refund/revocation — sync the revocation to Supabase
                        Task { await purchaseService.syncProToSupabase(userID: userID, value: false) }
                    }
                    // If !isPro && !lastChangeWasRevocation → logout reset → don't touch Supabase
                }
        }
        .modelContainer(container)
    }
}
