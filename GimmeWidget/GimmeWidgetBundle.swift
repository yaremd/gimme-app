import SwiftUI
import WidgetKit

@main
struct GimmeWidgetBundle: WidgetBundle {
    var body: some Widget {
        GimmeWidget()
        GimmeLockScreenWidget()
    }
}
