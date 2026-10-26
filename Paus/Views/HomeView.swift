import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var isHealthInfoPresented = false
    @State private var isSettingsPresented = false
    @State private var isStopFocusConfirming = false
    /// The step goal waiting for the user to confirm, since a step session can't be undone.
    @State private var confirmingStepGoal: Int?

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
            .navigationTitle(model.firstName.map { L("Hej \($0)!") } ?? "Paus")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .accessibilityLabel(L("Konto och inställningar"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    StreakPill(streak: model.progress.currentStreak(at: .now, calendar: .current))
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
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
                    Text(L("Nivå \(level)"))
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
                    .accessibilityLabel(L("\(progress.xp - levelStart) av \(levelEnd - levelStart) XP till nästa nivå"))
            }
        }
        .card(highlighted: true)
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L("Välj vad Pip ska vakta"), systemImage: "square.grid.2x2.fill")
                .font(.headline)
            Text(L("Börja med apparna som tar mest av din tid, till exempel TikTok, Instagram och YouTube."))
                .foregroundStyle(.secondary)
            Button(L("Välj appar")) { model.selectedTab = .apps }
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
                        Text(L("Öppna dagens belöning"))
                            .font(.headline)
                        Text(L("+\(progress.dailyRewardXP(at: date, calendar: .current)) XP och din streak fortsätter"))
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
                    Text(L("Dagens belöning är hämtad"))
                        .font(.headline)
                    Text(L("Nästa om \(Format.countdown(to: Calendar.current.startOfDay(for: date).addingTimeInterval(86_400), from: date))"))
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
                switch reason {
                case .focus: return model.isStrictFocusActive
                case .stepFocus: return true
                default: return false
                }
            }()
            VStack(alignment: .leading, spacing: 12) {
                if engine.shouldShield(at: date) {
                    StatusRow(symbol: "lock.fill", tint: Theme.pink, title: L("Blockerat just nu"), detail: Format.reason(reason))
                    if model.rules.pause.isEnabled && !isStrictFocus {
                        Button {
                            model.isPauseSheetPresented = true
                        } label: {
                            let penalty = model.progress.nextPausePenalty(at: date, calendar: .current)
                            Label(
                                penalty == 0 ? L("Ta en paus på \(model.rules.pause.minutes) min (gratis)") : L("Ta en paus (−\(penalty) XP och poäng)"),
                                systemImage: "cup.and.saucer.fill"
                            )
                        }
                        .buttonStyle(ChipButtonStyle())
                        .disabled(!engine.canPause(at: date))
                        Text(L("\(engine.pausesLeft(at: date)) av \(model.rules.pause.maxPerDay) pauser kvar idag"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let pausedUntil = model.runtime.pausedUntil {
                    StatusRow(
                        symbol: "cup.and.saucer.fill",
                        tint: Theme.orange,
                        title: L("Paus – \(Format.countdown(to: pausedUntil, from: date)) kvar"),
                        detail: L("Sedan blockeras apparna igen.")
                    )
                    Button(L("Avsluta pausen nu")) { model.endPause() }
                        .buttonStyle(ChipButtonStyle())
                }
            }
            .card()
        }
    }

    // MARK: Focus

    private func focusCard(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let goal = model.runtime.focusStepGoal, let end = model.runtime.focusEndsAt, end > date {
                stepSession(goal: goal)
            } else if let end = model.runtime.focusEndsAt, end > date, let start = model.runtime.focusStartedAt {
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
                        Text(L("Fokus pågår"))
                            .font(.title3.bold())
                        Text(L("Klart \(Format.time(end)). Du får \(Int((total / 60).rounded()) + PlayerProgress.XP.focusBonus) XP."))
                            .foregroundStyle(.secondary)
                        if model.isStrictFocusActive {
                            Label(L("Strikt fokus"), systemImage: "lock.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.pink)
                        } else {
                            Button(L("Avbryt (−\(PlayerProgress.XP.abandonedFocus) XP)"), role: .destructive) {
                                isStopFocusConfirming = true
                            }
                            .font(.subheadline)
                            .confirmationDialog(L("Avbryta fokuspasset?"), isPresented: $isStopFocusConfirming, titleVisibility: .visible) {
                                Button(L("Avbryt ändå (−\(PlayerProgress.XP.abandonedFocus) XP)"), role: .destructive) { model.stopFocus() }
                                Button(L("Fortsätt fokusera"), role: .cancel) {}
                            } message: {
                                Text(L("Du förlorar \(PlayerProgress.XP.abandonedFocus) XP, \(League.Points.abandonedFocus) veckopoäng och Pip blir ledsen. Du är så nära!"))
                            }
                        }
                    }
                }
            } else {
                Text(L("Fokuspass"))
                    .font(.title3.bold())
                Text(L("Blockera apparna direkt. 1 XP per minut + \(PlayerProgress.XP.focusBonus) i bonus."))
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(focusLengths, id: \.self) { minutes in
                        Button {
                            model.startFocus(minutes: minutes)
                        } label: {
                            Text(Format.minutes(minutes))
                        }
                        .buttonStyle(ChipButtonStyle())
                        .accessibilityLabel(L("Starta fokus i \(Format.minutes(minutes))"))
                    }
                }
                stepSessionChoices
            }
        }
        .card()
    }

    // MARK: Step sessions

    private func stepSession(goal: Int) -> some View {
        let walked = min(model.sessionSteps ?? 0, goal)
        return HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: Double(walked) / Double(max(goal, 1)))
                    .stroke(Theme.glow, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Image(systemName: "figure.walk")
                        .font(.subheadline)
                    Text(Format.number(walked))
                        .font(.headline.monospacedDigit())
                }
            }
            .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Stegpass pågår"))
                    .font(.title3.bold())
                Text(L("Gå \(Format.number(goal - walked)) steg till, så låses apparna upp."))
                    .foregroundStyle(.secondary)
                Label(L("Går inte att avbryta"), systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.pink)
                if model.sessionSteps == nil {
                    Text(L("Stegen kunde inte läsas från Hälsa just nu."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            // Keep the count fresh while the card is on screen; the session ends as soon as the goal is reached.
            while !Task.isCancelled {
                await model.refreshSessionSteps()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private var stepSessionChoices: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("Eller lås apparna tills du har gått"))
                    .font(.subheadline.weight(.semibold))
                if !model.isPro {
                    Spacer()
                    ProBadge()
                }
            }
            HStack(spacing: 10) {
                ForEach(StepFocus.goals, id: \.self) { goal in
                    Button {
                        if model.isPro {
                            confirmingStepGoal = goal
                        } else {
                            model.isPaywallPresented = true
                        }
                    } label: {
                        Text(L("\(Format.number(goal)) steg"))
                    }
                    .buttonStyle(ChipButtonStyle())
                }
            }
        }
        .padding(.top, 4)
        .confirmationDialog(
            L("Starta ett stegpass?"),
            isPresented: Binding(get: { confirmingStepGoal != nil }, set: { if !$0 { confirmingStepGoal = nil } }),
            titleVisibility: .visible,
            presenting: confirmingStepGoal
        ) { goal in
            Button(L("Lås tills jag gått \(Format.number(goal)) steg")) {
                Task { await model.startStepFocus(goal: goal) }
            }
            Button(L("Inte nu"), role: .cancel) {}
        } message: { goal in
            Text(L("Apparna låses tills du har gått \(Format.number(goal)) steg. Det går inte att avbryta, pausa eller ta bort Paus under tiden. Öppna Paus när du har gått klart."))
        }
    }

    // MARK: Quests

    private func questsCard(at date: Date) -> some View {
        let counts = model.progress.counts(at: date, calendar: .current)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("Dagens uppdrag"))
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
        .accessibilityValue(isDone ? L("Klart") : L("\(min(progress, quest.target)) av \(quest.target)"))
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
        .accessibilityLabel(L("Streak: \(streak) dagar"))
    }
}

