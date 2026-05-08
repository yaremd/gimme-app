import SwiftUI
import UIKit

struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> ConfettiUIView {
        let view = ConfettiUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: ConfettiUIView, context: Context) {}
}

final class ConfettiUIView: UIView {

    private let emitter = CAEmitterLayer()
    private var started = false

    private static let palette: [UIColor] = [
        UIColor(red: 0.49, green: 0.44, blue: 0.99, alpha: 1), // #7C6FFD
        UIColor(red: 0.25, green: 0.66, blue: 0.96, alpha: 1), // #3FA9F5
        UIColor(red: 0.20, green: 0.77, blue: 0.63, alpha: 1), // #34C4A0
        UIColor(red: 1.00, green: 0.44, blue: 0.26, alpha: 1), // #FF7043
        UIColor(red: 1.00, green: 0.79, blue: 0.16, alpha: 1), // #FFCA28
        UIColor(red: 0.93, green: 0.25, blue: 0.48, alpha: 1), // #EC407A
        .white,
    ]

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !started, bounds.width > 0 else { return }
        started = true
        start()
    }

    private func start() {
        emitter.emitterPosition = CGPoint(x: bounds.width / 2, y: -10)
        emitter.emitterSize     = CGSize(width: bounds.width * 1.2, height: 1)
        emitter.emitterShape    = .line
        emitter.renderMode      = .unordered

        emitter.emitterCells = Self.palette.flatMap { color in
            [makeCell(color: color, rect: true),
             makeCell(color: color, rect: false)]
        }

        layer.addSublayer(emitter)

        // Burst: emit hard for 0.35 s then cut off so particles drain naturally.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.emitter.birthRate = 0
        }
    }

    private func makeCell(color: UIColor, rect: Bool) -> CAEmitterCell {
        let cell = CAEmitterCell()

        // Draw particle image
        let w: CGFloat = rect ? 7 : 8
        let h: CGFloat = rect ? 12 : 8
        let size = CGSize(width: w, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { _ in
            color.setFill()
            if rect {
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 1.5).fill()
            } else {
                UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            }
        }
        cell.contents = img.cgImage

        cell.birthRate        = 14
        cell.lifetime         = 2.2
        cell.lifetimeRange    = 0.5
        cell.velocity         = 380
        cell.velocityRange    = 120
        cell.emissionLongitude = .pi          // straight down
        cell.emissionRange    = .pi / 5       // slight spread
        cell.spin             = 4
        cell.spinRange        = 5
        cell.scale            = 1.0
        cell.scaleRange       = 0.4
        cell.alphaSpeed       = -0.25
        cell.yAcceleration    = 80            // subtle gravity boost

        return cell
    }
}
