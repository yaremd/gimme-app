import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(PurchaseService.self) private var purchase
    @State private var currentFeature = 0
    @State private var isPressed = false
    @State private var celebrating = false

    private let features: [(icon: String, title: String, body: String)] = [
        ("square.and.arrow.up", "Unlimited Sharing",  "Share all your lists. Free plan includes up to 2 shared lists."),
        ("chart.pie",           "Stats & Insights",   "Spending charts, totals, and breakdowns across all your lists."),
        ("bell.badge",          "Gifting Alerts",     "Know when someone quietly reserves a gift \u{2014} no spoilers for you."),
        ("rectangle.3.group",   "All Widget Sizes",   "Medium home screen and Lock Screen widgets for every setup."),
        ("sparkles",            "Future Features",    "Every Pro feature we add is included at no extra cost. Ever."),
        ("lock.open",           "Yours Forever",      "One purchase. No subscription. No renewals. Own it forever."),
    ]

    private let featureColors: [Color] = [
        Color(hex: "#7C6FFD"),
        Color(hex: "#3FA9F5"),
        Color(hex: "#34C4A0"),
        Color(hex: "#FF7043"),
        Color(hex: "#FFCA28"),
        Color(hex: "#EC407A"),
    ]

    private var currentColor: Color {
        featureColors[min(currentFeature, featureColors.count - 1)]
    }

    private var isDark: Bool { colorScheme == .dark }

    // Onboarding-matched adaptive colors
    private var bgColor: Color {
        isDark ? Color(hex: "#1A1A1E") : Color(hex: "#F4F2EF")
    }

    private var titleColor: Color {
        isDark ? .white : Color(hex: "#1A1A1E")
    }

    private var bodyColor: Color {
        isDark ? .white.opacity(0.55) : Color(hex: "#1A1A1E").opacity(0.50)
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

    private var footerColor: Color {
        isDark ? .white.opacity(0.30) : Color(hex: "#1A1A1E").opacity(0.30)
    }

    private var windowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first
    }

    private var deviceCornerRadius: CGFloat {
        let r = windowScene?.windows.first?.layer.cornerRadius ?? 0
        return r > 0 ? r : 44
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Floating orbs (same style as onboarding)
            PaywallOrbs(page: currentFeature, isDark: isDark)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Feature carousel
                TabView(selection: $currentFeature) {
                    ForEach(features.indices, id: \.self) { i in
                        featurePage(features[i], color: featureColors[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 240)

                // Custom dots
                pageDots
                    .padding(.top, 4)

                Spacer(minLength: 16)

                purchaseTile

                footerRow
            }

            // Close button
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(.fill, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.leading, 20)
        }
        .overlay {
            if celebrating {
                ConfettiView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .presentationDetents([.height(440)])
        .presentationCornerRadius(deviceCornerRadius)
        .presentationBackground {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                bgColor.opacity(0.92)
            }
        }
        // Celebrate then auto-dismiss on successful purchase
        .onChange(of: purchase.isPro) { _, isPro in
            if isPro {
                Haptics.success()
                celebrating = true
                Task {
                    try? await Task.sleep(for: .seconds(1.8))
                    dismiss()
                }
            }
        }
        .alert("Purchase Error", isPresented: Binding(
            get: { purchase.errorMessage != nil },
            set: { if !$0 { purchase.clearError() } }
        )) {
            Button("OK", role: .cancel) { purchase.clearError() }
        } message: {
            Text(purchase.errorMessage ?? "")
        }
    }

    // MARK: - Custom page dots (onboarding style)

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(features.indices, id: \.self) { i in
                Capsule()
                    .fill(i == currentFeature ? currentColor : dotInactiveColor)
                    .frame(width: i == currentFeature ? 20 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: currentFeature)
    }

    // MARK: - Purchase tile (glass + press animation)

    private var purchaseTile: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Image("GimmeProLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 18)
                Text("One-time purchase")
                    .font(.system(.subheadline))
                    .foregroundStyle(bodyColor)
            }
            Spacer()
            purchasePriceView
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: iconBgGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(iconBorderColor, lineWidth: 0.5)
                )
        )
        .glassCardBackground(radius: 16)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .brightness(isPressed ? 0.08 : 0)
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .simultaneousGesture(TapGesture().onEnded {
            Task { await purchase.purchase() }
        })
        .disabled(purchase.isLoading)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var purchasePriceView: some View {
        if purchase.isLoading {
            ProgressView().tint(bodyColor).frame(width: 50)
        } else {
            Text(purchase.product?.displayPrice ?? "$4.99")
                .font(.rounded(.body, weight: .bold))
                .foregroundStyle(titleColor)
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack(spacing: 10) {
            Button("Restore Purchases") {
                Task { await purchase.restorePurchases() }
            }
            Text("\u{00B7}")
            Link("Privacy", destination: URL(string: "https://gimmelist.com/privacy")!)
            Text("\u{00B7}")
            Button("Promo") {
                Task { @MainActor in
                    guard let scene = windowScene else { return }
                    try? await AppStore.presentOfferCodeRedeemSheet(in: scene)
                }
            }
        }
        .font(.system(.caption))
        .foregroundStyle(footerColor)
        .padding(.top, 20)
        .padding(.bottom, max(20, windowScene?.windows.first?.safeAreaInsets.bottom ?? 34))
    }

    // MARK: - Feature page (glass icon, onboarding text style)

    private func featurePage(_ f: (icon: String, title: String, body: String), color: Color) -> some View {
        VStack(spacing: 14) {
            Spacer()

            // Glass icon container (like onboarding pages 2-3)
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: iconBgGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(iconBorderColor, lineWidth: 0.5)
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: f.icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(spacing: 8) {
                Text(f.title)
                    .font(.rounded(.title3, weight: .bold))
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.center)
                Text(f.body)
                    .font(.system(.subheadline))
                    .foregroundStyle(bodyColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            }

            Spacer()
        }
    }
}

