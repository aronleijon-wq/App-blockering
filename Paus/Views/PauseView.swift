import SwiftUI

/// The way past a block: first say why, then breathe with a few questions while the cost is shown,
/// then choose. Saying no is rewarded; pausing anyway costs league points after the first pause of the day.
struct PauseView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reason: PauseReason?
    @State private var startedAt = Date.now
    @State private var questionOffset = Int.random(in: 0..<ReflectionQuestions.all.count)

    /// One full breath: in for half, out for half.
    private let breathSeconds = 8.0

    var body: some View {
        NavigationStack {
            Group {
                if !model.engine.canPause(at: .now) {
                    ContentUnavailableView(
                        "Ingen paus just nu",
                        systemImage: "cup.and.saucer",
                        description: Text("Antingen är inget blockerat, pauserna för idag är slut eller så pågår ett strikt fokuspass.")
                    )
                } else if let reason {
                    TimelineView(.animation) { context in
                        breathing(reason: reason, elapsed: context.date.timeIntervalSince(startedAt))
                    }
                } else {
                    reasonPicker
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

    // MARK: Step 1: why?

    private var reasonPicker: some View {
        ScrollView {
            VStack(spacing: 20) {
                MascotView(mood: .happy, level: model.progress.level, size: 110)
                    .padding(.top, 8)
                Text("Varför vill du öppna appen?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("Var ärlig, det är bara du som ser svaret.")
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(PauseReason.allCases) { option in
                        Button {
                            choose(option)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: option.symbol)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 38, height: 38)
                                    .background(Theme.glow, in: Circle())
                                Text(option.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                costCard
            }
            .padding(20)
        }
    }

    private func choose(_ option: PauseReason) {
        model.recordPauseReason(option)
        startedAt = .now
        withAnimation(.spring(duration: 0.4)) { reason = option }
    }

    // MARK: Step 2: breathe and decide

    private func breathing(reason: PauseReason, elapsed: TimeInterval) -> some View {
        let wait = Double(model.rules.pause.waitSeconds) * (reason.isImpulse ? 1.5 : 1)
        let remaining = max(0, Int((wait - elapsed).rounded(.up)))
        let isBreathingIn = elapsed.truncatingRemainder(dividingBy: breathSeconds) < breathSeconds / 2
        let phase = elapsed.truncatingRemainder(dividingBy: breathSeconds) / breathSeconds
        let scale = reduceMotion ? 0.8 : 0.55 + 0.45 * (1 - cos(phase * 2 * .pi)) / 2

        return ScrollView {
            VStack(spacing: 20) {
                Text(reason.reply)
                    .font(.callout.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                ZStack {
                    Circle()
                        .fill(Theme.violet.opacity(0.18))
                    Circle()
                        .fill(Theme.glow)
                        .opacity(0.55)
                        .scaleEffect(scale)
                    MascotView(mood: .zen, level: model.progress.level, size: 110)
                }
                .frame(width: 220, height: 220)
                .accessibilityHidden(true)

                if remaining > 0 {
                    Text(isBreathingIn ? "Andas in…" : "Andas ut…")
                        .font(.title3.weight(.semibold))
                    Text(ReflectionQuestions.question(at: elapsed, offset: questionOffset))
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.brand)
                        .contentTransition(.opacity)
                        .animation(.easeInOut, value: Int(elapsed / 6))
                    Text("\(remaining)")
                        .font(.largeTitle.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(remaining) sekunder kvar")
                } else {
                    Text("Vill du fortfarande ta en paus?")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                }

                costCard

                VStack(spacing: 12) {
                    Button("Nej tack, jag klarar mig (+\(PlayerProgress.XP.decline) XP)") {
                        dismiss()
                        model.declinePause()
                    }
                    .buttonStyle(GlowButtonStyle())

                    Button(pauseButtonTitle) {
                        model.takePause()
                        dismiss()
                    }
                    .buttonStyle(ChipButtonStyle())
                    .disabled(remaining > 0)
                }
            }
            .padding(20)
        }
    }

    // MARK: Cost

    private var penalty: Int { model.progress.nextPausePenalty(at: .now, calendar: .current) }

    private var pauseButtonTitle: String {
        penalty == 0 ? "Pausa i \(model.rules.pause.minutes) min (gratis)" : "Pausa ändå (−\(penalty) XP och poäng)"
    }

    private var costCard: some View {
        let now = Date.now
        let points = model.progress.pointsThisWeek(at: now, calendar: .current)
        let pausesToday = model.progress.counts(at: now, calendar: .current).pauses
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: penalty == 0 ? "gift.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(penalty == 0 ? Theme.mint : Theme.orange)
                Text(penalty == 0 ? "Dagens första paus är gratis" : "Den här pausen kostar \(penalty) XP och \(penalty) veckopoäng")
                    .font(.headline)
            }
            if penalty > 0 {
                Text("Dina veckopoäng: \(points) → \(max(0, points - penalty)). Nästa paus kostar \(League.pausePenalty(forPause: pausesToday + 2)) XP och poäng. Du åker aldrig ner en nivå.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Nästa paus i dag kostar \(League.pausePenalty(forPause: 2)) XP och poäng. Tackar du nej får du +\(PlayerProgress.XP.decline) XP och +\(League.Points.decline) poäng.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            let healthCost = model.progress.nextPauseHealthCost(at: now, calendar: .current)
            Label("Pip tappar \(healthCost) i hälsa: \(model.progress.health) % → \(max(0, model.progress.health - healthCost)) %", systemImage: "heart.slash.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.pink)
            Text("Pauser i dag: \(pausesToday) av \(model.rules.pause.maxPerDay). Pausen varar \(model.rules.pause.minutes) min.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }
}
