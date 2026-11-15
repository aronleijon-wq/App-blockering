import SwiftUI

/// An egg: wider below, rounder on top.
struct EggShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.62),
                   control1: CGPoint(x: r.minX + w * 0.82, y: r.minY),
                   control2: CGPoint(x: r.maxX, y: r.minY + h * 0.32))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.minY + h * 0.88),
                   control2: CGPoint(x: r.minX + w * 0.78, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.62),
                   control1: CGPoint(x: r.minX + w * 0.22, y: r.maxY),
                   control2: CGPoint(x: r.minX, y: r.minY + h * 0.88))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.minX, y: r.minY + h * 0.32),
                   control2: CGPoint(x: r.minX + w * 0.18, y: r.minY))
        p.closeSubpath()
        return p
    }
}

/// A zigzag across an egg, for the crack.
struct CrackShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let y = r.midY
        let steps = 7
        p.move(to: CGPoint(x: r.minX, y: y))
        for step in 1...steps {
            let x = r.minX + r.width * CGFloat(step) / CGFloat(steps)
            p.addLine(to: CGPoint(x: x, y: y + (step % 2 == 0 ? -1 : 1) * r.height * 0.12))
        }
        return p
    }
}

enum EggStyle {
    static func colors(_ rarity: FocusEgg.Rarity?) -> [Color] {
        switch rarity {
        case .rare: return [Color(red: 0.55, green: 0.85, blue: 1), Color(red: 0.2, green: 0.45, blue: 1)]
        case .epic: return [Color(red: 0.85, green: 0.55, blue: 1), Color(red: 0.5, green: 0.2, blue: 0.95)]
        case .legendary: return [Color(red: 1, green: 0.95, blue: 0.55), Color(red: 1, green: 0.6, blue: 0.1)]
        default: return [Color(red: 0.98, green: 0.95, blue: 0.88), Color(red: 0.85, green: 0.78, blue: 0.68)]
        }
    }

    static func tint(_ rarity: FocusEgg.Rarity) -> Color { colors(rarity)[1] }
}

/// An egg with spots, in the colors of its rarity, or a mystery egg while it's still unknown.
struct EggView: View {
    var rarity: FocusEgg.Rarity?
    var cracked: Double = 0
    var size: CGFloat = 80

    var body: some View {
        let colors = rarity == nil ? [Color(red: 0.95, green: 0.9, blue: 1), Color(red: 0.62, green: 0.5, blue: 0.95)] : EggStyle.colors(rarity)
        ZStack {
            EggShape()
                .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            // Spots.
            Circle().fill(Color.white.opacity(0.35)).frame(width: size * 0.16).offset(x: -size * 0.14, y: -size * 0.18)
            Circle().fill(Color.white.opacity(0.25)).frame(width: size * 0.1).offset(x: size * 0.18, y: size * 0.05)
            Circle().fill(Color.white.opacity(0.2)).frame(width: size * 0.12).offset(x: -size * 0.06, y: size * 0.26)
            if cracked > 0 {
                CrackShape()
                    .trim(from: 0, to: min(1, cracked))
                    .stroke(Color.black.opacity(0.55), style: StrokeStyle(lineWidth: size * 0.03, lineCap: .round, lineJoin: .round))
                    .frame(width: size * 0.66, height: size * 0.5)
            }
        }
        .frame(width: size * 0.78, height: size)
        .shadow(color: colors[1].opacity(0.5), radius: size * 0.12)
        .accessibilityHidden(true)
    }
}

/// The egg a running focus session is keeping warm: it wobbles now and then and cracks as the session goes on.
struct IncubatingEgg: View {
    let fraction: Double
    let minutes: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let odds = FocusEgg.odds(minutes: minutes)
        HStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                // A little wobble every few seconds.
                let phase = time.truncatingRemainder(dividingBy: 3.5)
                let wobble: Double = phase < 0.5 ? sin(phase * 40) * 8 * (0.5 - phase) * 2 : 0
                EggView(cracked: fraction * 0.8, size: 62)
                    .rotationEffect(.degrees(wobble), anchor: .bottom)
            }
            .frame(width: 62, height: 66)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Ett fokusägg värms"))
                    .font(.headline)
                Text(minutes < FocusEgg.minMinutes ? L("Minst \(FocusEgg.minMinutes) minuter för att kläcka ett ägg.")
                     : L("Legendariskt: \(odds[3]) % · Episkt: \(odds[2]) %. Längre pass ger bättre ägg."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// An egg hatching: it shakes, cracks, bursts open and shows its rarity and what it held.
struct EggHatchView: View {
    let rarity: FocusEgg.Rarity
    let seeds: Int
    let item: String?
    @State private var stage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                if stage >= 3 {
                    // Rays behind the reveal.
                    ForEach(0..<12, id: \.self) { ray in
                        Capsule()
                            .fill(EggStyle.tint(rarity).opacity(0.35))
                            .frame(width: 8, height: 120)
                            .offset(y: -70)
                            .rotationEffect(.degrees(Double(ray) * 30))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                if stage < 3 {
                    TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || stage == 0)) { context in
                        let time = context.date.timeIntervalSinceReferenceDate
                        let shake: Double = stage >= 1 ? sin(time * 45) * Double(stage) * 6 : 0
                        EggView(rarity: stage >= 2 ? rarity : nil, cracked: stage >= 2 ? 1 : stage >= 1 ? 0.4 : 0, size: 150)
                            .rotationEffect(.degrees(shake), anchor: .bottom)
                    }
                    .transition(.scale(scale: 1.4).combined(with: .opacity))
                } else if let item, let wardrobe = WardrobeItem.with(id: item) {
                    PipAvatar(outfit: Outfit(wearing: wardrobe), level: 1, size: 96)
                        .frame(width: 150, height: 150)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                } else {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 76, weight: .bold))
                        .foregroundStyle(Theme.mint)
                        .frame(width: 150, height: 150)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .frame(height: 190)
            if stage >= 3 {
                VStack(spacing: 6) {
                    Text(L("\(rarity.name) ägg!").uppercased())
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: EggStyle.colors(rarity), startPoint: .top, endPoint: .bottom))
                    Label(L("+\(seeds) frön"), systemImage: "leaf.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.mint)
                    if let item, let wardrobe = WardrobeItem.with(id: item) {
                        Text(L("Ny sak till Pip: \(wardrobe.name)"))
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text(L("Ditt fokusägg kläcks…"))
                    .font(.title3.weight(.heavy))
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: stage)
        .task {
            for next in 1...3 {
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.2 : 0.8))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { stage = next }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L("\(rarity.name) ägg: +\(seeds) frön"))
    }
}
