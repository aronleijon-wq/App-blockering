import SwiftUI

/// Today's focus score, this week against the last, and a calendar of the last months.
struct StatsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    var body: some View {
        let now = Date.now
        let history = model.progress.dayHistory(at: now, calendar: calendar)
        let today = model.progress.counts(at: now, calendar: calendar)
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    scoreCard(today)
                    weekCard(history, now: now)
                    calendarCard(history, now: now)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle(L("Statistik"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Klar")) { dismiss() }
                }
            }
        }
    }

    // MARK: Score

    private func scoreCard(_ today: DailyCounts) -> some View {
        let score = FocusScore.compute(today)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                FocusScoreRing(score: score, size: 96)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Fokuspoäng i dag"))
                        .font(.title3.bold())
                    Text(FocusScoreRing.verdict(for: score))
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(FocusScore.breakdown(today), id: \.title) { part in
                HStack {
                    Text(part.title)
                    Spacer()
                    Text(part.maximum > 0 ? "\(part.points) / \(part.maximum)" : "\(part.points)")
                        .monospacedDigit()
                        .foregroundStyle(part.points < 0 ? Theme.pink : .secondary)
                }
                .font(.subheadline)
            }
        }
        .card(highlighted: true)
    }

    // MARK: Week

    private func weekCard(_ history: [String: DaySummary], now: Date) -> some View {
        let monday = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let lastMonday = calendar.date(byAdding: .day, value: -7, to: monday) ?? monday
        let thisWeek = WeekReport.make(from: history, weekStarting: monday, calendar: calendar)
        let lastWeek = WeekReport.make(from: history, weekStarting: lastMonday, calendar: calendar)
        return VStack(alignment: .leading, spacing: 12) {
            Text(L("Veckorapport"))
                .font(.title3.bold())
            if let change = WeekReport.change(thisWeek.focusMinutes, from: lastWeek.focusMinutes) {
                Text(change >= 0
                     ? L("Du har fokuserat \(change) % mer än förra veckan. 🎉")
                     : L("Du har fokuserat \(-change) % mindre än förra veckan. Du kan vända det!"))
                    .font(.headline)
                    .foregroundStyle(change >= 0 ? Theme.mint : Theme.orange)
            } else {
                Text(L("Nästa vecka kan du jämföra med den här."))
                    .foregroundStyle(.secondary)
            }
            WeekRow(title: L("Fokustid"), now: Format.minutes(thisWeek.focusMinutes), before: Format.minutes(lastWeek.focusMinutes))
            WeekRow(title: L("Fokuspass"), now: "\(thisWeek.focusSessions)", before: "\(lastWeek.focusSessions)")
            WeekRow(title: L("Stängda appar"), now: "\(thisWeek.closes)", before: "\(lastWeek.closes)")
            WeekRow(title: L("Snittpoäng"), now: "\(thisWeek.averageScore)", before: "\(lastWeek.averageScore)")
            Text(L("Hur mycket du har scrollat ser du under Skärmtid på startsidan."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    // MARK: Calendar

    private static let weeks = 16

    private func calendarCard(_ history: [String: DaySummary], now: Date) -> some View {
        let monday = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let first = calendar.date(byAdding: .day, value: -7 * (Self.weeks - 1), to: monday) ?? monday
        let today = DayKey.string(for: now, calendar: calendar)
        return VStack(alignment: .leading, spacing: 12) {
            Text(L("Fokuskalender"))
                .font(.title3.bold())
            HStack(alignment: .top, spacing: 4) {
                ForEach(0..<Self.weeks, id: \.self) { week in
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { weekday in
                            let date = calendar.date(byAdding: .day, value: week * 7 + weekday, to: first) ?? first
                            let key = DayKey.string(for: date, calendar: calendar)
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(color(for: history[key], future: key > today))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    if key == today {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(.white, lineWidth: 1.5)
                                    }
                                }
                        }
                    }
                }
            }
            HStack(spacing: 6) {
                Text(L("Mindre"))
                ForEach([0, 30, 55, 80], id: \.self) { score in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color(for: DaySummary(score: score), future: false))
                        .frame(width: 12, height: 12)
                }
                Text(L("Mer fokus"))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .card()
    }

    private func color(for day: DaySummary?, future: Bool) -> Color {
        guard !future else { return .clear }
        guard let day, day.focusMinutes > 0 || day.closes > 0 || day.quests > 0 else { return Color.white.opacity(0.07) }
        switch day.score {
        case ..<40: return Theme.mint.opacity(0.3)
        case 40..<65: return Theme.mint.opacity(0.55)
        case 65..<85: return Theme.mint.opacity(0.8)
        default: return Theme.mint
        }
    }
}

private struct WeekRow: View {
    let title: String
    let now: String
    let before: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(now)
                .font(.subheadline.weight(.bold).monospacedDigit())
            Text(L("förra: \(before)"))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .font(.subheadline)
    }
}

/// The focus score as a ring that fills up.
struct FocusScoreRing: View {
    let score: Int
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: size * 0.1)
            Circle()
                .trim(from: 0, to: Double(score) / 100)
                .stroke(Theme.glow, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(L("Fokuspoäng \(score) av 100"))
    }

    static func verdict(for score: Int) -> String {
        switch score {
        case ..<35: return L("Dagen har bara börjat. Ett fokuspass gör stor skillnad.")
        case 35..<60: return L("På god väg. Fortsätt så!")
        case 60..<85: return L("Riktigt bra fokus i dag.")
        default: return L("Toppdag! Pip är superstolt.")
        }
    }
}
