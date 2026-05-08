import SwiftUI

struct ConfettiView: View {

    private struct Particle: Identifiable {
        let id = UUID()
        let xFraction: CGFloat
        let delay: Double
        let duration: Double
        let color: Color
        let startAngle: Double
        let endAngle: Double
        let width: CGFloat
        let height: CGFloat
        let shape: Int  // 0 = rect, 1 = circle, 2 = rounded
    }

    private static let palette: [Color] = [
        Color(hex: "#7C6FFD"),
        Color(hex: "#3FA9F5"),
        Color(hex: "#34C4A0"),
        Color(hex: "#FF7043"),
        Color(hex: "#FFCA28"),
        Color(hex: "#EC407A"),
        .white,
    ]

    @State private var particles: [Particle] = []
    @State private var animating = false

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { p in
                confettiPiece(p)
                    .position(
                        x: p.xFraction * geo.size.width,
                        y: animating ? geo.size.height + 60 : -20
                    )
                    .rotationEffect(.degrees(animating ? p.endAngle : p.startAngle))
                    .animation(
                        .linear(duration: p.duration).delay(p.delay),
                        value: animating
                    )
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            particles = (0..<90).map { _ in
                Particle(
                    xFraction: .random(in: 0.02...0.98),
                    delay: .random(in: 0...0.55),
                    duration: .random(in: 0.9...1.5),
                    color: palette.randomElement()!,
                    startAngle: .random(in: -30...30),
                    endAngle: .random(in: 200...520),
                    width: .random(in: 5...9),
                    height: .random(in: 8...14),
                    shape: Int.random(in: 0...2)
                )
            }
            // Tiny delay so the view is in the hierarchy before animation fires
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animating = true
            }
        }
    }

    @ViewBuilder
    private func confettiPiece(_ p: Particle) -> some View {
        switch p.shape {
        case 1:
            Circle()
                .fill(p.color)
                .frame(width: p.width, height: p.width)
        case 2:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(p.color)
                .frame(width: p.width, height: p.height)
        default:
            Rectangle()
                .fill(p.color)
                .frame(width: p.width, height: p.height)
        }
    }
}
