import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete = false
    @State private var viewModel = OnboardingViewModel()
    @State private var isShowingAuth = false
    @State private var dragOffset: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    private struct Page {
        let icon: String?           // nil = use app icon
        let secondaryIcon: String?
        let label: String
        let title: String
        let body: String
        let buttonLabel: String
    }

    private let pages: [Page] = [
        Page(
            icon: nil,              // app icon
            secondaryIcon: nil,
            label: "HELLO",
            title: "Welcome to\nGimme",
            body: "Save everything you want and keep it all in one beautiful place.",
            buttonLabel: "Continue"
        ),
        Page(
            icon: "square.and.arrow.up.fill",
            secondaryIcon: "link",
            label: "SHARE WITH ANYONE",
            title: "Share your list,\nkeep the surprise",
            body: "Send a link to friends and family. They quietly mark what they're gifting — no account needed.",
            buttonLabel: "Continue"
        ),
        Page(
            icon: "person.crop.circle.fill",
            secondaryIcon: "arrow.triangle.2.circlepath",
            label: "SYNC EVERYWHERE",
            title: "Your lists,\non every device",
            body: "Create a free account to sync your wishlists across all your Apple devices.",
            buttonLabel: "Let's start!"
        ),
    ]

    private var current: Page { pages[viewModel.currentPage] }
    private var isLast: Bool { viewModel.currentPage == pages.count - 1 }
    private var isDark: Bool { colorScheme == .dark }

    private var windowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first
    }

    private var deviceCornerRadius: CGFloat {
        let r = windowScene?.windows.first?.layer.cornerRadius ?? 0
        return r > 0 ? r : 44
    }

    // MARK: - Adaptive colors

    private var bgColor: Color {
        isDark ? Color(hex: "#1A1A1E") : Color(hex: "#F4F2EF")
    }

    private var titleColor: Color {
        isDark ? .white : Color(hex: "#1A1A1E")
    }

    private var bodyColor: Color {
        isDark ? .white.opacity(0.55) : Color(hex: "#1A1A1E").opacity(0.50)
    }

    private var iconFgColor: Color {
        isDark ? .white.opacity(0.90) : Color(hex: "#1A1A1E").opacity(0.80)
    }

    private var iconBgGradient: [Color] {
        isDark
            ? [.white.opacity(0.10), .white.opacity(0.04)]
            : [Color(hex: "#1A1A1E").opacity(0.06), Color(hex: "#1A1A1E").opacity(0.02)]
    }

    private var iconBorderColor: Color {
        isDark ? .white.opacity(0.10) : Color(hex: "#1A1A1E").opacity(0.08)
    }

    private var dotInactiveColor: Color {
        isDark ? .white.opacity(0.20) : Color(hex: "#1A1A1E").opacity(0.15)
    }

    private var skipColor: Color {
        isDark ? .white.opacity(0.40) : Color(hex: "#1A1A1E").opacity(0.35)
    }

    // MARK: - Direction-aware transition

    private var contentTransition: AnyTransition {
        switch viewModel.direction {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    private var iconTransition: AnyTransition {
        switch viewModel.direction {
        case .forward:
            return .asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 1.1).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .scale(scale: 1.1).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            )
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            FloatingOrbs(page: viewModel.currentPage, isDark: isDark)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // ── Top spacer — pushes icon to ~22% from top ────────
                Spacer().frame(height: UIScreen.main.bounds.height * 0.22)

                // ── Icon (fixed position, crossfade) ─────────────────
                iconView
                    .frame(height: 120)
                    .id(viewModel.currentPage)
                    .transition(iconTransition)

                Spacer().frame(height: 40)

                // ── Text (slide in swipe direction) ──────────────────
                textBlock
                    .frame(height: 170, alignment: .top)
                    .id(viewModel.currentPage)
                    .transition(contentTransition)

                Spacer()

                // ── Dots ─────────────────────────────────────────────
                pageDots

                Spacer().frame(height: 24)

                // ── Buttons ──────────────────────────────────────────
                bottomButtons
            }
            .offset(x: dragOffset * 0.25)
        }
        .gesture(swipeGesture)
        .presentationDetents([.large])
        .presentationCornerRadius(deviceCornerRadius)
        .presentationBackground {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                bgColor.opacity(0.92)
            }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $isShowingAuth, onDismiss: { isOnboardingComplete = true }) {
            AuthView()
                .pageSheet()
        }
    }

    // MARK: - Swipe gesture (follows finger direction)

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onChanged { value in
                let t = value.translation.width
                let canBack = viewModel.currentPage > 0
                let canFwd = viewModel.currentPage < pages.count - 1

                if (t > 0 && canBack) || (t < 0 && canFwd) {
                    dragOffset = t
                } else {
                    dragOffset = t * 0.15  // rubber band
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 60
                let velocity = value.predictedEndTranslation.width

                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    if (value.translation.width < -threshold || velocity < -200),
                       viewModel.currentPage < pages.count - 1 {
                        viewModel.advance()
                    } else if (value.translation.width > threshold || velocity > 200),
                              viewModel.currentPage > 0 {
                        viewModel.goBack()
                    }
                    dragOffset = 0
                }
            }
    }

    // MARK: - Icon

    private var iconView: some View {
        Group {
            if current.icon == nil {
                // Page 1: App icon
                Image("GimmeIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Theme.Colors.accent.opacity(0.30), radius: 20, y: 8)
            } else {
                // Pages 2–3: SF Symbol in glass container
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: iconBgGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(iconBorderColor, lineWidth: 0.5)
                        )
                        .frame(width: 110, height: 110)

                    Image(systemName: current.icon!)
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(iconFgColor)

                    if let secondary = current.secondaryIcon {
                        Image(systemName: secondary)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Theme.Colors.accent, in: Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.20), lineWidth: 0.5))
                            .offset(x: 44, y: 44)
                    }
                }
            }
        }
    }

    // MARK: - Text block

    private var textBlock: some View {
        VStack(spacing: 14) {
            Text(current.label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "#E8A838"))
                .kerning(3)

            Text(current.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(titleColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(current.body)
                .font(.system(.body))
                .foregroundStyle(bodyColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Page dots

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(i == viewModel.currentPage ? Theme.Colors.accent : dotInactiveColor)
                    .frame(width: i == viewModel.currentPage ? 24 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: viewModel.currentPage)
    }

    // MARK: - Bottom buttons

    private var bottomButtons: some View {
        VStack(spacing: 10) {
            if isLast {
                OnboardingPressButton(label: "Create Account / Sign In", isDark: isDark) {
                    isShowingAuth = true
                }
                Button {
                    isOnboardingComplete = true
                } label: {
                    Text("Continue without account")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(skipColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .transition(.opacity)
            } else {
                OnboardingPressButton(label: current.buttonLabel, isDark: isDark) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                        viewModel.advance()
                    }
                }
                Color.clear.frame(height: 44)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: viewModel.currentPage)
        .padding(.horizontal, 28)
        .padding(.bottom, 36)
    }
}

// MARK: - Press button with highlight (keypad-style)

private struct OnboardingPressButton: View {
    let label: String
    let isDark: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Text(label)
            .font(.rounded(.body, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .primaryGlassBackground(color: Theme.Colors.accent)
            .shadow(color: .black.opacity(isDark ? 0.28 : 0.10), radius: isPressed ? 6 : 20, y: isPressed ? 1 : 8)
            .shadow(color: Theme.Colors.accent.opacity(isPressed ? 0.15 : 0.35), radius: isPressed ? 3 : 12, y: isPressed ? 1 : 4)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .brightness(isPressed ? 0.08 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
            .simultaneousGesture(TapGesture().onEnded { action() })
    }
}

// MARK: - Floating gradient orbs

private struct FloatingOrbs: View {
    let page: Int
    let isDark: Bool

    private struct Orb {
        let color: String
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let blur: CGFloat
    }

    private let darkSets: [[Orb]] = [
        [
            Orb(color: "#6C63FF", x: 0.25, y: 0.18, size: 200, blur: 80),
            Orb(color: "#EC407A", x: 0.80, y: 0.28, size: 140, blur: 70),
            Orb(color: "#6C63FF", x: 0.55, y: 0.08, size: 100, blur: 60),
        ],
        [
            Orb(color: "#3FA9F5", x: 0.70, y: 0.15, size: 180, blur: 80),
            Orb(color: "#34C4A0", x: 0.20, y: 0.25, size: 160, blur: 70),
            Orb(color: "#3FA9F5", x: 0.50, y: 0.05, size: 120, blur: 65),
        ],
        [
            Orb(color: "#34C4A0", x: 0.30, y: 0.20, size: 190, blur: 80),
            Orb(color: "#E8A838", x: 0.75, y: 0.12, size: 150, blur: 75),
            Orb(color: "#34C4A0", x: 0.55, y: 0.30, size: 100, blur: 60),
        ],
    ]

    private let lightSets: [[Orb]] = [
        [
            Orb(color: "#B8B3FF", x: 0.20, y: 0.15, size: 280, blur: 60),
            Orb(color: "#FFB3C6", x: 0.82, y: 0.25, size: 220, blur: 55),
            Orb(color: "#C4BFFF", x: 0.50, y: 0.05, size: 180, blur: 50),
            Orb(color: "#E8D5FF", x: 0.65, y: 0.35, size: 160, blur: 65),
        ],
        [
            Orb(color: "#A3D9FF", x: 0.72, y: 0.12, size: 260, blur: 60),
            Orb(color: "#A3F0D5", x: 0.18, y: 0.22, size: 240, blur: 55),
            Orb(color: "#B3E5FF", x: 0.45, y: 0.02, size: 180, blur: 50),
            Orb(color: "#C4F5E8", x: 0.60, y: 0.32, size: 150, blur: 60),
        ],
        [
            Orb(color: "#A3F0D5", x: 0.28, y: 0.18, size: 270, blur: 60),
            Orb(color: "#FFE0A3", x: 0.78, y: 0.10, size: 230, blur: 55),
            Orb(color: "#B8F5D9", x: 0.50, y: 0.30, size: 180, blur: 50),
            Orb(color: "#FFEDC4", x: 0.35, y: 0.05, size: 160, blur: 60),
        ],
    ]

    var body: some View {
        GeometryReader { geo in
            let sets = isDark ? darkSets : lightSets
            let orbs = sets[min(page, sets.count - 1)]
            let opacity: Double = isDark ? 0.18 : 0.45
            ForEach(orbs.indices, id: \.self) { i in
                let orb = orbs[i]
                Circle()
                    .fill(Color(hex: orb.color).opacity(opacity))
                    .frame(width: orb.size, height: orb.size)
                    .blur(radius: orb.blur)
                    .position(
                        x: geo.size.width * orb.x,
                        y: geo.size.height * orb.y
                    )
            }
        }
        .animation(.easeInOut(duration: 0.6), value: page)
    }
}

#Preview("Dark") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            OnboardingView()
                .preferredColorScheme(.dark)
        }
}

#Preview("Light") {
    Color.white.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            OnboardingView()
                .preferredColorScheme(.light)
        }
}
