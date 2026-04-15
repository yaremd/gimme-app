import SwiftUI

// MARK: - Contrast color cache (avoids 40-iteration HSB loop per card per render)
private nonisolated(unsafe) let _contrastColorCache = NSCache<NSString, UIColor>()

// MARK: - Color + Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    /// Darkens (and slightly boosts saturation) until the color meets `targetRatio` contrast
    /// against `background`. Returns self unchanged if already sufficient.
    func withContrast(atLeast targetRatio: CGFloat, against background: Color = .white) -> Color {
        let selfUI = UIColor(self)
        let bgUI   = UIColor(background)

        // Fast cache lookup — same (color, ratio, background) always produces the same result.
        var sr: CGFloat = 0, sg: CGFloat = 0, sb: CGFloat = 0
        selfUI.getRed(&sr, green: &sg, blue: &sb, alpha: nil)
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0
        bgUI.getRed(&br, green: &bg, blue: &bb, alpha: nil)
        let cacheKey = "\(Int(sr*255)),\(Int(sg*255)),\(Int(sb*255))-\(targetRatio)-\(Int(br*255)),\(Int(bg*255)),\(Int(bb*255))" as NSString
        if let cached = _contrastColorCache.object(forKey: cacheKey) {
            return Color(cached)
        }

        func luminance(of uiColor: UIColor) -> CGFloat {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            func lin(_ c: CGFloat) -> CGFloat {
                c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        }
        func contrastRatio(_ a: UIColor, _ b: UIColor) -> CGFloat {
            let la = luminance(of: a), lb = luminance(of: b)
            let lighter = max(la, lb), darker = min(la, lb)
            return (lighter + 0.05) / (darker + 0.05)
        }

        guard contrastRatio(selfUI, bgUI) < targetRatio else {
            _contrastColorCache.setObject(selfUI, forKey: cacheKey)
            return self
        }

        var h: CGFloat = 0, s: CGFloat = 0, bri: CGFloat = 0, a: CGFloat = 0
        selfUI.getHue(&h, saturation: &s, brightness: &bri, alpha: &a)
        let sBoosted = min(s * 1.15, 1.0)
        var step = bri
        for _ in 0..<40 {
            step = max(step - 0.03, 0)
            let candidate = UIColor(hue: h, saturation: sBoosted, brightness: step, alpha: 1)
            if contrastRatio(candidate, bgUI) >= targetRatio {
                _contrastColorCache.setObject(candidate, forKey: cacheKey)
                return Color(hue: Double(h), saturation: Double(sBoosted), brightness: Double(step))
            }
        }
        let fallback = UIColor(hue: h, saturation: sBoosted, brightness: 0, alpha: 1)
        _contrastColorCache.setObject(fallback, forKey: cacheKey)
        return Color(hue: Double(h), saturation: Double(sBoosted), brightness: 0)
    }

    // Returns a contrasting label color (black or white) meeting WCAG AA (4.5:1).
    var contrastingLabel: Color {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        // Linearise sRGB → relative luminance (WCAG 2.x)
        func lin(_ c: CGFloat) -> CGFloat {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let L = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        // Crossover where both black and white hit 4.5:1; use black above, white below.
        return L > 0.179 ? Color.black.opacity(0.85) : .white
    }
}

// MARK: - FX Rates
/// 1 USD = X units of currency. Built-in fallback used until a live fetch succeeds.
private let fxRatesFallback: [String: Double] = [
    "USD": 1.0,
    "EUR": 0.92,
    "GBP": 0.79,
    "JPY": 149.5,
    "CAD": 1.36,
    "AUD": 1.53,
    "CHF": 0.88,
    "CNY": 7.24,
    "UAH": 38.5,
]

/// Current FX rates: live rates cached in UserDefaults, or built-in fallback.
var fxRates: [String: Double] {
    guard
        let data = UserDefaults.standard.data(forKey: "cachedFxRates"),
        let decoded = try? JSONDecoder().decode([String: Double].self, from: data),
        !decoded.isEmpty
    else { return fxRatesFallback }
    return decoded
}

/// Convert an amount from one currency to another using current FX rates.
func convertCurrency(_ amount: Decimal, from: String, to: String) -> Decimal {
    guard from != to else { return amount }
    let fromRate = Decimal(fxRates[from] ?? 1.0)
    let toRate   = Decimal(fxRates[to]   ?? 1.0)
    guard fromRate != 0 else { return amount }
    return amount * toRate / fromRate
}

// MARK: - Decimal Formatting
extension Decimal {
    func formatted(currency: String?) -> String {
        let code = currency ?? "USD"
        let rounding   = UserDefaults.standard.bool(forKey: "roundingEnabled")
        let abbreviate = UserDefaults.standard.bool(forKey: "abbreviateNumbers")
        let doubleVal  = NSDecimalNumber(decimal: self).doubleValue

        // Abbreviate large numbers: $74.5k / $1.2M
        if abbreviate && abs(doubleVal) >= 1_000 {
            let (divisor, suffix): (Double, String) = abs(doubleVal) >= 1_000_000
                ? (1_000_000, "M") : (1_000, "k")
            let short = doubleVal / divisor

            // Derive the currency symbol via NumberFormatter
            let symFmt = NumberFormatter()
            symFmt.numberStyle = .currency
            symFmt.currencyCode = code
            if code == "USD" { symFmt.currencySymbol = "$" }
            let symbol = symFmt.currencySymbol ?? code

            let numFmt = NumberFormatter()
            numFmt.numberStyle = .decimal
            numFmt.maximumFractionDigits = rounding ? 0 : 1
            numFmt.minimumFractionDigits = 0
            let numStr = numFmt.string(from: NSNumber(value: short))
                ?? String(format: rounding ? "%.0f" : "%.1f", short)
            return "\(symbol)\(numStr)\(suffix)"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = rounding ? 0 : 2
        formatter.minimumFractionDigits = rounding ? 0 : 2
        // Force the short symbol for known codes to avoid "US$" etc.
        if code == "USD" { formatter.currencySymbol = "$" }
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }
}

// MARK: - View + Conditional modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - String URL validation
extension String {
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        let scheme = url.scheme ?? ""
        return (scheme == "http" || scheme == "https") && !(url.host ?? "").isEmpty
    }

    /// Returns a URLSession-safe URL from the string, re-encoding any characters that
    /// pass URL(string:) but are rejected by URLSession (spaces, pipes, brackets, etc.).
    var sanitizedURL: URL? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        // Fast path — already a valid, encodable URL
        if let url = URL(string: trimmed),
           (url.scheme == "http" || url.scheme == "https"),
           let host = url.host, !host.isEmpty {
            return url
        }
        // Re-encode via URLComponents, which percent-encodes path/query without touching scheme/host
        guard var comps = URLComponents(string: trimmed) else { return nil }
        let allowedPath  = CharacterSet.urlPathAllowed
        let allowedQuery = CharacterSet.urlQueryAllowed
        comps.percentEncodedPath = comps.path
            .addingPercentEncoding(withAllowedCharacters: allowedPath) ?? comps.percentEncodedPath
        if let q = comps.query {
            comps.percentEncodedQuery = q
                .addingPercentEncoding(withAllowedCharacters: allowedQuery) ?? comps.percentEncodedQuery
        }
        guard let url = comps.url,
              let scheme = url.scheme, (scheme == "http" || scheme == "https"),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    /// Extracts the first http/https URL from a string that may contain
    /// surrounding text (product titles, prices, descriptions, etc.).
    var extractedURL: URL? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        // Fast path — entire string is already a clean URL
        if let direct = trimmed.sanitizedURL { return direct }
        // Use NSDataDetector to find the first link in mixed text
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return nil }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = detector.firstMatch(in: trimmed, options: [], range: range),
              let url = match.url,
              let scheme = url.scheme, scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

// MARK: - Share text generators
extension WishList {
    static let webBaseURL = "https://gimmelist.com/share/"

    var shareURL: URL? {
        guard let shareToken else { return nil }
        return URL(string: Self.webBaseURL + shareToken)
    }

    var shareText: String {
        var lines: [String] = []
        lines.append("\(emoji) \(name)")
        lines.append("")
        let sorted = items.sorted { $0.createdAt < $1.createdAt }
        for item in sorted {
            var row = "• \(item.title)"
            if let price = item.price, let currency = item.currency {
                row += " — \(price.formatted(currency: currency))"
            }
            if item.isPurchased { row += " ✓" }
            lines.append(row)
        }
        lines.append("")
        lines.append("\(items.count) item\(items.count == 1 ? "" : "s") · Shared from Gimme ✨")
        if let shareURL {
            lines.append(shareURL.absoluteString)
        }
        return lines.joined(separator: "\n")
    }

    /// Generates a fresh share token (invalidating any previous link), marks the list
    /// as shared, and returns the new web URL.
    @discardableResult
    func ensureShareToken() -> URL {
        shareToken = UUID().uuidString
        isShared = true
        updatedAt = .now
        return shareURL!
    }

    /// Revokes sharing: clears the token so old links stop working.
    func revokeShare() {
        isShared = false
        shareToken = nil
        updatedAt = .now
    }
}

// MARK: - URL + Identifiable (for .sheet(item:))
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Share sheet (UIActivityViewController wrapper)
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Liquid Glass modifiers (iOS 26+, fallback for older)

extension View {
    /// Circle glass background — used on dismiss (X) buttons throughout the app.
    @ViewBuilder
    func glassCircleBackground() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(in: Circle())
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }

    /// Capsule glass background — used on filter/sort/action buttons.
    @ViewBuilder
    func glassCapsuleBackground() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(in: Capsule())
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
        }
    }

    /// Rounded-rect glass background — used on cards and sheets.
    @ViewBuilder
    func glassCardBackground(radius: CGFloat = Theme.Radius.card) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}

