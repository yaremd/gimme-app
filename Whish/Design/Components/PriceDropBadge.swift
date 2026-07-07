import SwiftUI

/// Compact "↓ 12%" capsule shown when an item's price dropped below its baseline.
struct PriceDropBadge: View {
    let fraction: Double

    var body: some View {
        Text("↓\(Int((fraction * 100).rounded()))%")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.Colors.purchased, in: Capsule())
    }
}

#Preview {
    HStack {
        PriceDropBadge(fraction: 0.12)
        PriceDropBadge(fraction: 0.05)
        PriceDropBadge(fraction: 0.5)
    }
    .padding()
}
