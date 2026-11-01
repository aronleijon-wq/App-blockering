import SwiftUI
import WidgetKit

// MARK: - Pip

/// Pip for widgets: a still drawing whose face follows the mood. Widgets can't run the app's animated mascot.
struct WidgetPip: View {
    let mood: MascotMood
    let level: Int

    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                Ellipse()
                    .fill(LinearGradient(colors: bodyColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Ellipse().stroke(Color.white.opacity(0.85), lineWidth: s * 0.03))
                    .frame(width: s * 0.94, height: s * 0.9)
                    .saturation(isDown ? 0.45 : 1)
                eyes(s)
                    .offset(y: -s * 0.06)
                cheeks(s)
                    .offset(y: s * 0.13)
                mouth(s)
                    .offset(y: s * 0.18)
                if mood == .crying {
                    Capsule()
                        .fill(Color(red: 0.5, green: 0.8, blue: 1))
                        .frame(width: s * 0.06, height: s * 0.14)
                        .offset(x: -s * 0.2, y: s * 0.08)
                }
                if mood == .sleepy {
                    Text("z")
                        .font(.system(size: s * 0.18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .offset(x: s * 0.36, y: -s * 0.38)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    private var isDown: Bool { mood == .sad || mood == .crying || mood == .wrecked }

    private var bodyColors: [Color] {
        switch level {
        case ..<3: return [Palette.mint, Color(red: 0.2, green: 0.75, blue: 0.95)]
        case 3..<5: return [Palette.violet, Palette.pink]
        case 5..<8: return [Palette.pink, Palette.orange]
        default: return [Palette.orange, Color(red: 1, green: 0.9, blue: 0.35)]
        }
    }

    private func eyes(_ s: CGFloat) -> some View {
        HStack(spacing: s * 0.2) {
            ForEach(0..<2, id: \.self) { _ in
                ZStack {
                    switch mood {
                    case .zen, .sleepy:
                        // Closed, content eyes.
                        Capsule()
                            .fill(Color(red: 0.08, green: 0.06, blue: 0.16))
                            .frame(width: s * 0.17, height: s * 0.035)
                    default:
                        Circle().fill(.white).frame(width: s * 0.2, height: s * 0.2)
                        Circle()
                            .fill(Color(red: 0.08, green: 0.06, blue: 0.16))
                            .frame(width: s * 0.11, height: s * 0.11)
                            .offset(y: isDown ? s * 0.03 : 0)
                        Circle().fill(.white).frame(width: s * 0.035, height: s * 0.035).offset(x: s * 0.025, y: -s * 0.03)
                    }
                }
                .frame(width: s * 0.22, height: s * 0.22)
            }
        }
    }

    private func cheeks(_ s: CGFloat) -> some View {
        HStack(spacing: s * 0.42) {
            Ellipse().fill(Palette.pink.opacity(0.55)).frame(width: s * 0.13, height: s * 0.08)
            Ellipse().fill(Palette.pink.opacity(0.55)).frame(width: s * 0.13, height: s * 0.08)
        }
    }

    @ViewBuilder
    private func mouth(_ s: CGFloat) -> some View {
        let ink = Color(red: 0.08, green: 0.06, blue: 0.16)
        switch mood {
        case .hyped, .proud:
            Ellipse()
                .trim(from: 0.5, to: 1)
                .fill(ink)
                .rotationEffect(.degrees(180))
                .frame(width: s * 0.2, height: s * 0.16)
        case .sad, .crying, .wrecked:
            Arc(up: true).stroke(ink, style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                .frame(width: s * 0.16, height: s * 0.06)
        case .sleepy:
            Capsule().fill(ink).frame(width: s * 0.08, height: s * 0.03)
        default:
            Arc(up: false).stroke(ink, style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                .frame(width: s * 0.18, height: s * 0.07)
        }
    }
}

/// A smile, or a frown when `up`.
private struct Arc: Shape {
    let up: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y0 = up ? rect.maxY : rect.minY
        let control = up ? rect.minY - rect.height : rect.maxY + rect.height
        path.move(to: CGPoint(x: rect.minX, y: y0))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: y0), control: CGPoint(x: rect.midX, y: control))
        return path
    }
}

// MARK: - The Pip widget

/// A big headline with Pip beside it: a live countdown while something is blocked, otherwise how Pip feels.
struct PipWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PausPip", provider: StatusProvider()) { entry in
            PipWidgetView(entry: entry)
        }
        .configurationDisplayName("Pip")
        .description(L("Pip med en nedräkning medan något är blockerat, och hur det går för dig."))
        .supportedFamilies([.systemMedium, .systemSmall])
    }
}

private struct PipWidgetView: View {
    let entry: StatusEntry
    @Environment(\.widgetFamily) private var family