// MARK: - Primary glass button background

private struct PrimaryGlassModifier: ViewModifier {
    let color: Color
    let isEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .background {
                    if isEnabled {
                        Capsule().fill(color.opacity(colorScheme == .dark ? 0.7 : 1.0))
                    } else {
                        Capsule().fill(Theme.Colors.surfaceElevated)
                    }
                }
                .glassEffect(in: Capsule())
                .shadow(color: isEnabled ? color.opacity(colorScheme == .dark ? 0.35 : 0.45) : .clear, radius: 12, y: 4)
        } else {
            content
                .background {
                    if isEnabled {
                        if colorScheme == .dark {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(Capsule().fill(color.opacity(0.55)))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
                        } else {
                            Capsule()
                                .fill(color)
                                .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                        }
                    } else {
                        Capsule().fill(Theme.Colors.surfaceElevated)
                    }
                }
                .shadow(color: isEnabled ? color.opacity(colorScheme == .dark ? 0.3 : 0.4) : .clear, radius: 12, y: 4)
        }
    }
}

extension View {
    /// Applies the glass capsule background used on all primary action buttons.
    func primaryGlassBackground(color: Color, isEnabled: Bool = true) -> some View {
        modifier(PrimaryGlassModifier(color: color, isEnabled: isEnabled))
    }

    /// Forces classic edge-to-edge sheet style on iOS 26+ (avoids floating sheets).
    @ViewBuilder
    func pageSheet() -> some View {
        if #available(iOS 26, *) {
            self.presentationSizing(.page)
        } else {
            self
        }
    }
}
