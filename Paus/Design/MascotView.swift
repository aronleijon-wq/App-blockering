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
                    .overlay {
                        if mood == .wrecked {
                            // A sickly green tinge.
                            BlobShape(phase: time * 1.6, wobble: 0.03)
                                .fill(Color(red: 0.45, green: 0.6, blue: 0.3).opacity(0.35))
                        }
                    }
                    .saturation(saturation)

                face(time: time)
                accessories(time: time)
                if mood == .crying {
                    tears(time: time)
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(x: mood == .wrecked ? 1.04 : 1, y: mood == .wrecked ? 0.92 : 1, anchor: .bottom)
            .offset(y: CGFloat(sin(time * bobSpeed)) * size * 0.025)
        }
        .accessibilityElement()
        .accessibilityLabel(L("Pip, nivå \(level), \(mood.label)"))
    }

    private var saturation: Double {
        switch mood {
        case .sad: return 0.45
        case .crying: return 0.3
        case .wrecked: return 0.12
        default: return 1
        }
    }

    private var bobSpeed: Double {
        switch mood {
        case .hyped: return 4
        case .crying, .wrecked: return 1
        default: return 2
        }
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
        case .wrecked:
            // Dazed X eyes.
            CrossShape()
                .stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: size * 0.028, lineCap: .round))
                .frame(width: eyeSize * 0.7, height: eyeSize * 0.7)
        default:
            ZStack {
                Ellipse().fill(.white)
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: eyeSize * 0.52)
                    .offset(y: mood == .sad || mood == .crying ? eyeSize * 0.15 : 0)
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
        case .sad, .crying:
            ArcShape(upward: true)
                .stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round))
                .frame(width: width * (mood == .crying ? 1 : 0.8), height: width * (mood == .crying ? 0.4 : 0.3))
        case .wrecked:
            WavyLine()
                .stroke(Color.black.opacity(0.75), style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round, lineJoin: .round))
                .frame(width: width, height: width * 0.25)
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

    /// Two drops that keep running down from under the eyes.
    private func tears(time: Double) -> some View {
        ForEach(0..<2, id: \.self) { index in
            let phase = (time * 0.7 + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
            Image(systemName: "drop.fill")
                .font(.system(size: size * 0.07))
                .foregroundStyle(Color(red: 0.55, green: 0.8, blue: 1))
                .offset(
                    x: (index == 0 ? -1 : 1) * size * 0.19,
                    y: size * 0.02 + CGFloat(phase) * size * 0.22
                )
                .opacity(1 - phase)
        }
    }

    @ViewBuilder
    private func accessories(time: Double) -> some View {
        let top = -size * 0.47
        if mood == .wrecked {
            // A plaster instead of the level accessory.
            RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                .fill(Color(red: 0.98, green: 0.84, blue: 0.68))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.015, style: .continuous)
                        .fill(Color(red: 0.9, green: 0.72, blue: 0.56))
                        .frame(width: size * 0.07, height: size * 0.06)
                }
                .frame(width: size * 0.22, height: size * 0.08)
                .rotationEffect(.degrees(-30))
                .offset(x: size * 0.2, y: -size * 0.3)
        } else if level >= 8 {
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

        if (level >= 10 && mood != .crying && mood != .wrecked) || mood == .proud || mood == .hyped {
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
        case .happy: return L("glad")
        case .zen: return L("i fokus")
        case .sleepy: return L("sömnig")
        case .sad: return L("lite ledsen")
        case .crying: return L("ledsen och mår dåligt")
        case .wrecked: return L("scrollsjuk")
        case .proud: return L("stolt")
        case .hyped: return L("peppad")
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

/// The two diagonals of a box, for dazed eyes.
struct CrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

/// A queasy zigzag mouth.
struct WavyLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let segments = 4
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        for index in 1...segments {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(segments)
            let controlX = x - rect.width / CGFloat(segments * 2)
            path.addQuadCurve(to: CGPoint(x: x, y: rect.midY), control: CGPoint(x: controlX, y: index.isMultiple(of: 2) ? rect.maxY : rect.minY))
        }
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

#Preview(L("Nivåer")) {
    HStack {
        ForEach([1, 3, 6, 10], id: \.self) { level in
            MascotView(mood: .happy, level: level, size: 80)
        }
    }
    .padding()
    .screenBackground()
}
