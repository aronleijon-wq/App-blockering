import SwiftUI

/// Falling confetti drawn with Canvas. Shows a still sprinkle when Reduce Motion is on.
struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    @State private var pieces: [Piece] = (0..<70).map { _ in Piece.random() }
    private static let colors: [Color] = [Theme.violet, Theme.pink, Theme.orange, Theme.mint, .white]

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { context in
            let elapsed = reduceMotion ? 1.2 : context.date.timeIntervalSince(start)
            Canvas { canvas, size in
                for piece in pieces {
                    let fall = (piece.delay + elapsed * piece.speed).truncatingRemainder(dividingBy: 1.3) - 0.15
                    let x = CGFloat(piece.x) * size.width + CGFloat(sin(elapsed * piece.sway + piece.x * 10)) * 18
                    let y = CGFloat(fall) * size.height
                    var context = canvas
                    context.translateBy(x: x, y: y)
                    context.rotate(by: .radians(elapsed * piece.spin))
                    let rect = CGRect(x: -piece.width / 2, y: -piece.height / 2, width: piece.width, height: piece.height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Self.colors[piece.colorIndex]))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let sway: Double
        let spin: Double
        let width: CGFloat
        let height: CGFloat
        let colorIndex: Int

        static func random() -> Piece {
            Piece(
                x: .random(in: 0...1),
                delay: .random(in: 0...1.3),
                speed: .random(in: 0.25...0.5),
                sway: .random(in: 1...3),
                spin: .random(in: -4...4),
                width: .random(in: 6...10),
                height: .random(in: 10...16),
                colorIndex: .random(in: 0..<ConfettiView.colors.count)
            )
        }
    }
}
