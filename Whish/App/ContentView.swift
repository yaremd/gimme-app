import SwiftUI
import CoreSpotlight

struct ContentView: View {
    @AppStorage("colorScheme") private var colorSchemePreference = "system"
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete = false

    @Environment(AuthService.self) private var authService

    @State private var sharedListToken: String?
    @State private var isShowingSharedList = false

    private var router: DeepLinkRouter { DeepLinkRouter.shared }

    var body: some View {
        HomeView()
            .environment(router)
            .preferredColorScheme(colorSchemeValue)
            .sheet(isPresented: Binding(
                get: { !isOnboardingComplete },
                set: { if !$0 { isOnboardingComplete = true } }
            )) {
                OnboardingView()
                    .preferredColorScheme(colorSchemeValue)
                    .pageSheet()
            }
            .onOpenURL { url in
                // Password recovery: gimme://reset-password#access_token=...
                if url.scheme == "gimme", url.host == "reset-password" {
                    Task { await authService.handleDeepLink(url) }
                    return
                }
                // Share links
                if let token = extractShareToken(from: url) {
                    sharedListToken = token
                    isShowingSharedList = true
                    return
                }
                // Deep links: gimme://list/<id>, gimme://stats
                router.handle(url: url)
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                      let url = URL(string: id) else { return }
                router.handle(url: url)
            }
            .sheet(isPresented: $isShowingSharedList) {
                if let token = sharedListToken {
                    SharedListView(shareToken: token)
                        .pageSheet()
                }
            }
    }

    // MARK: - URL parsing

    /// Handles both Universal Links and the custom scheme:
    /// - https://gimmelist.com/share/<token>
    /// - gimme://share/<token>
    private func extractShareToken(from url: URL) -> String? {
        // Universal Link
        if url.scheme == "https",
           url.host == "gimmelist.com" {
            let parts = url.pathComponents               // ["", "share", "<token>"]
            if parts.count == 3, parts[1] == "share" {
                return parts[2]
            }
        }
        // Custom URL scheme: gimme://share/<token>
        if url.scheme == "gimme",
           url.host == "share",
           !url.path.isEmpty {
            return url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return nil
    }

    private var colorSchemeValue: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
