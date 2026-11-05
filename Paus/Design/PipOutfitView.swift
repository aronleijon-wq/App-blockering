import SwiftUI

/// Draws one wardrobe item where it sits on Pip, sized for a Pip `size` points wide. `time` drives the items that move
/// (flames, wings, a fluttering headband); it stays 0 in the wardrobe grid, where the items stand still.
struct PipItemView: View {
    let id: String
    let size: CGFloat
    var time: Double = 0

    var body: some View {
        switch id {
        case "hat-cap": cap
        case "hat-flower": flower
        case "hat-beanie": beanie
        case "hat-party": partyHat
        case "hat-chef": chefHat
        case "hat-crown": crown
        case "hat-headphones": headphones
        case "hat-ninja": headband
        case "hat-devil": devilHorns
        case "hat-viking": vikingHelmet
        case "hat-wizard": wizardHat
        case "hat-halo": halo
        case "hat-fire": fireHair
        case "hat-santa": santaHat
        case "hat-cat": catEars
        case "hat-bunny": bunnyEars
        case "hat-cowboy": cowboyHat
        case "hat-grad": gradCap
        case "hat-pirate": pirateHat
        case "hat-tiara": tiara
        case "hat-bucket": bucketHat
        case "glasses-round": roundGlasses
        case "glasses-sun": sunglasses
        case "glasses-heart": heartGlasses
        case "glasses-3d": glasses3D
        case "glasses-star": starGlasses
        case "glasses-pixel": pixelShades
        case "glasses-visor": visor
        case "glasses-gold": goldGlasses
        case "glasses-monocle": monocle
        case "glasses-ski": skiGoggles
        case "glasses-laser": laserEyes
        case "glasses-aviator": aviators
        case "neck-scarf": scarf
        case "neck-bow": bowTie
        case "neck-medal": medal
        case "neck-tie": tie
        case "neck-lei": lei
        case "neck-chain": goldChain
        case "neck-iron-medal": ironMedal
        case "neck-bandana": bandana
        case "neck-diamond": diamondChain
        case "back-cape": cape
        case "back-bat": wings(angel: false)
        case "back-wings": wings(angel: true)
        case "back-jetpack": jetpack
        case "back-guitar": guitar
        case "back-dragon": dragonWings
        case "back-skateboard": skateboard
        default: EmptyView()
        }
    }

    /// How far a form's outline reaches per unit, as a share of Pip's size: between the animated Pip's 0.43 and the
    /// still one's 0.5.
    static let formScale: CGFloat = 0.45

    /// Where an item of `kind` sits on Pip, from Pip's center. Hats sit on top of the head and things for the neck
    /// at the bottom, wherever `form` puts them.
    static func offset(for kind: WardrobeItem.Kind, size: CGFloat, form: PipForm = .round) -> CGSize {
        switch kind {
        case .hat:
            let lift = CGFloat(form.hatShift) * formScale
            return CGSize(width: 0, height: size * (lift - 0.42))
        case .glasses: return CGSize(width: 0, height: -size * 0.07)
        case .neck:
            let drop = CGFloat(form.neckShift) * formScale
            return CGSize(width: 0, height: size * (0.38 + drop))
        case .back, .color, .shirt, .shape: return .zero
        }
    }

    private static let gold = LinearGradient(colors: [Color(red: 1, green: 0.9, blue: 0.45), Color(red: 0.85, green: 0.6, blue: 0.15)],
                                             startPoint: .top, endPoint: .bottom)
    private static let flame = LinearGradient(colors: [Color(red: 1, green: 0.96, blue: 0.5), Color(red: 1, green: 0.6, blue: 0.2), Color(red: 1, green: 0.25, blue: 0.2)],
                                              startPoint: .bottom, endPoint: .top)

    // MARK: Hats

    private var cap: some View {
        ZStack {
            Ellipse()
                .trim(from: 0.5, to: 1)
                .fill(Color(red: 0.95, green: 0.25, blue: 0.3))
                .frame(width: size * 0.52, height: size * 0.4)
                .offset(y: size * 0.1)
            Capsule()
                .fill(Color(red: 0.8, green: 0.15, blue: 0.22))
                .frame(width: size * 0.36, height: size * 0.07)
                .offset(x: size * 0.2, y: size * 0.1)
            Circle()
                .fill(Color(red: 0.8, green: 0.15, blue: 0.22))
                .frame(width: size * 0.06)
                .offset(y: -size * 0.1)
        }
    }

    private var flower: some View {
        Image(systemName: "camera.macro")
            .font(.system(size: size * 0.2, weight: .bold))
            .foregroundStyle(Theme.pink)
            .rotationEffect(.degrees(-18))
            .offset(x: size * 0.16, y: size * 0.04)
    }

    private var beanie: some View {
        ZStack {
            Ellipse()
                .trim(from: 0.5, to: 1)
                .fill(Color(red: 0.25, green: 0.45, blue: 0.95))
                .frame(width: size * 0.56, height: size * 0.46)
                .offset(y: size * 0.12)
            Capsule()
                .fill(Color(red: 0.18, green: 0.32, blue: 0.75))
                .frame(width: size * 0.58, height: size * 0.09)
                .offset(y: size * 0.12)
            Circle()
                .fill(.white)
                .frame(width: size * 0.12)
                .offset(y: -size * 0.12)
        }
    }

