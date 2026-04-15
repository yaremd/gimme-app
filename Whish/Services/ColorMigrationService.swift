import Foundation
import SwiftData

/// Migrates old pastel card colors to the new vibrant palette.
/// Runs once on app launch, tracked by a UserDefaults flag.
enum ColorMigrationService {

    private static let migrationKey = "hasRunColorMigrationV2"

    // Old pastel → new vibrant mapping
    private static let colorMap: [String: String] = [
        "#FFB3BA": "#E8586D",  // Rose (pastel) → Rose (vibrant)
        "#FFD9B3": "#E07B3C",  // Peach → Tangerine
        "#FFFAB3": "#D4A017",  // Lemon → Honey
        "#B3FFD1": "#2EAA5F",  // Mint → Emerald
        "#B3D9FF": "#3B8DD4",  // Sky → Ocean
        "#D4B3FF": "#8B5CF6",  // Lavender → Violet
        "#FFB3F0": "#D946A8",  // Pink → Fuchsia
        "#B3FFF0": "#1DA0A0",  // Teal → Teal (deep)
        "#FF6B6B": "#E04545",  // Coral → Coral (deep)
        // #6C63FF (Purple/Indigo) stays the same
    ]

    @MainActor
    static func migrateIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let lists = (try? context.fetch(FetchDescriptor<WishList>())) ?? []
        var changed = false

        for list in lists {
            let upper = list.colorHex.uppercased()
            if let newHex = colorMap[upper] {
                list.colorHex = newHex
                list.updatedAt = .now
                changed = true
            }
        }

        if changed { try? context.save() }
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
