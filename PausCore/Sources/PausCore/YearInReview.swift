import Foundation

/// A player's year with Paus, for the story to share at the end of the year, like a music app's wrap-up.
struct YearInReview: Equatable {
    let year: Int
    let focusMinutes: Int
    let focusSessions: Int
    let closes: Int
    let quests: Int
    /// Days with any focus.
    let focusDays: Int
    /// The day with the most focus, as a day key, and its minutes.
    let bestDay: String?
    let bestDayMinutes: Int
    /// The month with the most focus, 1...12.
    let bestMonth: Int?
    let bestStreak: Int
    let level: Int
    let eggs: Int
    let legendaryEggs: Int

    var hours: Int { focusMinutes / 60 }
    /// Whole days of 24 hours in the focus.
    var days: Int { focusMinutes / (24 * 60) }
    /// Books the focus time could have read, at about six hours a book.
    var books: Int { focusMinutes / 360 }

    static func make(from progress: PlayerProgress, year: Int, at date: Date, calendar: Calendar) -> YearInReview {
        var days = progress.history
        let today = progress.counts(at: date, calendar: calendar)
        if let key = today.day {
            days[key] = DaySummary(today)
        }
        let prefix = String(format: "%04d-", year)
        let inYear = days.filter { $0.key.hasPrefix(prefix) }
        var months: [Int: Int] = [:]
        for (key, day) in inYear {
            if let month = Int(key.dropFirst(5).prefix(2)) {
                months[month, default: 0] += day.focusMinutes
            }
        }
        let best = inYear.max { $0.value.focusMinutes == $1.value.focusMinutes ? $0.key > $1.key : $0.value.focusMinutes < $1.value.focusMinutes }
        let bestMonth = months.filter { $0.value > 0 }.max { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }?.key
        return YearInReview(
            year: year,
            focusMinutes: inYear.values.reduce(0) { $0 + $1.focusMinutes },
            focusSessions: inYear.values.reduce(0) { $0 + $1.focusSessions },
            closes: inYear.values.reduce(0) { $0 + $1.closes },
            quests: inYear.values.reduce(0) { $0 + $1.quests },
            focusDays: inYear.values.filter { $0.focusMinutes > 0 }.count,
            bestDay: (best?.value.focusMinutes ?? 0) > 0 ? best?.key : nil,
            bestDayMinutes: best?.value.focusMinutes ?? 0,
            bestMonth: bestMonth,
            bestStreak: progress.bestStreak,
            level: progress.level,
            eggs: progress.eggsHatchedCount,
            legendaryEggs: progress.eggsHatched[FocusEgg.Rarity.legendary.rawValue] ?? 0
        )
    }

    /// The year the wrap-up is about at `date`: from December on, this year; until mid-January, the year before.
    /// Nil the rest of the time, when it isn't offered on the home screen.
    static func season(at date: Date, calendar: Calendar) -> Int? {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        if month == 12 { return year }
        if month == 1 && day <= 15 { return year - 1 }
        return nil
    }
}
