import SwiftUI

/// Over everything while this version is older than the oldest still allowed in.
struct UpdateRequiredView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            MascotView(mood: .hyped, level: 1, size: 150, outfit: .none)
            Text(L("Dags att uppdatera Paus"))
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(L("Den här versionen är för gammal för ligan och dina framsteg. Uppdatera för att fortsätta, det tar bara en minut."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button(L("Uppdatera i App Store")) { openURL(AppUpdateChecker.storeURL) }
                .buttonStyle(GlowButtonStyle())
                .padding(.horizontal, 30)
            Text(L("Dina blockeringar fortsätter fungera under tiden."))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }
}

/// On the home screen when a newer version is out, until updated or waved away for that version.
struct UpdateCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @AppStorage("update.dismissedVersion") private var dismissedVersion = ""

    var body: some View {
        if case .optional(let latest) = model.updateNeed, dismissedVersion != latest {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Theme.mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Paus \(latest) är här"))
                        .font(.headline)
                    Text(L("Nya funktioner väntar. Uppdatera i App Store."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                VStack(spacing: 6) {
                    Button(L("Uppdatera")) { openURL(AppUpdateChecker.storeURL) }
                        .buttonStyle(ChipButtonStyle())
                    Button(L("Senare")) { dismissedVersion = latest }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .card(highlighted: true)
        }
    }
}
