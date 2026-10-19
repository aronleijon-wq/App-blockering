import SwiftUI

/// Pip, the mascot. Its face follows the mood and it gains accessories as the user levels up.
struct MascotView: View {
    var mood: MascotMood
    var level: Int
    var size: CGFloat = 170

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .fill(bodyGradient)
                    .blur(radius: size * 0.2)
                    .opacity(0.5)

                BlobShape(phase: time * 1.6, wobble: mood == .hyped ? 0.055 : 0.03)
                    .fill(bodyGradient)
                    .overlay {
                        BlobShape(phase: time * 1.6, wobble: mood == .hyped ? 0.055 : 0.03)
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    }
                    .saturation(mood == .sad ? 0.45 : 1)

                face(time: time)
                accessories(time: time)
            }
            .frame(width: size, height: size)
            .offset(y: CGFloat(sin(time * (mood == .hyped ? 4 : 2))) * size * 0.025)
        }
        .accessibilityElement()
        .accessibilityLabel("Pip, nivå \(level), \(mood.label)")
    }

    private var bodyGradient: LinearGradient {
        let colors: [Color]
        switch level {
        case ..<3: colors = [Theme.mint, Color(red: 0.2, green: 0.75, blue: 0.95)]
        case 3..<5: colors = [Theme.violet, Theme.pink]
        case 5..<8: colors = [Theme.pink, Theme.orange]
        default: colors = [Theme.orange, Color(red: 1, green: 0.9, blue: 0.35), Theme.pink]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func face(time: Double) -> some View {
        let isBlinking = time.truncatingRemainder(dividingBy: 4.2) < 0.13
        return ZStack {
            HStack(spacing: size * 0.2) {
                eye(isBlinking: isBlinking)
                eye(isBlinking: isBlinking)
            }
            .offset(y: -size * 0.07)

            HStack(spacing: size * 0.42) {
                Circle().fill(Theme.pink.opacity(0.55))
                Circle().fill(Theme.pink.opacity(0.55))
            }
            .frame(height: size * 0.09)
            .offset(y: size * 0.06)

            mouth
                .offset(y: size * 0.13)

            if mood == .sleepy {
                Text("z z")
                    .font(.system(size: size * 0.12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .offset(x: size * 0.36, y: -size * 0.36 - CGFloat(sin(time)) * size * 0.04)
            }
        }
    }

    @ViewBuilder
    private func eye(isBlinking: Bool) -> some View {
        let eyeSize = size * 0.17
        switch mood {
        case .zen, .sleepy:
            // Closed, content eyes.
            ArcShape(upward: mood == .zen)
                .stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round))
                .frame(width: eyeSize, height: eyeSize * 0.45)
        default:
            ZStack {
                Ellipse().fill(.white)
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: eyeSize * 0.52)
                    .offset(y: mood == .sad ? eyeSize * 0.15 : 0)
                Circle()
                    .fill(.white)
                    .frame(width: eyeSize * 0.18)
                    .offset(x: eyeSize * 0.1, y: -eyeSize * 0.1)
            }
            .frame(width: eyeSize, height: isBlinking ? eyeSize * 0.12 : eyeSize * (mood == .hyped ? 1.1 : 1))
        }
    }

    @ViewBuilder
    private var mouth: some View {
        let width = size * 0.2
        switch mood {
        case .proud, .hyped:
            HalfCircle()
                .fill(Color.black.opacity(0.75))
                .frame(width: width, height: width * 0.55)
        case .sad:
            ArcShape(upward: true)
                .stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round))
                .frame(width: width * 0.8, height: width * 0.3)
        case .sleepy:
            Ellipse()
                .fill(Color.black.opacity(0.7))
                .frame(width: width * 0.3, height: width * 0.25)
        case .happy, .zen:
            ArcShape(upward: false)
                .stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round))
                .frame(width: width, height: width * 0.4)
        }
    }

    @ViewBuilder
    private func accessories(time: Double) -> some View {
        let top = -size * 0.47
        if level >= 8 {
            Image(systemName: "crown.fill")
                .font(.system(size: size * 0.22))
                .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.3), Theme.orange], startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.orange.opacity(0.6), radius: 6)
                .offset(y: top)
        } else if level >= 6 {
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.16))
                .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.3))
                .rotationEffect(.degrees(sin(time * 2) * 10))
                .offset(y: top)
        } else if level >= 3 {
            Image(systemName: "leaf.fill")
                .font(.system(size: size * 0.16))
                .foregroundStyle(Theme.mint)
                .rotationEffect(.degrees(-20 + sin(time * 2) * 8))
                .offset(x: size * 0.04, y: top + size * 0.03)
        }

        if level >= 10 || mood == .proud || mood == .hyped {
            ForEach(0..<3, id: \.self) { index in
                let angle = time * 0.9 + Double(index) * 2 * .pi / 3
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.1))
                    .foregroundStyle(.white)
                    .offset(x: CGFloat(cos(angle)) * size * 0.58, y: CGFloat(sin(angle)) * size * 0.5)
                    .opacity(0.9)
            }
        }
    }
}

extension MascotMood {
    var label: String {
        switch self {
        case .happy: return "glad"
        case .zen: return "i fokus"
        case .sleepy: return "sömnig"
        case .sad: return "lite ledsen"
        case .proud: return "stolt"
        case .hyped: return "peppad"
        }
    }
}

/// A soft, slowly wobbling circle.
struct BlobShape: Shape {
    var phase: Double
    var wobble: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = Double(min(rect.width, rect.height)) / 2 * 0.86
        let steps = 90
        var path = Path()
        for step in 0...steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            let scale = 1 + wobble * sin(3 * angle + phase) + wobble * 0.6 * sin(5 * angle - phase * 1.3)
            let point = CGPoint(
                x: center.x + CGFloat(radius * scale * cos(angle)),
                y: center.y + CGFloat(radius * scale * sin(angle) * 0.94)
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// A curved line: a smile when `upward` is false, a frown or closed eye when true.
struct ArcShape: Shape {
    var upward: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: upward ? rect.maxY : rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: upward ? rect.maxY : rect.minY),
            control: CGPoint(x: rect.midX, y: upward ? rect.minY - rect.height : rect.maxY + rect.height)
        )
        return path
    }
}

/// An open, laughing mouth.
struct HalfCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2))
        path.closeSubpath()
        return path
    }
}

#Preview("Humör") {
    ScrollView {
        LazyVGrid(columns: [GridItem(), GridItem()], spacing: 24) {
            ForEach(MascotMood.allCases, id: \.self) { mood in
                VStack {
                    MascotView(mood: mood, level: 4, size: 130)
                    Text(mood.label).foregroundStyle(.white)
                }
            }
        }
        .padding()
    }
    .screenBackground()
}

#Preview("Nivåer") {
    HStack {
        ForEach([1, 3, 6, 10], id: \.self) { level in
            MascotView(mood: .happy, level: level, size: 80)
        }
    }
    .padding()
    .screenBackground()
}
