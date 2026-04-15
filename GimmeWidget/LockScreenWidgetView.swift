import SwiftUI
import WidgetKit

// MARK: - Lock Screen Widget Definition

struct GimmeLockScreenWidget: Widget {
    let kind = "GimmeLockScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectListIntent.self, provider: GimmeTimelineProvider()) { entry in
            LockScreenWidgetView(data: entry.displayData)
        }
        .configurationDisplayName("Gimme")
        .description("Remaining wishlist items.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

// MARK: - Lock Screen Views

struct LockScreenWidgetView: View {
    let data: WidgetDisplayData
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    private var circularView: some View {
        Gauge(value: data.completionFraction) {
            // Label (not shown in circular)
            Image(systemName: "heart.fill")
        } currentValueLabel: {
            Text("\(data.unpurchasedCount)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
            if data.reservedCount > 0 {
                Text("\(data.reservedCount) reserved, \(data.unpurchasedCount) remaining")
            } else {
                Text("\(data.unpurchasedCount) wish\(data.unpurchasedCount == 1 ? "" : "es") remaining")
            }
        }
    }
}

#Preview("Circular", as: .accessoryCircular) {
    GimmeLockScreenWidget()
} timeline: {
    GimmeEntry(date: .now, snapshot: .placeholder, selectedListID: nil)
}

#Preview("Inline", as: .accessoryInline) {
    GimmeLockScreenWidget()
} timeline: {
    GimmeEntry(date: .now, snapshot: .placeholder, selectedListID: nil)
}
