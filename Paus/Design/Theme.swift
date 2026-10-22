import SwiftUI

/// Colors and shared styles. The app always runs in dark mode so the gradients read the same everywhere.
enum Theme {
    static let background = Color(red: 0.055, green: 0.043, blue: 0.122)
    static let card = Color(red: 0.106, green: 0.086, blue: 0.212)
    static let cardRaised = Color(red: 0.149, green: 0.122, blue: 0.282)
    static let violet = Color(red: 0.545, green: 0.361, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.31, blue: 0.64)
    static let orange = Color(red: 1.0, green: 0.71, blue: 0.28)
    static let mint = Color(red: 0.235, green: 0.94, blue: 0.69)
    static let flame = Color(red: 1.0, green: 0.55, blue: 0.2)

    static let brand = LinearGradient(colors: [violet, pink, orange], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let glow = LinearGradient(colors: [violet, pink], startPoint: .leading, endPoint: .trailing)
    static let backdrop = LinearGradient(
        colors: [Color(red: 0.13, green: 0.07, blue: 0.27), background, background],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct CardModifier: ViewModifier {
    var highlighted = false

    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(highlighted ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Color.white.opacity(0.08)), lineWidth: highlighted ? 2 : 1)
            }
    }
}

extension View {
    func card(highlighted: Bool = false) -> some View {
        modifier(CardModifier(highlighted: highlighted))
    }

    /// The shared dark gradient behind every screen.
    func screenBackground() -> some View {
        background(Theme.backdrop.ignoresSafeArea())
    }
}

/// Gradient pill for the main action on a screen.
struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GlowButtonBody(configuration: configuration)
    }

    private struct GlowButtonBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 15)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(Theme.glow, in: Capsule())
                .shadow(color: Theme.pink.opacity(isEnabled ? 0.45 : 0), radius: 14, y: 6)
                .opacity(isEnabled ? 1 : 0.4)
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.spring(duration: 0.25), value: configuration.isPressed)
        }
    }
}

/// Dark rounded chip for secondary choices.
struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.violet.opacity(0.6), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Thin gradient bar for XP and quest progress.
struct GradientBar: View {
    var fraction: Double
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(Theme.glow)
                    .frame(width: max(height, proxy.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.6), value: fraction)
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.glow, in: Capsule())
            .accessibilityLabel(L("Kräver Pro"))
    }
}