    private var partyHat: some View {
        ZStack {
            Triangle()
                .fill(LinearGradient(colors: [Theme.violet, Theme.pink, Theme.orange], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.3, height: size * 0.36)
            Circle()
                .fill(Color(red: 1, green: 0.88, blue: 0.3))
                .frame(width: size * 0.09)
                .offset(y: -size * 0.18)
        }
        .rotationEffect(.degrees(12))
        .offset(y: -size * 0.02)
    }

    private var chefHat: some View {
        ZStack {
            HStack(spacing: -size * 0.06) {
                Circle().frame(width: size * 0.2)
                Circle().frame(width: size * 0.26).offset(y: -size * 0.04)
                Circle().frame(width: size * 0.2)
            }
            .foregroundStyle(.white)
            .offset(y: -size * 0.04)
            RoundedRectangle(cornerRadius: size * 0.02, style: .continuous)
                .fill(.white)
                .frame(width: size * 0.4, height: size * 0.12)
                .offset(y: size * 0.1)
        }
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }

    private var crown: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: size * 0.24))
            .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.3), Theme.orange], startPoint: .top, endPoint: .bottom))
            .shadow(color: Theme.orange.opacity(0.6), radius: 6)
    }

    /// Over-ear headphones: a band over the top and a cup on each side.
    private var headphones: some View {
        let band = Color(red: 0.16, green: 0.14, blue: 0.3)
        return ZStack {
            Circle()
                .trim(from: 0.53, to: 0.97)
                .stroke(band, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                .frame(width: size * 1.0, height: size * 1.0)
                .offset(y: size * 0.4)
            headphoneCup(side: -1, band: band)
            headphoneCup(side: 1, band: band)
        }
    }

    private func headphoneCup(side: CGFloat, band: Color) -> some View {
        let inner: CGFloat = -side * size * 0.075
        let shineX: CGFloat = side * size * 0.02
        let x: CGFloat = side * size * 0.49
        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.07, style: .continuous)
                .fill(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.17, height: size * 0.27)
            RoundedRectangle(cornerRadius: size * 0.04, style: .continuous)
                .fill(band)
                .frame(width: size * 0.06, height: size * 0.2)
                .offset(x: inner)
            Circle()
                .fill(.white.opacity(0.35))
                .frame(width: size * 0.05)
                .offset(x: shineX, y: -size * 0.06)
        }
        .offset(x: x, y: size * 0.38)
    }

    /// A red ninja headband across the forehead, its tails fluttering.
    private var headband: some View {
        let red = Color(red: 0.92, green: 0.15, blue: 0.22)
        let flutter = sin(time * 6) * 9
        return ZStack {
            Capsule()
                .fill(red)
                .frame(width: size * 0.88, height: size * 0.09)
            RoundedRectangle(cornerRadius: size * 0.015, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.95), Color(white: 0.7)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.16, height: size * 0.065)
            Capsule()
                .fill(red)
                .frame(width: size * 0.26, height: size * 0.05)
                .rotationEffect(.degrees(18 + flutter), anchor: .leading)
                .offset(x: size * 0.54, y: size * 0.02)
            Capsule()
                .fill(Color(red: 0.8, green: 0.1, blue: 0.18))
                .frame(width: size * 0.22, height: size * 0.045)
                .rotationEffect(.degrees(42 - flutter), anchor: .leading)
                .offset(x: size * 0.52, y: size * 0.03)
        }
        .offset(y: size * 0.15)
    }

    private var devilHorns: some View {
        let red = LinearGradient(colors: [Color(red: 1, green: 0.32, blue: 0.3), Color(red: 0.7, green: 0.05, blue: 0.15)], startPoint: .top, endPoint: .bottom)
        return HStack(spacing: size * 0.24) {
            Triangle().fill(red).frame(width: size * 0.12, height: size * 0.17).rotationEffect(.degrees(-20))
            Triangle().fill(red).frame(width: size * 0.12, height: size * 0.17).rotationEffect(.degrees(20))
        }
        .offset(y: size * 0.07)
    }

    private var vikingHelmet: some View {
        let bone = Color(red: 0.98, green: 0.94, blue: 0.84)
        let leather = Color(red: 0.72, green: 0.5, blue: 0.28)
        return ZStack {
            Horn().fill(bone).frame(width: size * 0.2, height: size * 0.3).offset(x: -size * 0.34, y: -size * 0.04)
            Horn().fill(bone).frame(width: size * 0.2, height: size * 0.3).scaleEffect(x: -1, y: 1).offset(x: size * 0.34, y: -size * 0.04)
            Ellipse()
                .trim(from: 0.5, to: 1)
                .fill(LinearGradient(colors: [Color(white: 0.9), Color(white: 0.55)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.62, height: size * 0.5)
                .offset(y: size * 0.13)
            Capsule().fill(leather).frame(width: size * 0.66, height: size * 0.08).offset(y: size * 0.13)
            Capsule().fill(leather).frame(width: size * 0.06, height: size * 0.24).offset(y: size * 0.01)
            HStack(spacing: size * 0.17) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(Color(white: 0.95)).frame(width: size * 0.03)
                }
            }
            .offset(y: size * 0.13)
        }
    }

    private var santaHat: some View {
        let red = Color(red: 0.88, green: 0.12, blue: 0.2)
        return ZStack {
            WizardCone()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.3, blue: 0.3), red], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.42, height: size * 0.46)
                .rotationEffect(.degrees(14))
                .offset(x: size * 0.04, y: -size * 0.12)
            Capsule()
                .fill(.white)
                .frame(width: size * 0.62, height: size * 0.12)
                .offset(y: size * 0.09)
            Circle()
                .fill(.white)
                .frame(width: size * 0.12)
                .offset(x: size * 0.17, y: -size * 0.32)
        }
    }

    private var catEars: some View {
        let fur = Color(red: 0.35, green: 0.3, blue: 0.4)
        return HStack(spacing: size * 0.2) {
            ForEach([-1.0, 1.0], id: \.self) { side in
                ZStack {
                    Triangle().fill(fur).frame(width: size * 0.2, height: size * 0.2)
                    Triangle().fill(Theme.pink.opacity(0.85)).frame(width: size * 0.1, height: size * 0.1).offset(y: size * 0.03)
                }
                .rotationEffect(.degrees(side * 14))
            }
        }
        .offset(y: size * 0.02)
    }

    private var bunnyEars: some View {
        let twitch: Double = sin(time * 2.5) * 4
        return HStack(spacing: size * 0.1) {
            ForEach([-1.0, 1.0], id: \.self) { side in
                ZStack {
                    Capsule().fill(.white).frame(width: size * 0.13, height: size * 0.36)
                    Capsule().fill(Color(red: 1, green: 0.7, blue: 0.8)).frame(width: size * 0.06, height: size * 0.26)
                }
                .rotationEffect(.degrees(side * 12 + side * twitch), anchor: .bottom)
            }
        }
        .offset(y: -size * 0.08)
    }

    private var cowboyHat: some View {
        let brown = Color(red: 0.6, green: 0.38, blue: 0.2)
        let dark = Color(red: 0.42, green: 0.25, blue: 0.12)
        return ZStack {
            Ellipse().fill(dark).frame(width: size * 0.82, height: size * 0.16).offset(y: size * 0.1)
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(LinearGradient(colors: [brown, dark], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.42, height: size * 0.26)
                .offset(y: -size * 0.02)
            Capsule().fill(Color(red: 0.2, green: 0.12, blue: 0.08)).frame(width: size * 0.43, height: size * 0.05).offset(y: size * 0.06)
        }
    }

    private var gradCap: some View {
        let swing: Double = sin(time * 3) * 8
        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.03).fill(Color(white: 0.12)).frame(width: size * 0.34, height: size * 0.14).offset(y: size * 0.08)
            Rectangle().fill(Color(white: 0.18)).frame(width: size * 0.42, height: size * 0.42)
                .rotationEffect(.degrees(45)).scaleEffect(x: 1, y: 0.32).offset(y: -size * 0.01)
            VStack(spacing: 0) {
                Rectangle().fill(Color(red: 1, green: 0.82, blue: 0.3)).frame(width: size * 0.012, height: size * 0.16)
                Capsule().fill(Color(red: 1, green: 0.82, blue: 0.3)).frame(width: size * 0.05, height: size * 0.06)
            }
            .rotationEffect(.degrees(swing), anchor: .top)
            .offset(x: size * 0.17, y: size * 0.08)
        }
    }

    private var pirateHat: some View {
        let black = Color(white: 0.1)
        return ZStack {
            Ellipse().trim(from: 0.5, to: 1).fill(black).frame(width: size * 0.74, height: size * 0.46).offset(y: size * 0.12)
            Capsule().fill(Color(red: 1, green: 0.82, blue: 0.3)).frame(width: size * 0.66, height: size * 0.03).offset(y: size * 0.12)
            ZStack {
                Circle().fill(.white).frame(width: size * 0.11)
                HStack(spacing: size * 0.02) {
                    Circle().fill(black).frame(width: size * 0.03)
                    Circle().fill(black).frame(width: size * 0.03)
                }
            }
            .offset(y: -size * 0.02)
        }
    }

    private var tiara: some View {
        let sparkle: Double = 0.75 + 0.25 * sin(time * 5)
        return ZStack {
            Image(systemName: "crown.fill")
                .font(.system(size: size * 0.2))
                .foregroundStyle(LinearGradient(colors: [Color(white: 0.98), Color(red: 0.75, green: 0.8, blue: 0.9)], startPoint: .top, endPoint: .bottom))
                .scaleEffect(x: 1.3, y: 0.8)
            Image(systemName: "diamond.fill")
                .font(.system(size: size * 0.08))
                .foregroundStyle(Theme.pink)
                .opacity(sparkle)
                .offset(y: -size * 0.01)
        }
        .shadow(color: Theme.pink.opacity(0.5), radius: size * 0.03)
        .offset(y: size * 0.06)
    }

    private var wizardHat: some View {
        let deep = Color(red: 0.25, green: 0.12, blue: 0.6)
        let star = Color(red: 1, green: 0.88, blue: 0.3)
        return ZStack {
            WizardCone()
                .fill(LinearGradient(colors: [Color(red: 0.5, green: 0.3, blue: 1), deep], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.42, height: size * 0.52)
                .offset(y: -size * 0.17)
            Ellipse()
                .fill(deep)
                .frame(width: size * 0.7, height: size * 0.13)
                .offset(y: size * 0.09)
            Capsule()
                .fill(Theme.orange)
                .frame(width: size * 0.4, height: size * 0.05)
                .offset(y: size * 0.04)
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.08))
                .foregroundStyle(star)
                .offset(x: -size * 0.05, y: -size * 0.12)
            Image(systemName: "moon.fill")
                .font(.system(size: size * 0.065))
                .foregroundStyle(star)
                .offset(x: size * 0.06, y: -size * 0.25)
        }
    }

    /// A glowing ring floating above Pip.
    private var halo: some View {
        let glow = Color(red: 1, green: 0.85, blue: 0.3)
        let bob: CGFloat = CGFloat(sin(time * 2.4)) * 0.025
        let y: CGFloat = size * (bob - 0.1)
        return Ellipse()
            .stroke(Color(red: 1, green: 0.93, blue: 0.55), lineWidth: size * 0.045)
            .frame(width: size * 0.44, height: size * 0.12)
            .shadow(color: glow, radius: size * 0.04)
            .shadow(color: glow.opacity(0.6), radius: size * 0.1)
            .offset(y: y)
    }

    /// Flames for hair, flickering.
    private var fireHair: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                flame(i)
            }
        }
        .shadow(color: Theme.orange.opacity(0.75), radius: size * 0.05)
    }

    private func flame(_ i: Int) -> some View {
        let height: CGFloat = size * flameHeight(i)
        let flicker: CGFloat = 1 + 0.16 * CGFloat(sin(time * 9 + Double(i) * 1.7))
        let x: CGFloat = size * CGFloat(i - 2) * 0.1
        let y: CGFloat = size * 0.12 - height / 2
        return FlameShape()
            .fill(Self.flame)
            .frame(width: size * 0.17, height: height)
            .scaleEffect(x: 1, y: flicker, anchor: .bottom)
            .offset(x: x, y: y)
    }

    private func flameHeight(_ i: Int) -> CGFloat {
        switch i {
        case 2: return 0.36
        case 1, 3: return 0.29
        default: return 0.21
        }
    }

    private var bucketHat: some View {
        let cloth = Color(red: 0.14, green: 0.15, blue: 0.2)
        return ZStack {
            Ellipse()
                .fill(Color(red: 0.22, green: 0.23, blue: 0.3))
                .frame(width: size * 0.66, height: size * 0.17)
                .overlay {
                    Ellipse()
                        .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: size * 0.008, dash: [size * 0.02, size * 0.015]))
                        .padding(size * 0.02)
                }
                .offset(y: size * 0.12)
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .fill(cloth)
                .frame(width: size * 0.44, height: size * 0.27)
                .offset(y: -size * 0.01)
            Rectangle()
                .fill(Color.white.opacity(0.85))
                .frame(width: size * 0.44, height: size * 0.035)
                .offset(y: size * 0.08)
        }
    }

    // MARK: Glasses

    private func glasses<Lens: View>(@ViewBuilder lens: () -> Lens) -> some View {
        HStack(spacing: size * 0.04) {
            lens()
            Capsule().fill(Color.black.opacity(0.8)).frame(width: size * 0.06, height: size * 0.025)
            lens()
        }
    }

    private var roundGlasses: some View {
        glasses {
            Circle()
                .stroke(Color.black.opacity(0.8), lineWidth: size * 0.025)
                .frame(width: size * 0.22)
        }
    }

    private var goldGlasses: some View {
        glasses {
            Circle()
                .stroke(Self.gold, lineWidth: size * 0.03)
                .frame(width: size * 0.22)
        }
    }

    private var monocle: some View {
        ZStack {
            Circle().stroke(Self.gold, lineWidth: size * 0.025).frame(width: size * 0.23)
            Circle().fill(Color.white.opacity(0.15)).frame(width: size * 0.21)
            Path { path in
                path.move(to: CGPoint(x: size * 0.1, y: size * 0.04))
                path.addQuadCurve(to: CGPoint(x: size * 0.16, y: size * 0.3), control: CGPoint(x: size * 0.22, y: size * 0.14))
            }
            .stroke(Self.gold, lineWidth: size * 0.01)
        }
        .frame(width: size * 0.23, height: size * 0.23)
        .offset(x: size * 0.13)
    }

    private var skiGoggles: some View {
        ZStack {
            Capsule().fill(Color(white: 0.15)).frame(width: size * 0.86, height: size * 0.07)
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(LinearGradient(colors: [Theme.orange, Theme.pink, Theme.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.6, height: size * 0.2)
                .overlay(RoundedRectangle(cornerRadius: size * 0.08, style: .continuous).stroke(Color(white: 0.95), lineWidth: size * 0.02))
            Capsule().fill(Color.white.opacity(0.5)).frame(width: size * 0.2, height: size * 0.03).offset(x: -size * 0.12, y: -size * 0.05)
        }
    }

    private var laserEyes: some View {
        let pulse: CGFloat = 0.7 + 0.3 * CGFloat(sin(time * 9))
        let red = Color(red: 1, green: 0.15, blue: 0.2)
        return HStack(spacing: size * 0.2) {
            ForEach([-1.0, 1.0], id: \.self) { side in
                ZStack {
                    Capsule()
                        .fill(LinearGradient(colors: [red, red.opacity(0)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: size * 0.5 * pulse, height: size * 0.04)
                        .offset(x: size * 0.25 * pulse * CGFloat(side))
                        .scaleEffect(x: CGFloat(side), y: 1)
                    Circle().fill(red).frame(width: size * 0.12).blur(radius: size * 0.01)
                    Circle().fill(.white).frame(width: size * 0.05)
                }
            }
        }
        .shadow(color: red, radius: size * 0.05 * pulse)
    }

    private var sunglasses: some View {
        glasses {
            RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                .fill(Color.black.opacity(0.85))
                .frame(width: size * 0.24, height: size * 0.16)
        }
    }

    private var heartGlasses: some View {
        glasses {
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.2))
                .foregroundStyle(Theme.pink)
        }
    }

    private var glasses3D: some View {
        HStack(spacing: size * 0.05) {
            RoundedRectangle(cornerRadius: size * 0.02, style: .continuous)
                .fill(Color(red: 1, green: 0.2, blue: 0.25).opacity(0.85))
                .frame(width: size * 0.22, height: size * 0.15)
            RoundedRectangle(cornerRadius: size * 0.02, style: .continuous)
                .fill(Color(red: 0.2, green: 0.85, blue: 1).opacity(0.85))
                .frame(width: size * 0.22, height: size * 0.15)
        }
        .padding(size * 0.025)
        .background(RoundedRectangle(cornerRadius: size * 0.035, style: .continuous).fill(.white))
    }

    private var starGlasses: some View {
        glasses {
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.24))
                .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.92, blue: 0.35), Theme.orange], startPoint: .top, endPoint: .bottom))
                .overlay {
                    Image(systemName: "star")
                        .font(.system(size: size * 0.24))
                        .foregroundStyle(.white.opacity(0.6))
                }
        }
    }

    /// 8-bit shades: a bar on top and two lenses that step in towards the bottom, with white pixels for shine.
    private static let pixelRows = [
        "111111111111111111111111",
        "011221111110011221111110",
        "011211111110011211111110",
        "001111111100001111111100",
        "000111111000000111111000",
    ]

    private var pixelShades: some View {
        Canvas { context, canvas in
            let px = canvas.width / 24
            for (y, row) in Self.pixelRows.enumerated() {
                for (x, c) in row.enumerated() where c != "0" {
                    let rect = CGRect(x: CGFloat(x) * px, y: CGFloat(y) * px, width: px + 0.5, height: px + 0.5)
                    context.fill(Path(rect), with: .color(c == "2" ? .white : .black))
                }
            }
        }
        .frame(width: size * 0.76, height: size * 0.76 / 24 * 5)
        .offset(y: size * 0.02)
    }

    /// A neon visor with a shine sweeping across it.
    private var visor: some View {
        let cyan = Color(red: 0.2, green: 0.95, blue: 1)
        let sweep: CGFloat = CGFloat((time * 0.6).truncatingRemainder(dividingBy: 1))
        let sweepX: CGFloat = size * (sweep - 0.5)
        return ZStack {
            Capsule()
                .fill(LinearGradient(colors: [cyan, Theme.violet, Theme.pink], startPoint: .leading, endPoint: .trailing))
                .opacity(0.92)
            Capsule()
                .fill(LinearGradient(colors: [.clear, .white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: size * 0.14)
                .offset(x: sweepX)
            Capsule()
                .stroke(.white.opacity(0.7), lineWidth: size * 0.012)
        }
        .frame(width: size * 0.82, height: size * 0.2)
        .clipShape(Capsule())
        .shadow(color: cyan.opacity(0.8), radius: size * 0.05)
    }

    private var aviators: some View {
        let tint = LinearGradient(colors: [Color(red: 0.45, green: 0.62, blue: 0.55), Color(red: 0.08, green: 0.12, blue: 0.12)],
                                  startPoint: .top, endPoint: .bottom)
        return HStack(spacing: size * 0.05) {
            aviatorLens(tint)
                .scaleEffect(x: -1, y: 1)
            aviatorLens(tint)
        }
        .overlay {
            Capsule()
                .fill(Self.gold)
                .frame(width: size * 0.1, height: size * 0.018)
                .offset(y: -size * 0.075)
        }
    }

    private func aviatorLens(_ tint: LinearGradient) -> some View {
        AviatorLens()
            .fill(tint)
            .overlay {
                AviatorLens().stroke(Self.gold, lineWidth: size * 0.018)
            }
            .frame(width: size * 0.25, height: size * 0.21)
    }

    // MARK: Neck

    private var scarf: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.95, green: 0.3, blue: 0.3))
                .frame(width: size * 0.6, height: size * 0.11)
            RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                .fill(Color(red: 0.85, green: 0.22, blue: 0.25))
                .frame(width: size * 0.1, height: size * 0.2)
                .rotationEffect(.degrees(-10))
                .offset(x: size * 0.16, y: size * 0.1)
        }
    }

    private var bowTie: some View {
        HStack(spacing: 0) {
            Triangle().fill(Theme.pink).frame(width: size * 0.14, height: size * 0.12).rotationEffect(.degrees(90))
            Circle().fill(Color(red: 0.85, green: 0.2, blue: 0.5)).frame(width: size * 0.06)
            Triangle().fill(Theme.pink).frame(width: size * 0.14, height: size * 0.12).rotationEffect(.degrees(-90))
        }
    }

    private var medal: some View {
        VStack(spacing: -size * 0.02) {
            Triangle()
                .fill(Theme.violet)
                .frame(width: size * 0.16, height: size * 0.1)
                .rotationEffect(.degrees(180))
            ZStack {
                Circle().fill(Color(red: 1, green: 0.82, blue: 0.3)).frame(width: size * 0.14)
                Image(systemName: "star.fill")
                    .font(.system(size: size * 0.07))
                    .foregroundStyle(Theme.orange)
            }
        }
        .offset(y: size * 0.04)
    }

    /// The NNN season's medal: steel with a violet ribbon and a flame.
    private var ironMedal: some View {
        VStack(spacing: -size * 0.02) {
            Triangle()
                .fill(Color(red: 0.35, green: 0.2, blue: 0.75))
                .frame(width: size * 0.16, height: size * 0.1)
                .rotationEffect(.degrees(180))
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 0.88, green: 0.9, blue: 0.95), Color(red: 0.5, green: 0.55, blue: 0.65)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: size * 0.15)
                Image(systemName: "flame.fill")
                    .font(.system(size: size * 0.075))
                    .foregroundStyle(Color(red: 0.35, green: 0.2, blue: 0.75))
            }
        }
        .offset(y: size * 0.04)
    }

    private var bandana: some View {
        ZStack {
            Triangle()
                .fill(LinearGradient(colors: [Color(red: 0.9, green: 0.18, blue: 0.22), Color(red: 0.65, green: 0.08, blue: 0.14)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.4, height: size * 0.2)
                .rotationEffect(.degrees(180))
            HStack(spacing: size * 0.06) {
                ForEach(0..<3, id: \.self) { _ in Circle().fill(.white.opacity(0.85)).frame(width: size * 0.025) }
            }
            .offset(y: -size * 0.03)
        }
        .offset(y: size * 0.02)
    }

    private var diamondChain: some View {
        let sparkle: Double = 0.8 + 0.2 * sin(time * 6)
        return VStack(spacing: -size * 0.01) {
            Circle()
                .trim(from: 0.08, to: 0.42)
                .stroke(Color(white: 0.92), style: StrokeStyle(lineWidth: size * 0.02, dash: [size * 0.02, size * 0.01]))
                .frame(width: size * 0.5, height: size * 0.5)
                .frame(height: size * 0.12, alignment: .bottom)
                .clipped()
            Image(systemName: "diamond.fill")
                .font(.system(size: size * 0.12))
                .foregroundStyle(LinearGradient(colors: [.white, Color(red: 0.55, green: 0.9, blue: 1)], startPoint: .top, endPoint: .bottom))
                .scaleEffect(CGFloat(sparkle))
                .shadow(color: Color(red: 0.55, green: 0.9, blue: 1), radius: size * 0.04)
        }
    }

    private var tie: some View {
        VStack(spacing: -size * 0.01) {
            Triangle()
                .fill(Color(red: 0.2, green: 0.3, blue: 0.85))
                .frame(width: size * 0.1, height: size * 0.05)
                .rotationEffect(.degrees(180))
            TieShape()
                .fill(LinearGradient(colors: [Color(red: 0.3, green: 0.45, blue: 1), Color(red: 0.15, green: 0.22, blue: 0.7)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.12, height: size * 0.15)
        }
    }

    /// A ring of flowers.
    private static let leiColors: [Color] = [Theme.pink, Theme.orange, Color(red: 1, green: 0.88, blue: 0.3), Theme.mint, Theme.violet]

    private var lei: some View {
        ZStack {
            ForEach(0..<9, id: \.self) { i in
                leiFlower(i)
            }
        }
    }

    private func leiFlower(_ i: Int) -> some View {
        let angle: Double = Double.pi * (0.08 + 0.84 * Double(i) / 8)
        let x: CGFloat = size * 0.3 * CGFloat(cos(angle))
        let y: CGFloat = size * (0.12 * CGFloat(sin(angle)) - 0.07)
        return Image(systemName: "camera.macro")
            .font(.system(size: size * 0.09, weight: .bold))
            .foregroundStyle(Self.leiColors[i % Self.leiColors.count])
            .offset(x: x, y: y)
    }

    private var goldChain: some View {
        ZStack {
            Circle()
                .trim(from: 0.08, to: 0.42)
                .stroke(Self.gold, style: StrokeStyle(lineWidth: size * 0.03, lineCap: .round, dash: [size * 0.035, size * 0.012]))
                .frame(width: size * 0.62, height: size * 0.62)
                .offset(y: -size * 0.33)
            ZStack {
                Circle().fill(Self.gold).frame(width: size * 0.16)
                Text(verbatim: "P")
                    .font(.system(size: size * 0.1, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.62, green: 0.42, blue: 0.05))
            }
            .shadow(color: Color(red: 1, green: 0.85, blue: 0.3).opacity(0.8), radius: size * 0.03)
            .offset(y: -size * 0.02)
        }
    }

    // MARK: Back, drawn behind Pip

    private var cape: some View {
        let wave: CGFloat = CGFloat(sin(time * 3)) * size * 0.03
        return CapeShape(wave: wave)
            .fill(LinearGradient(colors: [Color(red: 0.95, green: 0.15, blue: 0.25), Color(red: 0.6, green: 0.05, blue: 0.15)], startPoint: .top, endPoint: .bottom))
            .frame(width: size * 1.25, height: size * 0.95)
            .offset(y: size * 0.12)
    }

    private func wings(angel: Bool) -> some View {
        let speed: Double = angel ? 4 : 5
        let flap: Double = sin(time * speed) * 10
        let fill = angel
            ? LinearGradient(colors: [.white, Color(red: 0.85, green: 0.9, blue: 1)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color(red: 0.45, green: 0.2, blue: 0.7), Color(red: 0.2, green: 0.08, blue: 0.35)], startPoint: .top, endPoint: .bottom)
        return ZStack {
            WingShape(spiky: !angel)
                .fill(fill)
                .frame(width: size * 0.52, height: size * 0.6)
                .rotationEffect(.degrees(-flap), anchor: .trailing)
                .offset(x: -size * 0.5, y: -size * 0.06)
            WingShape(spiky: !angel)
                .fill(fill)
                .frame(width: size * 0.52, height: size * 0.6)
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(flap), anchor: .leading)
                .offset(x: size * 0.5, y: -size * 0.06)
        }
        .shadow(color: angel ? .white.opacity(0.6) : Theme.violet.opacity(0.5), radius: size * 0.04)
    }

    private var guitar: some View {
        let wood = Color(red: 0.85, green: 0.45, blue: 0.2)
        return ZStack {
            Rectangle().fill(Color(red: 0.3, green: 0.18, blue: 0.1)).frame(width: size * 0.06, height: size * 0.6).offset(y: -size * 0.32)
            RoundedRectangle(cornerRadius: size * 0.02).fill(Color(red: 0.3, green: 0.18, blue: 0.1)).frame(width: size * 0.1, height: size * 0.08).offset(y: -size * 0.62)
            Ellipse().fill(wood).frame(width: size * 0.3, height: size * 0.24).offset(y: -size * 0.04)
            Ellipse().fill(wood).frame(width: size * 0.36, height: size * 0.3).offset(y: size * 0.16)
            Circle().fill(Color(red: 0.25, green: 0.12, blue: 0.06)).frame(width: size * 0.09).offset(y: size * 0.06)
        }
        .rotationEffect(.degrees(-35))
        .offset(x: size * 0.42, y: -size * 0.02)
    }

    private var skateboard: some View {
        let deck = LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .leading, endPoint: .trailing)
        return ZStack {
            Capsule()
                .fill(deck)
                .frame(width: size * 1.25, height: size * 0.3)
            Capsule()
                .fill(Color.white.opacity(0.85))
                .frame(width: size * 0.9, height: size * 0.05)
            skateWheels(at: -1)
            skateWheels(at: 1)
        }
        .rotationEffect(.degrees(-50))
    }

    private func skateWheels(at end: CGFloat) -> some View {
        VStack(spacing: size * 0.12) {
            Circle().fill(Color(white: 0.95)).frame(width: size * 0.09)
            Circle().fill(Color(white: 0.95)).frame(width: size * 0.09)
        }
        .offset(x: end * size * 0.5)
    }

    private var dragonWings: some View {
        let flap: Double = sin(time * 3) * 14
        let fill = LinearGradient(colors: [Color(red: 0.95, green: 0.3, blue: 0.2), Color(red: 0.45, green: 0.05, blue: 0.1)], startPoint: .top, endPoint: .bottom)
        return ZStack {
            WingShape(spiky: true)
                .fill(fill)
                .frame(width: size * 0.66, height: size * 0.72)
                .rotationEffect(.degrees(-flap), anchor: .trailing)
                .offset(x: -size * 0.56, y: -size * 0.1)
            WingShape(spiky: true)
                .fill(fill)
                .frame(width: size * 0.66, height: size * 0.72)
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(flap), anchor: .leading)
                .offset(x: size * 0.56, y: -size * 0.1)
        }
        .shadow(color: Theme.orange.opacity(0.6), radius: size * 0.05)
    }

    private var jetpack: some View {
        ZStack {
            jetpackTank(side: -1)
            jetpackTank(side: 1)
        }
        .shadow(color: Theme.orange.opacity(0.5), radius: size * 0.04)
    }

    private func jetpackTank(side: CGFloat) -> some View {
        let flicker: CGFloat = 1 + 0.25 * CGFloat(sin(time * 20))
        let x: CGFloat = side * size * 0.47
        return ZStack {
            FlameShape()
                .fill(Self.flame)
                .frame(width: size * 0.13, height: size * 0.3)
                .rotationEffect(.degrees(180))
                .scaleEffect(x: 1, y: flicker, anchor: .top)
                .offset(y: size * 0.32)
            RoundedRectangle(cornerRadius: size * 0.07, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.9), Color(white: 0.5)], startPoint: .leading, endPoint: .trailing))
                .frame(width: size * 0.19, height: size * 0.44)
            Capsule()
                .fill(Theme.pink)
                .frame(width: size * 0.19, height: size * 0.05)
                .offset(y: -size * 0.1)
        }
        .offset(x: x, y: size * 0.04)
    }
}

