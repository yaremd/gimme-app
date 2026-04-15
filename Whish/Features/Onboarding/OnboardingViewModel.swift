import SwiftUI

@Observable @MainActor final class OnboardingViewModel {
    var currentPage = 0
    var direction: SwipeDirection = .forward
    let pageCount = 3

    enum SwipeDirection {
        case forward, backward
    }

    func advance() {
        guard currentPage < pageCount - 1 else { return }
        direction = .forward
        currentPage += 1
    }

    func goBack() {
        guard currentPage > 0 else { return }
        direction = .backward
        currentPage -= 1
    }
}
