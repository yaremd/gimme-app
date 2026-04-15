import SwiftUI

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
}

// Shared formatting helper
func formatCurrency(_ value: Double, code: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    if code == "USD" { formatter.currencySymbol = "$" }
    return formatter.string(from: NSNumber(value: value)) ?? "$0"
}
