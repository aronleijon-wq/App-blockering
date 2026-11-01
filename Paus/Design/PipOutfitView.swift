import SwiftUI

/// Draws one wardrobe item where it sits on Pip, sized for a Pip `size` points wide.
struct PipItemView: View {
    let id: String
    let size: CGFloat

    var body: some View {
        switch id {
        case "hat-cap": cap
        case "hat-flower": flower
        case "hat-beanie": beanie
        case "hat-party": partyHat
        case "hat-chef": chefHat
        case "hat-crown": crown
        case "glasses-round": roundGlasses
        case "glasses-sun": sunglasses
        case "glasses-heart": heartGlasses
        case "neck-scarf": scarf
        case "neck-bow": bowTie
        case "neck-medal": medal
        default: EmptyView()
        }
    }

    /// Where an item of `kind` sits on Pip, from Pip's center.
    static func offset(for kind: WardrobeItem.Kind, size: CGFloat) -> CGSize {
        switch kind {
        case .hat: return CGSize(width: 0, height: -size * 0.42)
        case .glasses: return CGSize(width: 0, height: -size * 0.07)
        case .neck: return CGSize(width: 0, height: size * 0.38)
        case .color: return .zero
        }
    }

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
