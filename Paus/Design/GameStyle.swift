import SwiftUI

/// The bright, chunky look of the game screens: buttons and tiles with a thick edge below, like pieces you can press,
/// fat progress bars with the count inside, and section headers in small capitals.

/// A button with a darker edge under it that it sinks into when pressed.
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = Theme.mint
    var edge: Color = Color(red: 0.1, green: 0.62, blue: 0.45)
    var text: Color = Color(red: 0.05, green: 0.1, blue: 0.12)

    func makeBody(configuration: Configuration) -> some View {
        let depth: CGFloat = configuration.isPressed ? 1 : 5
        configuration.label
            .font(.headline.weight(.heavy))
            .textCase(.uppercase)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(edge, in: RoundedRectangle(cornerRadius: 16, style: .continuous).offset(y: depth))
            .offset(y: 5 - depth)
            .padding(.bottom, 5)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The outlined version: a dark button with a light rim, for the less important action.
struct ChunkyOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let depth: CGFloat = configuration.isPressed ? 1 : 4
        configuration.label
            .font(.headline.weight(.heavy))
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 2)
            }
            .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous).offset(y: depth))
            .offset(y: 4 - depth)
            .padding(.bottom, 4)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    /// A tile with a rim and a thick edge below it.
    func gameTile(rim: Color = Color.white.opacity(0.12)) -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(rim, lineWidth: 2)
            }
            .background(rim, in: RoundedRectangle(cornerRadius: 18, style: .continuous).offset(y: 4))
            .padding(.bottom, 4)
    }
}

/// A header in small capitals, with an optional timer on the right, like "DAILY QUESTS ⏱ 11 H".
struct GameSectionHeader: View {
    let title: String
    var timer: String?
    var tint: Color = .secondary

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.subheadline.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Spacer()
            if let timer {
                Label(timer.uppercased(), systemImage: "timer")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(tint)
            }
        }
    }
}

/// A fat progress bar with the count written inside it, like "3 / 5".
struct QuestBar: View {
    let value: Int
    let target: Int
    var fill: LinearGradient = LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.25), Theme.orange],
                                              startPoint: .top, endPoint: .bottom)
    /// Text shown instead of the count.
    var label: String?
    var height: CGFloat = 22

    private var fraction: Double {
        Double(min(value, target)) / Double(max(1, target))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                if fraction > 0 {
                    Capsule()
                        .fill(fill)
                        .frame(width: max(height, proxy.size.width * fraction))
                        .overlay(alignment: .top) {
                            // A shine along the top, like Duolingo's bars.
                            Capsule()
                                .fill(Color.white.opacity(0.35))
                                .frame(height: height * 0.22)
                                .padding(.horizontal, height * 0.4)
                                .padding(.top, height * 0.18)
                        }
                }
                Text(label ?? "\(min(value, target)) / \(target)")
                    .font(.system(size: height * 0.62, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.6), value: fraction)
    }
}

/// A chest beside a quest: shut and dim until the quest is done, then gold and open.
struct QuestChest: View {
    let isDone: Bool
    var tint: [Color] = [Color(red: 1, green: 0.88, blue: 0.35), Theme.orange]
    var size: CGFloat = 46

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: isDone ? "gift" : "gift.fill")
                .font(.system(size: size * 0.7, weight: .bold))
                .foregroundStyle(LinearGradient(colors: tint, startPoint: .top, endPoint: .bottom))
                .opacity(isDone ? 1 : 0.85)
                .frame(width: size, height: size)
                .shadow(color: tint.last?.opacity(isDone ? 0.7 : 0.3) ?? .clear, radius: isDone ? 10 : 4)
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(.white, Theme.mint)
            }
        }
        .accessibilityHidden(true)
    }
}
