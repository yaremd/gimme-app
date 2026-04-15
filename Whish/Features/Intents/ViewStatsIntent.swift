import AppIntents

struct ViewStatsIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "View Wishlist Stats"
    nonisolated(unsafe) static var description: IntentDescription = "Shows your wishlist statistics in Gimme."
    nonisolated(unsafe) static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkRouter.shared.pendingAction = .openStats
        return .result()
    }
}
