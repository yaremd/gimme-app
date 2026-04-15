import SwiftUI
import UIKit

extension Font {
    // SF Pro Rounded via UIFontDescriptor — supports Dynamic Type scaling
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        let uiStyle = UIFont.TextStyle(style)
        guard let descriptor = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: uiStyle)
            .withDesign(.rounded) else {
            return Font.system(style).weight(weight)
        }
        let uiFont = UIFont(descriptor: descriptor, size: 0)
        return Font(uiFont).weight(weight)
    }
}

extension UIFont.TextStyle {
    init(_ swiftUIStyle: Font.TextStyle) {
        switch swiftUIStyle {
        case .largeTitle:   self = .largeTitle
        case .title:        self = .title1
        case .title2:       self = .title2
        case .title3:       self = .title3
        case .headline:     self = .headline
        case .subheadline:  self = .subheadline
        case .body:         self = .body
        case .callout:      self = .callout
        case .footnote:     self = .footnote
        case .caption:      self = .caption1
        case .caption2:     self = .caption2
        default:            self = .body
        }
    }
}

// MARK: - Convenience text style modifiers
extension View {
    func whishLargeTitle() -> some View {
        self.font(.rounded(.largeTitle, weight: .bold))
    }

    func whishTitle() -> some View {
        self.font(.rounded(.title2, weight: .semibold))
    }

    func whishHeadline() -> some View {
        self.font(.rounded(.headline, weight: .semibold))
    }

    func whishBody() -> some View {
        self.font(.system(.body))
    }

    func whishCaption() -> some View {
        self.font(.system(.caption))
            .foregroundStyle(.secondary)
    }
}
