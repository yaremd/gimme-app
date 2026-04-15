import Foundation
import SwiftUI

/// Bridges deep link URLs (parsed in ContentView) and AppIntents to navigation state (consumed in HomeView).
@Observable
@MainActor
final class DeepLinkRouter {

    static let shared = DeepLinkRouter()

    enum Action: Equatable {
        case openList(UUID)
        case openStats
        case addItem(title: String, listID: UUID?)  // nil = ask user which list
        case showAddForm(listID: UUID?)              // opens the add-item sheet
    }

    /// Set by ContentView/AppIntents; consumed and cleared by HomeView.
    var pendingAction: Action?

    func handle(url: URL) {
        guard url.scheme == "gimme" else { return }

        switch url.host {
        case "list":
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if let id = UUID(uuidString: path) {
                pendingAction = .openList(id)
            }
        case "stats":
            pendingAction = .openStats
        case "add":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let listIDStr = components?.queryItems?.first(where: { $0.name == "list" })?.value
            let listID = listIDStr.flatMap { UUID(uuidString: $0) }
            pendingAction = .showAddForm(listID: listID)
        default:
            break
        }
    }
}
