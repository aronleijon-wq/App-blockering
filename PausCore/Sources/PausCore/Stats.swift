import Foundation

/// What one day looked like, kept for the focus calendar and the weekly report.
struct DaySummary: Codable, Equatable {
    var focusMinutes = 0
    var focusSessions = 0
    var closes = 0
    var pauses = 0
    var quests = 0
    var score = 0

    init(focusMinutes: Int = 0, focusSessions: Int = 0, closes: Int = 0, pauses: Int = 0, quests: Int = 0, score: Int = 0) {
        self.focusMinutes = focusMinutes
        self.focusSessions = focusSessions
        self.closes = closes
        self.pauses = pauses
        self.quests = quests
        self.score = score
    }

    init(_ counts: DailyCounts) {
        self.init(
            focusMinutes: counts.focusMinutes,
            focusSessions: counts.focusSessions,
            closes: counts.closes,
            pauses: counts.pauses,
            quests: counts.completedQuests.count,
            score: FocusScore.compute(counts)
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 0
        focusSessions = try container.decodeIfPresent(Int.self, forKey: .focusSessions) ?? 0
        closes = try container.decodeIfPresent(Int.self, forKey: .closes) ?? 0
        pauses = try container.decodeIfPresent(Int.self, forKey: .pauses) ?? 0
        quests = try container.decodeIfPresent(Int.self, forKey: .quests) ?? 0
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
    }
}

/// A day's focus as one number, 0 to 100: focus time, closed apps, quests and little scrolling raise it;
/// pauses and SOS lower it.
enum FocusScore {
    static func compute(_ counts: DailyCounts) -> Int {
        let parts = breakdown(counts)
        return max(0, min(100, parts.reduce(0) { $0 + $1.points }))
    }

    struct Part: Equatable {
        let title: String
        let points: Int
        let maximum: Int
    }

    static func breakdown(_ counts: DailyCounts) -> [Part] {
        let focus = Int((min(Double(counts.focusMinutes) / 60, 1) * 40).rounded())
        let closes = Int((min(Double(counts.closes) / 5, 1) * 15).rounded())
        let quests = Int((min(Double(counts.completedQuests.count) / 3, 1) * 15).rounded())
        let scroll = Int(((1 - min(Double(counts.scrolledMinutes) / 180, 1)) * 30).rounded())
        let giving = -(counts.pauses * 5 + counts.sosUses * 10)
        return [
            Part(title: L("Fokustid"), points: focus, maximum: 40),
            Part(title: L("Lite scrollande"), points: scroll, maximum: 30),
            Part(title: L("Stängda appar"), points: closes, maximum: 15),
            Part(title: L("Uppdrag"), points: quests, maximum: 15),
            Part(title: L("Pauser och SOS"), points: max(-30, giving), maximum: 0),
        ]
    }
}

/// This week against the one before, from the day history.
struct WeekReport: Equatable {
    var focusMinutes = 0
    var focusSessions = 0
    var closes = 0
    var averageScore = 0
    var days = 0

    /// The report for the seven days of the week starting `monday`.
    static func make(from history: [String: DaySummary], weekStarting monday: Date, calendar: Calendar) -> WeekReport {
        var report = WeekReport()
        var scores = 0
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: monday),
                  let day = history[DayKey.string(for: date, calendar: calendar)] else { continue }
            report.focusMinutes += day.focusMinutes
            report.focusSessions += day.focusSessions
            report.closes += day.closes
            scores += day.score
            report.days += 1
        }
        report.averageScore = report.days > 0 ? scores / report.days : 0
        return report
    }

    /// The change from `previous` in whole percent, or nil when there's nothing to compare with.
    static func change(_ value: Int, from previous: Int) -> Int? {
        guard previous > 0 else { return nil }
        return Int((Double(value - previous) / Double(previous) * 100).rounded())
    }
}

extension PlayerProgress {
    /// Days kept in the history, about four months.
    static let historyDays = 120

    /// Every day in the history, today included as it stands at `date`.
    func dayHistory(at date: Date, calendar: Calendar) -> [String: DaySummary] {
        var all = history
        let today = counts(at: date, calendar: calendar)
        if let key = today.day {
            all[key] = DaySummary(today)
        }
        return all
    }

    /// Moves a finished day into the history and drops the oldest days.
    mutating func archive(_ counts: DailyCounts) {
        guard let day = counts.day else { return }
        history[day] = DaySummary(counts)
        if history.count > Self.historyDays {
            for key in history.keys.sorted().prefix(history.count - Self.historyDays) {
                history.removeValue(forKey: key)
            }
        }
    }
}