/// Pip's body colors for a color item, or nil for Pip's own colors.
enum PipColors {
    static func colors(for id: String?) -> [Color]? {
        switch id {
        case "color-mint": return [Theme.mint, Color(red: 0.2, green: 0.75, blue: 0.95)]
        case "color-ocean": return [Color(red: 0.2, green: 0.5, blue: 1), Color(red: 0.3, green: 0.85, blue: 0.95)]
        case "color-sunset": return [Theme.orange, Theme.pink]
        case "color-lava": return [Color(red: 1, green: 0.3, blue: 0.2), Theme.orange]
        case "color-galaxy": return [Theme.violet, Color(red: 0.2, green: 0.1, blue: 0.5)]
        case "color-gold": return [Color(red: 1, green: 0.88, blue: 0.35), Theme.orange]
        case "color-ice": return [Color(red: 0.93, green: 0.98, blue: 1), Color(red: 0.55, green: 0.8, blue: 1)]
        case "color-candy": return [Color(red: 1, green: 0.6, blue: 0.85), Color(red: 0.6, green: 0.8, blue: 1)]
        case "color-toxic": return [Color(red: 0.78, green: 1, blue: 0.2), Color(red: 0.1, green: 0.7, blue: 0.3)]
        case "color-neon": return [Color(red: 0.2, green: 0.95, blue: 1), Color(red: 1, green: 0.2, blue: 0.85)]
        case "color-midnight": return [Color(red: 0.16, green: 0.13, blue: 0.42), Color(red: 0.48, green: 0.22, blue: 0.92)]
        case "color-shadow": return [Color(red: 0.3, green: 0.3, blue: 0.36), Color(red: 0.06, green: 0.06, blue: 0.1)]
        case "color-ruby": return [Color(red: 1, green: 0.35, blue: 0.5), Color(red: 0.6, green: 0.02, blue: 0.18)]
        case "color-emerald": return [Color(red: 0.4, green: 1, blue: 0.6), Color(red: 0.02, green: 0.5, blue: 0.3)]
        case "color-rainbow":
            return [Color(red: 1, green: 0.3, blue: 0.3), Color(red: 1, green: 0.7, blue: 0.2), Color(red: 1, green: 0.95, blue: 0.3),
                    Color(red: 0.3, green: 0.9, blue: 0.5), Color(red: 0.3, green: 0.6, blue: 1), Color(red: 0.7, green: 0.4, blue: 1)]
        case "color-iron": return [Color(red: 0.62, green: 0.66, blue: 0.75), Color(red: 0.36, green: 0.22, blue: 0.78)]
        case "color-frost": return [Color(red: 0.88, green: 0.96, blue: 1), Color(red: 0.42, green: 0.62, blue: 1)]
        case "color-dawn": return [Color(red: 1, green: 0.8, blue: 0.6), Color(red: 0.72, green: 0.55, blue: 1)]
        default: return nil
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// An aviator lens: flat on top, round below and deepest near the nose, which is on the left. Mirror it for the
/// other eye.
struct AviatorLens: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let start = CGPoint(x: r.minX, y: r.minY + r.height * 0.08)
        p.move(to: start)
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.02),
                       control: CGPoint(x: r.midX, y: r.minY - r.height * 0.04))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.45, y: r.maxY),
                       control: CGPoint(x: r.maxX + r.width * 0.02, y: r.maxY - r.height * 0.05))
        p.addQuadCurve(to: start, control: CGPoint(x: r.minX - r.width * 0.02, y: r.maxY - r.height * 0.1))
        p.closeSubpath()
        return p
    }
}

