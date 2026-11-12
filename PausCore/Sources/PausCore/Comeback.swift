import Foundation

/// What brings players back in their first days and after a break: a calendar for the first week of daily rewards,
/// streak freezes that save a streak through a missed day, and a gift for coming back after a few days away.
enum FirstWeek {
    static let days = 7
    /// The color the seventh daily reward gives. It can't be bought.
    static let item = "color-starter"

    /// Extra seeds the daily reward gives on day `day` of the first week, more each day.
    static func bonusSeeds(day: Int) -> Int {
        guard (1...days).contains(day) else { return 0 }
        return day * 5
    }
}

enum StreakFreeze {
    static let price = 60
    static let max = 2
}

enum Comeback {
    /// Days since the last activity that count as having been away.
    static let awayDays = 3
    /// Enough for a streak freeze.
    static let seeds = 60
}

extension DayKey {
    /// The day a key such as "2026-11-12" names, at its start.
    static func date(from key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Whole days from day `from` to day `to`, or nil when a key can't be read.
    static func days(from: String, to: String, calendar: Calendar) -> Int? {
        guard let start = date(from: from, calendar: calendar), let end = date(from: to, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: start, to: end).day
    }
}

extension PlayerProgress {
    /// Days missed since the last active day, before `date`'s day: 0 when active today or yesterday.
    func missedDays(at date: Date, calendar: Calendar) -> Int {
        guard let lastActiveDay,
              let gap = DayKey.days(from: lastActiveDay, to: DayKey.string(for: date, calendar: calendar), calendar: calendar) else { return 0 }
        return max(0, gap - 1)
    }

    /// The day of the first week the next daily reward is, or nil once the first week is done.
    var nextFirstWeekDay: Int? {
        rewardDays < FirstWeek.days ? rewardDays + 1 : nil
    }

    /// Buys a streak freeze with seeds. Returns whether it was bought.
    @discardableResult
    mutating func buyStreakFreeze() -> Bool {
        guard streakFreezes < StreakFreeze.max, seeds >= StreakFreeze.price else { return false }
        seeds -= StreakFreeze.price
        streakFreezes += 1
        return true
    }
}
