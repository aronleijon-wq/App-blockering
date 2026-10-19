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
                    .fill(Color.accentColor.opacity(0.15))
                Circle()
                    .fill(Color.accentColor.opacity(0.45))
                    .scaleEffect(scale)
            }
            .frame(width: 220, height: 220)
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
                Text("Under pausen kan du öppna de blockerade apparna i \(model.rules.pause.minutes) minuter. \(model.engine.pausesLeft(at: .now)) av \(model.rules.pause.maxPerDay) pauser kvar idag.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            VStack(spacing: 12) {
                Button {
                    model.takePause()
                    dismiss()
                } label: {
                    Text("Pausa i \(model.rules.pause.minutes) min")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(remaining > 0)

                Button("Nej tack, jag klarar mig") { dismiss() }
                    .controlSize(.large)
            }
        }
        .padding(24)
    }
}
