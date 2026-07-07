import Charts
import SwiftUI

/// Compact sparkline of an item's tracked price history.
/// Prices render as steps (a price holds until it changes), extended to today.
struct PriceHistoryChart: View {
    let history: [PricePoint]
    let currency: String?
    let tint: Color

    /// History plus a synthetic "still this price today" point so the line
    /// reaches the trailing edge.
    private var plotted: [PricePoint] {
        guard let last = history.last,
              Date.now.timeIntervalSince(last.date) > 3_600 else { return history }
        return history + [PricePoint(date: .now, price: last.price)]
    }

    private var yDomain: ClosedRange<Double> {
        let prices = history.map(\.price)
        guard let low = prices.min(), let high = prices.max(), high > 0 else { return 0...1 }
        let pad = Swift.max((high - low) * 0.15, high * 0.02)
        return Swift.max(0, low - pad)...(high + pad)
    }

    var body: some View {
        Chart(plotted, id: \.date) { point in
            AreaMark(
                x: .value("Date", point.date),
                yStart: .value("Floor", yDomain.lowerBound),
                yEnd: .value("Price", point.price)
            )
            .interpolationMethod(.stepEnd)
            .foregroundStyle(
                LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0.02)],
                               startPoint: .top, endPoint: .bottom)
            )
            LineMark(
                x: .value("Date", point.date),
                y: .value("Price", point.price)
            )
            .interpolationMethod(.stepEnd)
            .foregroundStyle(tint)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .chartYScale(domain: yDomain)
        .chartPlotStyle { $0.clipped() }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { value in
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(Decimal(price).formatted(currency: currency))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
            }
        }
        .frame(height: 72)
    }
}

#Preview {
    PriceHistoryChart(
        history: [
            PricePoint(date: .now.addingTimeInterval(-86_400 * 30), price: 249),
            PricePoint(date: .now.addingTimeInterval(-86_400 * 18), price: 229),
            PricePoint(date: .now.addingTimeInterval(-86_400 * 9), price: 239),
            PricePoint(date: .now.addingTimeInterval(-86_400 * 2), price: 199)
        ],
        currency: "USD",
        tint: .purple
    )
    .padding()
}
