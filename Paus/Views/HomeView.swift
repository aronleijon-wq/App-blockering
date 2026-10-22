import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var isHealthInfoPresented = false

    private let focusLengths = [25, 50, 90]

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ScrollView {
                    VStack(spacing: 16) {
                        hero(at: context.date)
                        if !model.hasSelection {
                            setupCard
                        }
                        dailyRewardCard(at: context.date)
                        if model.hasSelection {
                            statusCard(at: context.date)
                            focusCard(at: context.date)
                        }
                        ScreenTimeCard()
                        questsCard(at: context.date)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .task(id: focusHasEnded(at: context.date)) {
                    // Pick up the XP once the monitor has settled a finished session.
                    guard focusHasEnded(at: context.date) else { return }
                    try? await Task.sleep(for: .seconds(2))
                    model.reload()
                }
            }
            .screenBackground()
            .navigationTitle("Paus")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    StreakPill(streak: model.progress.currentStreak(at: .now, calendar: .current))
                }
            }
        }
    }

    private func focusHasEnded(at date: Date) -> Bool {
        guard let end = model.runtime.focusEndsAt else { return false }
        return end <= date
    }

    // MARK: Hero

    private func hero(at date: Date) -> some View {
        let progress = model.progress
        let level = progress.level
        let levelStart = Level.xpRequired(for: level)
        let levelEnd = Level.xpRequired(for: level + 1)
        return VStack(spacing: 14) {
            MascotView(mood: model.mood, level: level, size: 160)
                .padding(.top, 8)

            if !model.coachMessage.isEmpty {
                Text(model.coachMessage)
                    .font(.callout.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .top) {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.cardRaised)
                            .offset(y: -9)
                            .accessibilityHidden(true)
                    }
                    .contentTransition(.opacity)
            }

            Button {
                isHealthInfoPresented = true
            } label: {
                HealthBar(health: progress.health)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isHealthInfoPresented) {
                PipHealthSheet()
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Nivå \(level)")
                        .font(.headline)
                    Text(Level.title(for: level))
                        .font(.headline)
                        .foregroundStyle(Theme.brand)
                    Spacer()
                    Text("\(progress.xp - levelStart) / \(levelEnd - levelStart) XP")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                GradientBar(fraction: Level.fraction(forXP: progress.xp), height: 12)
                    .accessibilityLabel("\(progress.xp - levelStart) av \(levelEnd - levelStart) XP till nästa nivå")
            }
        }
        .card(highlighted: true)
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Välj vad Pip ska vakta", systemImage: "square.grid.2x2.fill")
                .font(.headline)
            Text("Börja med apparna som tar mest av din tid, till exempel TikTok, Instagram och YouTube.")
                .foregroundStyle(.secondary)
            Button("Välj appar") { model.selectedTab = .apps }
                .buttonStyle(GlowButtonStyle())
                .padding(.top, 4)
        }
        .card()
    }

    // MARK: Daily reward

    @ViewBuilder
    private func dailyRewardCard(at date: Date) -> some View {
        let progress = model.progress
        if progress.canClaimDailyReward(at: date, calendar: .current) {
            Button {
                model.claimDailyReward()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "gift.fill")
                        .font(.title)
                        .symbolEffect(.pulse)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Öppna dagens belöning")
                            .font(.headline)
                        Text("+\(progress.dailyRewardXP(at: date, calendar: .current)) XP och din streak fortsätter")
                            .font(.subheadline)
                            .opacity(0.85)
                    }
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(18)
                .background(Theme.brand, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: Theme.pink.opacity(0.4), radius: 16, y: 8)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: progress.lastRewardDay)
        } else {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(Theme.mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dagens belöning är hämtad")
                        .font(.headline)
                    Text("Nästa om \(Format.countdown(to: Calendar.current.startOfDay(for: date).addingTimeInterval(86_400), from: date))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .card()
        }
    }

    // MARK: Status

    @ViewBuilder
    private func statusCard(at date: Date) -> some View {
        let engine = model.engine
        if let reason = engine.reason(at: date) {
            let isStrictFocus: Bool = {
                if case .focus = reason { return model.isStrictFocusActive }
                return false
            }()
            VStack(alignment: .leading, spacing: 12) {
                if engine.shouldShield(at: date) {
                    StatusRow(symbol: "lock.fill", tint: Theme.pink, title: "Blockerat just nu", detail: Format.reason(reason))
                    if model.rules.pause.isEnabled && !isStrictFocus {
                        Button {
                            model.isPauseSheetPresented = true
                        } label: {
                            let penalty = model.progress.nextPausePenalty(at: date, calendar: .current)
                            Label(
                                penalty == 0 ? "Ta en paus på \(model.rules.pause.minutes) min (gratis)" : "Ta en paus (−\(penalty) poäng)",
                                systemImage: "cup.and.saucer.fill"
                            )
                        }
                        .buttonStyle(ChipButtonStyle())
                        .disabled(!engine.canPause(at: date))
                        Text("\(engine.pausesLeft(at: date)) av \(model.rules.pause.maxPerDay) pauser kvar idag")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let pausedUntil = model.runtime.pausedUntil {
                    StatusRow(
                        symbol: "cup.and.saucer.fill",
                        tint: Theme.orange,
                        title: "Paus – \(Format.countdown(to: pausedUntil, from: date)) kvar",
                        detail: "Sedan blockeras apparna igen."
                    )
                    Button("Avsluta pausen nu") { model.endPause() }
                        .buttonStyle(ChipButtonStyle())
                }
            }
            .card()
        }
    }

    // MARK: Focus

    private func focusCard(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let end = model.runtime.focusEndsAt, end > date, let start = model.runtime.focusStartedAt {
                let total = end.timeIntervalSince(start)
                let done = total > 0 ? date.timeIntervalSince(start) / total : 0
                HStack(spacing: 18) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: done)
                            .stroke(Theme.glow, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(Format.countdown(to: end, from: date))
                            .font(.headline.monospacedDigit())
                    }
                    .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fokus pågår")
                            .font(.title3.bold())
                        Text("Klart \(Format.time(end)). Du får \(Int((total / 60).rounded()) + PlayerProgress.XP.focusBonus) XP.")
                            .foregroundStyle(.secondary)
                        if model.isStrictFocusActive {
                            Label("Strikt fokus", systemImage: "lock.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.pink)
                        } else {
                            Button("Avsluta utan XP", role: .destructive) { model.stopFocus() }
                                .font(.subheadline)
                        }
                    }
                }
            } else {
                Text("Fokuspass")
                    .font(.title3.bold())
                Text("Blockera apparna direkt. 1 XP per minut + \(PlayerProgress.XP.focusBonus) i bonus.")
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(focusLengths, id: \.self) { minutes in
                        Button {
                            model.startFocus(minutes: minutes)
                        } label: {
                            Text(Format.minutes(minutes))
                        }
                        .buttonStyle(ChipButtonStyle())
                        .accessibilityLabel("Starta fokus i \(Format.minutes(minutes))")
                    }
                }
            }
        }
        .card()
    }

    // MARK: Quests

    private func questsCard(at date: Date) -> some View {
        let counts = model.progress.counts(at: date, calendar: .current)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Dagens uppdrag")
                    .font(.title3.bold())
                Spacer()
                Text("\(counts.completedQuests.count)/3")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.brand)
            }
            ForEach(Quest.daily(for: DayKey.string(for: date, calendar: .current))) { quest in
                QuestRow(quest: quest, progress: quest.progress(in: counts), isDone: counts.completedQuests.contains(quest.id))
            }
        }
        .card()
    }
}

private struct QuestRow: View {
    let quest: Quest
    let progress: Int
    let isDone: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(isDone ? AnyShapeStyle(Theme.glow) : AnyShapeStyle(Theme.cardRaised))
                Image(systemName: isDone ? "checkmark" : quest.symbol)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 6) {
                Text(quest.title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(isDone, color: .secondary)
                GradientBar(fraction: Double(min(progress, quest.target)) / Double(quest.target), height: 6)
            }
            Text("+\(quest.xp)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(isDone ? Theme.mint : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? "Klart" : "\(min(progress, quest.target)) av \(quest.target)")
    }
}

struct StatusRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .monospacedDigit()
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct StreakPill: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(streak > 0 ? Theme.flame : .secondary)
                .symbolEffect(.pulse, isActive: streak > 0)
            Text("\(streak)")
                .font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.cardRaised, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak: \(streak) dagar")
    }
}
