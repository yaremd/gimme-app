import AppIntents

struct GimmeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenListIntent(),
            phrases: [
                "Open wishlist in \(.applicationName)",
                "Open \(.applicationName)",
            ],
            shortTitle: "Open Wishlist",
            systemImageName: "list.bullet.rectangle"
        )

        AppShortcut(
            intent: AddItemIntent(),
            phrases: [
                "Add wish in \(.applicationName)",
                "New wish in \(.applicationName)",
                "Save wish in \(.applicationName)",
            ],
            shortTitle: "Add Wish",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: QuickAddIntent(),
            phrases: [
                "Quick add in \(.applicationName)",
            ],
            shortTitle: "Quick Add",
            systemImageName: "bolt.circle"
        )

        AppShortcut(
            intent: HowMuchLeftIntent(),
            phrases: [
                "Wishlist total in \(.applicationName)",
                "How much on my \(.applicationName) wishlist",
            ],
            shortTitle: "Wishlist Value",
            systemImageName: "dollarsign.circle"
        )

        AppShortcut(
            intent: ViewStatsIntent(),
            phrases: [
                "Show stats in \(.applicationName)",
                "Wishlist stats in \(.applicationName)",
            ],
            shortTitle: "View Stats",
            systemImageName: "chart.pie"
        )
    }
}