    private var status: PausStatus { entry.status }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Spacer(minLength: 0)
                headline
                    .font(.system(size: family == .systemSmall ? 30 : 40, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Text(subline)
                    .font(.system(size: family == .systemSmall ? 14 : 18, weight: .semibold, design: .rounded))
                    .opacity(0.9)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            if family != .systemSmall {
                WidgetPip(mood: entry.mood, level: entry.level)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 6)
            }
        }
        .containerBackground(background, for: .widget)
    }

    @ViewBuilder
    private var headline: some View {
        if let left = status.stepsLeft {
            Text(Format.number(left))
        } else if let range = status.countdown(from: entry.date) {
            Text(timerInterval: range, countsDown: true)
        } else if entry.health < 40 {
            Text("\(entry.health) %")
        } else if !entry.activeToday {
            Text(L("Pip väntar"))
        } else if entry.streak >= 2 {
            Text(L("\(entry.streak) dagar"))
        } else {
            Text(L("Nivå \(entry.level)"))
        }
    }

    private var subline: String {
        if status.stepsLeft != nil { return L("steg kvar tills apparna låses upp") }
        if status.countdown(from: entry.date) != nil {
            switch status.kind {
            case .focus: return L("kvar av fokuspasset")
            case .pause: return L("kvar av pausen")
            default: return L("tills apparna låses upp")
            }
        }
        if entry.health < 40 { return L("Pip mår dåligt. Ett fokuspass hjälper.") }
        if !entry.activeToday { return entry.streak > 0 ? L("Rädda din streak i dag") : L("på att du ska fokusera") }
        if entry.streak >= 2 { return L("i rad. Pip är stolt!") }
        return Level.title(for: entry.level)
    }

    private var background: LinearGradient {
        let colors: [Color]
        if status.isBlocking || status.kind == .pause {
            colors = status.kind == .focus
                ? [Color(red: 0.36, green: 0.22, blue: 0.9), Color(red: 0.2, green: 0.45, blue: 1)]
                : [Palette.pink, Palette.violet]
        } else if entry.health < 40 || !entry.activeToday {
            colors = [Color(red: 0.32, green: 0.36, blue: 0.5), Color(red: 0.5, green: 0.56, blue: 0.7)]
        } else {
            colors = [Color(red: 0.1, green: 0.55, blue: 0.95), Color(red: 0.4, green: 0.88, blue: 1)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - The journey widget

/// The road from the first level to Legend, with Pip standing on the player's level.
struct JourneyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PausJourney", provider: StatusProvider()) { entry in
            JourneyWidgetView(entry: entry)
        }
        .configurationDisplayName(L("Din resa"))
        .description(L("Vägen från scrollzombie till Legend, och hur långt du har kommit."))
        .supportedFamilies([.systemLarge])
    }
}

private struct JourneyWidgetView: View {
    let entry: StatusEntry

    private let levels = Array(1...10)

    var body: some View {
        let current = min(entry.level, 10)
        let next = Level.xpRequired(for: current + 1)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(L("Din resa"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                Spacer()
                Text(current < 10 ? L("\(Format.number(max(0, next - entry.xp))) XP till nivå \(current + 1)") : "Legend 🏆")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.mint)
                    .contentTransition(.numericText())
            }
            GeometryReader { proxy in
                let points = levels.map { point(for: $0, in: proxy.size) }
                ZStack(alignment: .topLeading) {
                    road(points, upTo: current)
                    ForEach(levels, id: \.self) { level in
                        node(level, current: current, at: points[level - 1], width: proxy.size.width)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .containerBackground(
            LinearGradient(colors: [Color(red: 0.2, green: 0.1, blue: 0.4), Color(red: 0.08, green: 0.05, blue: 0.18), Color(red: 0.3, green: 0.08, blue: 0.3)],
                           startPoint: .top, endPoint: .bottom),
            for: .widget
        )
    }

    /// Level 1 at the bottom, Legend at the top, zigzagging like a mountain road.
    private func point(for level: Int, in size: CGSize) -> CGPoint {
        let zigzag: [CGFloat] = [0.62, 0.68, 0.58, 0.44, 0.34, 0.42, 0.56, 0.64, 0.6, 0.5]
        let y = size.height - 16 - CGFloat(level - 1) * (size.height - 40) / 9
        return CGPoint(x: size.width * zigzag[level - 1], y: y)
    }

    private func road(_ points: [CGPoint], upTo current: Int) -> some View {
        ZStack {
            Path { path in path.addLines(points) }
                .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            Path { path in path.addLines(Array(points.prefix(current))) }
                .stroke(LinearGradient(colors: [Palette.pink, Palette.violet], startPoint: .bottom, endPoint: .top),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
    }

    @ViewBuilder
    private func node(_ level: Int, current: Int, at point: CGPoint, width: CGFloat) -> some View {
        let reached = level <= current
        let labelOnLeft = point.x > width * 0.5
        ZStack {
            if level == current {
                WidgetPip(mood: entry.mood, level: entry.level)
                    .frame(width: 40, height: 40)
                    .shadow(color: Palette.mint.opacity(0.7), radius: 8)
            } else if level == 10 {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.3), Palette.orange], startPoint: .top, endPoint: .bottom))
            } else {
                Circle()
                    .fill(reached ? AnyShapeStyle(LinearGradient(colors: [Palette.pink, Palette.violet], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.12)))
                    .overlay(Circle().stroke(Color.white.opacity(reached ? 0.6 : 0.25), lineWidth: 1.5))
                    .frame(width: 22, height: 22)
                    .overlay(Text("\(level)").font(.system(size: 11, weight: .black, design: .rounded)))
            }
        }
        .position(point)
        VStack(alignment: labelOnLeft ? .trailing : .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(Level.title(for: level))
                    .font(.system(size: 11, weight: level == current ? .black : .semibold, design: .rounded))
                if level == current {
                    Text(L("DU"))
                        .font(.system(size: 8, weight: .black))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Palette.mint, in: Capsule())
                        .foregroundStyle(Color.black)
                }
            }
            Text("\(Format.number(Level.xpRequired(for: level))) XP")
                .font(.system(size: 8, weight: .semibold))
                .opacity(0.6)
        }
        .opacity(reached || level == current + 1 ? 1 : 0.55)
        .fixedSize()
        .frame(width: 130, alignment: labelOnLeft ? .trailing : .leading)
        .position(x: labelOnLeft ? point.x - 92 : point.x + 92, y: point.y)
    }
}
