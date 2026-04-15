import SwiftUI

enum Theme {

    // MARK: - Colors
    enum Colors {
        // Accent
        static let accent      = Color(hex: "#6C63FF")
        static let purchased   = Color(hex: "#30D158")
        static let destructive = Color(hex: "#FF453A")

        // Adaptive surface palette
        //
        // Dark:  #17162C (top) → #0C0C11 (bottom) → tertiary (surface)
        // Light: #F5F0E8 (warm cream top) → #EDE6D8 (warm cream bottom) → #FFFBF0 (cards)

        static let background = Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? .systemGroupedBackground
                : UIColor(red: 0.949, green: 0.937, blue: 0.910, alpha: 1) // #F2EFE8
        })

        static let backgroundTop = Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.090, green: 0.086, blue: 0.110, alpha: 1) // #17162C
                : UIColor(red: 0.961, green: 0.941, blue: 0.910, alpha: 1) // #F5F0E8
        })
        static let backgroundBottom = Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 0.047, green: 0.047, blue: 0.067, alpha: 1) // #0C0C11
                : UIColor(red: 0.929, green: 0.902, blue: 0.847, alpha: 1) // #EDE6D8
        })
        static let surface = Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? .secondarySystemGroupedBackground
                : UIColor(red: 1.000, green: 0.992, blue: 0.965, alpha: 1) // #FFFDF6
        })
        static let surfaceElevated = Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? .tertiarySystemGroupedBackground
                : UIColor(red: 1.000, green: 0.984, blue: 0.941, alpha: 1) // #FFFBF0
        })
        static let surfaceBorder = Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor.separator.withAlphaComponent(0.35)
                : UIColor.separator
        })

        // Adaptive text
        static let textPrimary = Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? .label
                : UIColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1) // #2C2C2E
        })
        static let textSecondary = Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? .secondaryLabel
                : UIColor(red: 0.380, green: 0.370, blue: 0.390, alpha: 1) // #616163 — stronger than system
        })
        static let textTertiary = Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? .tertiaryLabel
                : UIColor(red: 0.510, green: 0.500, blue: 0.520, alpha: 1) // #828085 — visible on cream
        })

        // Preset card swatches — vibrant, accessible on both warm cream and dark backgrounds
        // Each has ≥ 3:1 contrast ratio against #FFFBF0 (light) and dark surface
        static let presets: [(hex: String, name: String)] = [
            ("#E8586D", "Rose"),       // rich rose red
            ("#E07B3C", "Tangerine"),  // warm orange
            ("#D4A017", "Honey"),      // deep golden
            ("#2EAA5F", "Emerald"),    // rich green
            ("#3B8DD4", "Ocean"),      // vivid blue
            ("#8B5CF6", "Violet"),     // medium purple
            ("#D946A8", "Fuchsia"),    // hot pink
            ("#1DA0A0", "Teal"),       // deep teal
            ("#6C63FF", "Indigo"),     // app accent
            ("#E04545", "Coral"),      // warm red
        ]
    }

    // MARK: - Corner Radii
    enum Radius {
        static let card: CGFloat   = 20
        static let sheet: CGFloat  = 28
        static let button: CGFloat = 14
        static let badge: CGFloat  = 8
        static let image: CGFloat  = 12
        static let icon: CGFloat   = 14
    }

    // MARK: - Spacing
    enum Spacing {
        static let gridPadding: CGFloat = 16
        static let cardInner: CGFloat   = 16
        static let cardGap: CGFloat     = 10
        static let sectionGap: CGFloat  = 24
        static let xs: CGFloat =  4
        static let sm: CGFloat =  8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: - Animation
    static let spring      = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let quickSpring = Animation.spring(response: 0.25, dampingFraction: 0.8)

    // MARK: - Background gradient
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Colors.backgroundTop, Colors.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Shadows
    enum Shadow {
        static let cardRadius: CGFloat  = 12
        static let cardY: CGFloat       =  4
        static let cardOpacity: Double  = 0.08
    }
}
