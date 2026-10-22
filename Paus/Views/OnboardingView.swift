import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                MascotView(mood: .happy, level: 1, size: 170)
                    .padding(.top, 24)

                VStack(spacing: 10) {
                    Text(model.firstName.map { "Sista steget, \($0)!" } ?? "Hej! Jag är Pip.")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.brand)
                    Text(model.hasFinishedIntro
                        ? "Ge mig tillgång till Skärmtid, så kan jag börja vakta dina appar."
                        : "Tillsammans tar vi tillbaka din tid från scrollandet. Varje gång du väljer bort TikTok blir jag lite starkare.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 18) {
                    FeatureRow(symbol: "scope", title: "Fokuspass", text: "Blockera sociala medier direkt och få XP för varje minut.")
                    FeatureRow(symbol: "flame.fill", title: "Streaks och belöningar", text: "Hämta dagens belöning och håll streaken vid liv.")
                    FeatureRow(symbol: "trophy.fill", title: "Nivåer och troféer", text: "Gå från Scrollzombie till Legend, och se Pip växa.")
                    FeatureRow(symbol: "wind", title: "Medvetna pauser", text: "Måste du ändå in? Andas först, sedan får du en kort paus.")
                }
                .card()

                Text("Paus använder Apples Skärmtid. Paus ser bara anonyma symboler för apparna du väljer, och ingenting om vad du gör lämnar telefonen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if model.authorizationStatus == .denied {
                    Text("Paus har inte fått tillgång till Skärmtid. Tryck på knappen igen, eller tillåt Paus under Inställningar > Skärmtid.")
                        .font(.footnote)
                        .foregroundStyle(Theme.pink)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    isRequesting = true
                    await model.requestAuthorization()
                    isRequesting = false
                }
            } label: {
                Text("Kom igång")
            }
            .buttonStyle(GlowButtonStyle())
            .disabled(isRequesting)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.background.opacity(0.9))
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Theme.glow, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
