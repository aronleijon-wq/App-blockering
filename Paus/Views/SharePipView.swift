import SwiftUI

/// Pip as a picture to post: Pip in its outfit, the streak, the level and the time taken back, sized for a story.
struct SharePipSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var image: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                card
                    .frame(width: 252, height: 448)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Theme.pink.opacity(0.4), radius: 22)
                    .padding(.top, 10)
                if let image {
                    ShareLink(item: image, preview: SharePreview(L("Min Pip i Paus"), image: image)) {
                        Label(L("Dela"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.horizontal, 40)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .screenBackground()
            .navigationTitle(L("Dela din Pip"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Klar")) { dismiss() }
                }
            }
        }
        .task { image = render() }
    }

    private var card: PipShareCard {
        let progress = model.progress
        return PipShareCard(
            name: model.league.nickname ?? model.firstName,
            outfit: progress.outfit,
            level: progress.level,
            streak: progress.currentStreak(at: .now, calendar: .current),
            hours: progress.focusMinutes / 60,
            eggs: progress.eggsHatchedCount
        )
    }

    @MainActor
    private func render() -> Image? {
        let renderer = ImageRenderer(content: card.frame(width: 360, height: 640))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// The picture itself.
struct PipShareCard: View {
    let name: String?
    let outfit: Outfit
    let level: Int
    let streak: Int
    let hours: Int
    let eggs: Int

    var body: some View {
        let colors = MascotView.bodyColors(level: level, outfit: outfit)
        ZStack {
            LinearGradient(colors: [Theme.background] + colors.map { $0.opacity(0.75) }, startPoint: .top, endPoint: .bottom)
            VStack(spacing: 14) {
                Text(name.map { L("\($0)S PIP").uppercased() } ?? L("MIN PIP"))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .padding(.top, 34)
                Spacer(minLength: 0)
                PipAvatar(outfit: outfit, level: level, size: 150)
                    .frame(width: 210, height: 210)
                Text(Level.title(for: level))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(L("Nivå \(level)"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .opacity(0.85)
                HStack(spacing: 10) {
                    stat("🔥 \(streak)", L("dagar i rad"))
                    stat("\(hours) h", L("i fokus"))
                    stat("🥚 \(eggs)", L("ägg"))
                }
                .padding(.horizontal, 18)
                Spacer(minLength: 0)
                Text(L("Ta tillbaka din tid · Paus"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .opacity(0.9)
                    .padding(.bottom, 26)
            }
            .foregroundStyle(.white)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .opacity(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
