import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Ta tillbaka din tid")
                        .font(.largeTitle.bold())
                    Text("Paus blockerar apparna som stjäl din uppmärksamhet – när du vill, enligt schema eller när dagens tid är slut.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(symbol: "scope", title: "Fokuspass", text: "Blockera sociala medier direkt i 25, 50 eller 90 minuter.")
                    FeatureRow(symbol: "calendar", title: "Scheman", text: "Blockera automatiskt under skoldagen eller på kvällen.")
                    FeatureRow(symbol: "hourglass", title: "Daglig gräns", text: "Bestäm hur länge du får scrolla per dag.")
                    FeatureRow(symbol: "wind", title: "Medvetna pauser", text: "Måste du ändå in? Andas en stund först, sedan får du en kort paus.")
                }

                Text("Paus använder Apples Skärmtid. Paus ser bara anonyma symboler för apparna du väljer, och ingenting om vad du gör lämnar telefonen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if model.authorizationStatus == .denied {
                    Text("Paus har inte fått tillgång till Skärmtid. Tryck på knappen igen, eller tillåt Paus under Inställningar > Skärmtid.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    isRequesting = true
                    await model.requestAuthorization()
                    isRequesting = false
                }
            } label: {
                Text("Kom igång")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRequesting)
            .padding(24)
            .background(.bar)
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
    }
}
