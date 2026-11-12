import SwiftUI

/// The first week's daily rewards as a calendar: seven days, more seeds each day, and a color no shop sells on the
/// seventh. Shown until the week is done.
struct FirstWeekCard: View {
    @Environment(AppModel.self) private var model
    let date: Date

    var body: some View {
        let progress = model.progress
        let claimedToday = !progress.canClaimDailyReward(at: date, calendar: .current)
        let finishedToday = progress.rewardDays == FirstWeek.days && claimedToday
        if progress.rewardDays < FirstWeek.days || finishedToday {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(L("Din första vecka"))
                        .font(.title3.bold())
                    Spacer()
                    Text("\(min(progress.rewardDays, FirstWeek.days)) / \(FirstWeek.days)")
                        .font(.headline.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Theme.orange)
                }
                Text(L("Hämta dagens belöning varje dag. Dag 7 får Pip en färg som inte går att köpa."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ForEach(1...FirstWeek.days, id: \.self) { day in
                        dayBadge(day, claimed: day <= progress.rewardDays, isNext: !claimedToday && day == progress.rewardDays + 1)
                    }
                }
            }
            .card(highlighted: !claimedToday)
        }
    }

    private func dayBadge(_ day: Int, claimed: Bool, isNext: Bool) -> some View {
        let last = day == FirstWeek.days
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(claimed ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.35), Theme.orange],
                                                                 startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(Theme.cardRaised))
                if isNext {
                    Circle().strokeBorder(Color.white, lineWidth: 2.5)
                }
                if last && !claimed {
                    PipAvatar(outfit: Outfit(color: FirstWeek.item), level: 1, size: 22)
                } else {
                    Image(systemName: claimed ? "checkmark" : "gift.fill")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(claimed ? Color.white : isNext ? Theme.pink : Color.secondary)
                }
            }
            .frame(maxWidth: 44)
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(isNext ? 1.08 : 1)
            Text(L("Dag \(day)"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isNext ? Color.primary : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Dag \(day)"))
        .accessibilityValue(claimed ? L("Hämtad") : L("+\(FirstWeek.bonusSeeds(day: day)) frön"))
    }
}

/// The streak up close, with the streak freezes that keep it alive through a missed day.
struct StreakSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let progress = model.progress
        let streak = progress.currentStreak(at: .now, calendar: .current)
        VStack(spacing: 18) {
            Image(systemName: "flame.fill")
                .font(.system(size: 70))
                .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.3), Theme.flame], startPoint: .top, endPoint: .bottom))
                .symbolEffect(.bounce, value: streak)
                .padding(.top, 30)
            Text(streak == 1 ? L("1 dag i rad") : L("\(streak) dagar i rad"))
                .font(.system(size: 30, weight: .heavy, design: .rounded))
            Text(L("Bästa: \(progress.bestStreak) dagar"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L("Streakfrys"))
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<StreakFreeze.max, id: \.self) { index in
                            Image(systemName: "snowflake")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(index < progress.streakFreezes ? Color(red: 0.5, green: 0.85, blue: 1) : Color.secondary.opacity(0.4))
                        }
                    }
                }
                Text(L("En streakfrys räddar din streak en dag du missar. Den används av sig själv. Du kan ha \(StreakFreeze.max) åt gången."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if progress.streakFreezes < StreakFreeze.max {
                    Button {
                        model.buyStreakFreeze()
                    } label: {
                        Label(L("Köp för \(StreakFreeze.price) frön"), systemImage: "snowflake")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Color(red: 0.5, green: 0.85, blue: 1), edge: Color(red: 0.25, green: 0.55, blue: 0.85)))
                    .disabled(progress.seeds < StreakFreeze.price)
                    .opacity(progress.seeds < StreakFreeze.price ? 0.5 : 1)
                    SeedsChip(seeds: progress.seeds)
                        .frame(maxWidth: .infinity)
                } else {
                    Label(L("Du har fullt"), systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Theme.mint)
                }
            }
            .card()
            .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .screenBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: progress.streakFreezes)
    }
}