/// A cone whose tip bends over to the right.
struct WizardCone: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.08),
                       control: CGPoint(x: r.midX - r.width * 0.05, y: r.minY + r.height * 0.05))
        p.addQuadCurve(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.maxY),
                       control: CGPoint(x: r.midX + r.width * 0.12, y: r.midY))
        p.closeSubpath()
        return p
    }
}

/// A horn curving up and out from its base at the bottom right.
struct Horn: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.15, y: r.minY), control: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.45),
                       control: CGPoint(x: r.minX + r.width * 0.4, y: r.midY + r.height * 0.1))
        p.closeSubpath()
        return p
    }
}

/// A flame: a point on top, a round bottom.
struct FlameShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let radius = r.width / 2
        let center = CGPoint(x: r.midX, y: r.maxY - radius)
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: center.y), control: CGPoint(x: r.maxX, y: r.midY))
        p.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

/// A tie: narrow under the knot, widest low down, then a point.
struct TieShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX - r.width * 0.25, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.25, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.2))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.2))
        p.closeSubpath()
        return p
    }
}

/// A cape hanging from Pip's shoulders, its hem waving with `wave`.
struct CapeShape: Shape {
    var wave: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX - r.width * 0.22, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.22, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY + wave), control: CGPoint(x: r.maxX - r.width * 0.05, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.06 - wave),
                       control: CGPoint(x: r.midX + r.width * 0.25, y: r.maxY + r.height * 0.05 + wave))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY + wave),
                       control: CGPoint(x: r.midX - r.width * 0.25, y: r.maxY + r.height * 0.05 - wave))
        p.addQuadCurve(to: CGPoint(x: r.midX - r.width * 0.22, y: r.minY), control: CGPoint(x: r.minX + r.width * 0.05, y: r.midY))
        p.closeSubpath()
        return p
    }
}

