import SwiftUI

/// Breathing countdown that has to finish before a pause can start.
struct PauseView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date.now

    /// One full breath: in for half, out for half.
    private let breathSeconds = 8.0

    var body: some View {
        NavigationStack {
            Group {
                if model.engine.canPause(at: .now) {
                    TimelineView(.animation) { context in
                        content(elapsed: context.date.timeIntervalSince(startedAt))
                    }
                } else {
                    ContentUnavailableView(
                        "Ingen paus just nu",
                        systemImage: "cup.and.saucer",
                        description: Text("Antingen är inget blockerat, pauserna för idag är slut eller så pågår ett strikt fokuspass.")
                    )
                }
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") { dismiss() }
                }
            }
        }
    }

    private func content(elapsed: TimeInterval) -> some View {
        let remaining = max(0, Int((Double(model.rules.pause.waitSeconds) - elapsed).rounded(.up)))
        let isBreathingIn = elapsed.truncatingRemainder(dividingBy: breathSeconds) < breathSeconds / 2
        let phase = elapsed.truncatingRemainder(dividingBy: breathSeconds) / breathSeconds
        let scale = reduceMotion ? 0.8 : 0.55 + 0.45 * (1 - cos(phase * 2 * .pi)) / 2

        return VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.violet.opacity(0.18))
                Circle()
                    .fill(Theme.glow)
                    .opacity(0.55)
                    .scaleEffect(scale)
                MascotView(mood: .zen, level: model.progress.level, size: 120)
            }
            .frame(width: 240, height: 240)
            .accessibilityHidden(true)

            if remaining > 0 {
                Text(isBreathingIn ? "Andas in…" : "Andas ut…")
                    .font(.title2.weight(.semibold))
                Text("\(remaining)")
                    .font(.largeTitle.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(remaining) sekunder kvar")
            } else {
                Text("Vill du fortfarande ta en paus?")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Under pausen kan du öppna de blockerade apparna i \(model.rules.pause.minutes) minuter. \(model.engine.pausesLeft(at: .now)) av \(model.rules.pause.maxPerDay) pauser kvar idag. Tackar du nej får du +\(PlayerProgress.XP.decline) XP.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            VStack(spacing: 12) {
                Button("Nej tack, jag klarar mig (+\(PlayerProgress.XP.decline) XP)") {
                    dismiss()
                    model.declinePause()
                }
                .buttonStyle(GlowButtonStyle())

                Button("Pausa i \(model.rules.pause.minutes) min") {
                    model.takePause()
                    dismiss()
                }
                .buttonStyle(ChipButtonStyle())
                .disabled(remaining > 0)
            }
        }
        .padding(24)
    }
}
