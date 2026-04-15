import UIKit

@MainActor
enum Haptics {
    private static let lightImpact   = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact  = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact   = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionGen  = UISelectionFeedbackGenerator()
    private static let notificationGen = UINotificationFeedbackGenerator()

    static func light()     { lightImpact.impactOccurred() }
    static func medium()    { mediumImpact.impactOccurred() }
    static func heavy()     { heavyImpact.impactOccurred() }
    static func selection() { selectionGen.selectionChanged() }

    static func success()   { notificationGen.notificationOccurred(.success) }
    static func error()     { notificationGen.notificationOccurred(.error) }
    static func warning()   { notificationGen.notificationOccurred(.warning) }

    /// Call on app launch to prime the taptic engine (avoids ~50ms delay on first haptic).
    static func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionGen.prepare()
        notificationGen.prepare()
    }
}