// MARK: - Floating orbs (matches onboarding style, per-feature colors)

private struct PaywallOrbs: View {
    let page: Int
    let isDark: Bool

    private struct Orb {
        let color: String
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let blur: CGFloat
    }

    // One orb set per feature color
    private let darkSets: [[Orb]] = [
        [ // violet
            Orb(color: "#7C6FFD", x: 0.25, y: 0.18, size: 180, blur: 70),
            Orb(color: "#EC407A", x: 0.80, y: 0.28, size: 120, blur: 60),
        ],
        [ // sky blue
            Orb(color: "#3FA9F5", x: 0.70, y: 0.15, size: 170, blur: 70),
            Orb(color: "#34C4A0", x: 0.20, y: 0.25, size: 130, blur: 60),
        ],
        [ // teal
            Orb(color: "#34C4A0", x: 0.30, y: 0.20, size: 170, blur: 70),
            Orb(color: "#3FA9F5", x: 0.75, y: 0.12, size: 130, blur: 60),
        ],
        [ // orange
            Orb(color: "#FF7043", x: 0.35, y: 0.15, size: 180, blur: 70),
            Orb(color: "#FFCA28", x: 0.75, y: 0.28, size: 120, blur: 60),
        ],
        [ // amber
            Orb(color: "#FFCA28", x: 0.25, y: 0.22, size: 170, blur: 70),
            Orb(color: "#FF7043", x: 0.70, y: 0.10, size: 130, blur: 60),
        ],
        [ // pink
            Orb(color: "#EC407A", x: 0.30, y: 0.15, size: 180, blur: 70),
            Orb(color: "#7C6FFD", x: 0.80, y: 0.25, size: 120, blur: 60),
        ],
    ]

    private let lightSets: [[Orb]] = [
        [ // violet
            Orb(color: "#B8B3FF", x: 0.22, y: 0.15, size: 240, blur: 55),
            Orb(color: "#FFB3C6", x: 0.82, y: 0.25, size: 180, blur: 50),
        ],
        [ // sky blue
            Orb(color: "#A3D9FF", x: 0.72, y: 0.12, size: 230, blur: 55),
            Orb(color: "#A3F0D5", x: 0.18, y: 0.22, size: 190, blur: 50),
        ],
        [ // teal
            Orb(color: "#A3F0D5", x: 0.28, y: 0.18, size: 230, blur: 55),
            Orb(color: "#A3D9FF", x: 0.78, y: 0.10, size: 190, blur: 50),
        ],
        [ // orange
            Orb(color: "#FFD4B3", x: 0.32, y: 0.12, size: 240, blur: 55),
            Orb(color: "#FFE8A3", x: 0.78, y: 0.25, size: 180, blur: 50),
        ],
        [ // amber
            Orb(color: "#FFE8A3", x: 0.22, y: 0.20, size: 230, blur: 55),
            Orb(color: "#FFD4B3", x: 0.72, y: 0.08, size: 190, blur: 50),
        ],
        [ // pink
            Orb(color: "#FFB3C6", x: 0.28, y: 0.12, size: 240, blur: 55),
            Orb(color: "#B8B3FF", x: 0.82, y: 0.22, size: 180, blur: 50),
        ],
    ]

    var body: some View {
        GeometryReader { geo in
            let sets = isDark ? darkSets : lightSets
            let orbs = sets[min(page, sets.count - 1)]
            let opacity: Double = isDark ? 0.18 : 0.40
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
        .animation(.easeInOut(duration: 0.5), value: page)
    }
}

#Preview("Dark") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            PaywallView()
                .environment(PurchaseService())
                .preferredColorScheme(.dark)
        }
}

#Preview("Light") {
    Color.white.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            PaywallView()
                .environment(PurchaseService())
                .preferredColorScheme(.light)
        }
}