/// A left wing attached at its right edge: feathered (round scallops) or bat-like (`spiky`, pointed scallops).
struct WingShape: Shape {
    var spiky = false

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.3))
        let tip = CGPoint(x: r.minX, y: r.minY + r.height * 0.05)
        p.addQuadCurve(to: tip, control: CGPoint(x: r.midX, y: r.minY - r.height * 0.05))
        let points = [
            CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.42),
            CGPoint(x: r.minX + r.width * 0.35, y: r.minY + r.height * 0.66),
            CGPoint(x: r.minX + r.width * 0.62, y: r.minY + r.height * 0.84),
            CGPoint(x: r.maxX, y: r.maxY - r.height * 0.05),
        ]
        var previous = tip
        for point in points {
            let control: CGPoint
            if spiky {
                let cx: CGFloat = max(previous.x, point.x) - r.width * 0.02
                let cy: CGFloat = min(previous.y, point.y) + r.height * 0.02
                control = CGPoint(x: cx, y: cy)
            } else {
                let cx: CGFloat = min(previous.x, point.x) - r.width * 0.06
                let cy: CGFloat = max(previous.y, point.y) + r.height * 0.06
                control = CGPoint(x: cx, y: cy)
            }
            p.addQuadCurve(to: point, control: control)
            previous = point
        }
        p.closeSubpath()
        return p
    }
}
