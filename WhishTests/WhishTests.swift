import Foundation
import Testing
@testable import Whish

struct WhishTests {
    @Test func placeholder() async throws {
        // Add tests here
    }
}

/// Deep link parsing — the routes notifications and Siri hand to the app.
/// Serialized: these share the router singleton.
@MainActor
@Suite(.serialized)
struct DeepLinkRouterTests {

    private func route(_ string: String) -> DeepLinkRouter.Action? {
        let router = DeepLinkRouter.shared
        router.pendingAction = nil
        router.handle(url: URL(string: string)!)
        return router.pendingAction
    }

    @Test func routesItemLinksToItemDetail() {
        let item = UUID()
        #expect(route("gimme://item/\(item.uuidString)") == .openItem(itemID: item, listID: nil))
    }

    @Test func carriesTheListAlongAsAFallback() {
        let item = UUID()
        let list = UUID()
        #expect(route("gimme://item/\(item.uuidString)?list=\(list.uuidString)")
                == .openItem(itemID: item, listID: list))
    }

    @Test func ignoresMalformedIdentifiers() {
        #expect(route("gimme://item/not-a-uuid") == nil)
        #expect(route("gimme://item") == nil)
    }

    @Test func stillRoutesListLinks() {
        let list = UUID()
        #expect(route("gimme://list/\(list.uuidString)") == .openList(list))
    }
}
