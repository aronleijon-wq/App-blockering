import Foundation

/// How pauses from an active block work.
struct PauseRules: Codable, Equatable {
    var isEnabled: Bool
    /// Seconds of breathing before a pause can start.
    var waitSeconds: Int
    var minutes: Int
    var maxPerDay: Int

    init(isEnabled: Bool = true, waitSeconds: Int = 20, minutes: Int = 5, maxPerDay: Int = 3) {
        self.isEnabled = isEnabled
        self.waitSeconds = waitSeconds
        self.minutes = minutes
        self.maxPerDay = maxPerDay
    }

    // Missing keys decode as defaults so saved data survives new fields.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PauseRules()
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
        waitSeconds = try container.decodeIfPresent(Int.self, forKey: .waitSeconds) ?? defaults.waitSeconds
        minutes = try container.decodeIfPresent(Int.self, forKey: .minutes) ?? defaults.minutes
        maxPerDay = try container.decodeIfPresent(Int.self, forKey: .maxPerDay) ?? defaults.maxPerDay
    }
}

/// The rules the user sets up in the app.
struct PausRules: Codable, Equatable {
    var dailyLimitMinutes: Int?
    var schedules: [BlockSchedule]
    /// A strict focus session can't be ended early or paused.
    var strictFocus: Bool
    var pause: PauseRules
    /// Stops apps, Paus included, from being deleted while the shield is up.
    var preventUninstall: Bool
    /// Keeps Apple's adult website filter on at all times.
    var adultFilter: Bool
    /// The adult filter stays on until this date and can't be turned off before. See `AdultLock`.
    var adultFilterLockedUntil: Date?
    /// When the running adult filter lock started, so its length can be shown and rewarded once it ends.
    var adultFilterLockedAt: Date?
    /// Schedules and the daily limit rest until this date. Focus sessions still work.
    var vacationUntil: Date?
    /// The guarded apps stay blocked, but each can be opened this many times a day in all, from the shield.
    var openLimit: Int?
    /// How long an app stays open after opening it from the shield.
    var openMinutes: Int

    init(
        dailyLimitMinutes: Int? = nil,
        schedules: [BlockSchedule] = [],
        strictFocus: Bool = true,
        pause: PauseRules = PauseRules(),
        preventUninstall: Bool = false,
        adultFilter: Bool = false,
        adultFilterLockedUntil: Date? = nil,
        adultFilterLockedAt: Date? = nil,
        vacationUntil: Date? = nil,
        openLimit: Int? = nil,
        openMinutes: Int = 5
    ) {
        self.dailyLimitMinutes = dailyLimitMinutes
        self.schedules = schedules
        self.strictFocus = strictFocus
        self.pause = pause
        self.preventUninstall = preventUninstall
        self.adultFilter = adultFilter
        self.adultFilterLockedUntil = adultFilterLockedUntil
        self.adultFilterLockedAt = adultFilterLockedAt
        self.vacationUntil = vacationUntil
        self.openLimit = openLimit
        self.openMinutes = openMinutes
    }

    func isOnVacation(at date: Date) -> Bool {
        guard let vacationUntil else { return false }
        return vacationUntil > date
    }

    func isAdultFilterLocked(at date: Date) -> Bool {
        guard let adultFilterLockedUntil else { return false }
        return adultFilterLockedUntil > date
    }

    /// Whether adult websites are blocked at `date`: the filter is on, or locked on.
    func blocksAdultSites(at date: Date) -> Bool {
        adultFilter || isAdultFilterLocked(at: date)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PausRules()
        dailyLimitMinutes = try container.decodeIfPresent(Int.self, forKey: .dailyLimitMinutes)
        schedules = try container.decodeIfPresent([BlockSchedule].self, forKey: .schedules) ?? defaults.schedules
        strictFocus = try container.decodeIfPresent(Bool.self, forKey: .strictFocus) ?? defaults.strictFocus
        pause = try container.decodeIfPresent(PauseRules.self, forKey: .pause) ?? defaults.pause
        preventUninstall = try container.decodeIfPresent(Bool.self, forKey: .preventUninstall) ?? defaults.preventUninstall
        adultFilter = try container.decodeIfPresent(Bool.self, forKey: .adultFilter) ?? defaults.adultFilter
        adultFilterLockedUntil = try container.decodeIfPresent(Date.self, forKey: .adultFilterLockedUntil)
        adultFilterLockedAt = try container.decodeIfPresent(Date.self, forKey: .adultFilterLockedAt)
        vacationUntil = try container.decodeIfPresent(Date.self, forKey: .vacationUntil)
        openLimit = try container.decodeIfPresent(Int.self, forKey: .openLimit)
        openMinutes = try container.decodeIfPresent(Int.self, forKey: .openMinutes) ?? defaults.openMinutes
    }
}

/// Locks Apple's adult website filter on for a number of days, such as the rest of November, so it can't be
/// turned off in a weak moment.
enum AdultLock {
    /// The lengths offered, in days.
    static let lengths = [7, 30, 90]
    static let maxDays = 365
    /// "The rest of the month" is only offered while at least this many days of it are left.
    static let minDaysForMonth = 3

    /// The end of the month `date` is in: midnight as the next month starts.
    static func endOfMonth(after date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.end ?? date
    }

    /// When a lock of `days` days started at `date` ends: midnight after its last day, counting `date`'s day.
    static func end(days: Int, from date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: min(max(1, days), maxDays), to: start) ?? date
    }

    /// Days left of a lock that ends at `end`, counting `date`'s day.
    static func daysLeft(until end: Date, from date: Date, calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: end)).day ?? 0
        return max(0, days)
    }

    // MARK: The November challenge

    /// The month the challenge runs in.
    static let challengeMonth = 11

    /// The oldest age group the challenge is offered to: under 18, 18–24 and 25–34 see it. Without an answer
    /// from the intro, it is offered.
    static let oldestChallengeGroup = AgeGroup.from25

    static func offersChallenge(to ageGroup: AgeGroup?) -> Bool {
        guard let ageGroup else { return true }
        return ageGroup.youngestAge <= oldestChallengeGroup.youngestAge
    }

    /// Whether `date` is in the challenge month with enough of it left to take the challenge.
    static func offersChallenge(at date: Date, calendar: Calendar) -> Bool {
        calendar.component(.month, from: date) == challengeMonth
            && daysLeft(until: endOfMonth(after: date, calendar: calendar), from: date, calendar: calendar) >= minDaysForMonth
    }

    /// Whether a lock from `start` to `end` is the challenge: started in November and lasting the rest of it.
    static func isChallenge(from start: Date, to end: Date, calendar: Calendar) -> Bool {
        calendar.component(.month, from: start) == challengeMonth && end >= endOfMonth(after: start, calendar: calendar)
    }

    // MARK: Rewards

    /// Locks shorter than this earn nothing when they end, so short locks can't be farmed.
    static let minRewardDays = 7
    /// Rewards grow with the lock up to this many days.
    static let maxRewardDays = 30

    static func rewardXP(days: Int) -> Int {
        days < minRewardDays ? 0 : min(days, maxRewardDays) * 10
    }

    static func rewardSeeds(days: Int) -> Int {
        days < minRewardDays ? 0 : min(days, maxRewardDays) * 5
    }
}

/// State written by both the app and its extensions while blocks run.
struct PausRuntime: Codable, Equatable {
    var focusStartedAt: Date?
    var focusEndsAt: Date?
    /// Set for a step session: the focus session ends once this many steps are walked after `focusStartedAt`,
    /// and `focusEndsAt` is only a backstop.
    var focusStepGoal: Int?
    /// The latest step count of the running step session, and when it was read, for the lock screen.
    var focusStepsWalked: Int?
    var focusStepsCheckedAt: Date?
    var pausedUntil: Date?
    /// Schedules and the daily limit rest until this date after an SOS. Focus sessions started later still block.
    var sosUntil: Date?
    /// Whether an iPhone Focus with Paus's filter is on, set by the Focus filter.
    var focusModeOn = false
    /// While an app opened from the shield under the open limit stays open.
    var openUntil: Date?
    /// Opens used today under the open limit; belongs to `statsDay`.
    var opensUsed = 0
    /// Day key of the day the daily limit was reached.
    var limitReachedDay: String?
    /// When the shield's pause button was last pressed, so the app can open the pause screen.
    var pauseRequestedAt: Date?
    /// Day key the counters below belong to.
    var statsDay: String?
    var pausesUsed: Int
    var closedCount: Int

    init(
        focusStartedAt: Date? = nil,
        focusEndsAt: Date? = nil,
        focusStepGoal: Int? = nil,
        focusStepsWalked: Int? = nil,
        focusStepsCheckedAt: Date? = nil,
        pausedUntil: Date? = nil,
        sosUntil: Date? = nil,
        limitReachedDay: String? = nil,
        pauseRequestedAt: Date? = nil,
        statsDay: String? = nil,
        pausesUsed: Int = 0,
        closedCount: Int = 0
    ) {
        self.focusStartedAt = focusStartedAt
        self.focusEndsAt = focusEndsAt
        self.focusStepGoal = focusStepGoal
        self.focusStepsWalked = focusStepsWalked
        self.focusStepsCheckedAt = focusStepsCheckedAt
        self.pausedUntil = pausedUntil
        self.sosUntil = sosUntil
        self.limitReachedDay = limitReachedDay
        self.pauseRequestedAt = pauseRequestedAt
        self.statsDay = statsDay
        self.pausesUsed = pausesUsed
        self.closedCount = closedCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusStartedAt = try container.decodeIfPresent(Date.self, forKey: .focusStartedAt)
        focusEndsAt = try container.decodeIfPresent(Date.self, forKey: .focusEndsAt)
        focusStepGoal = try container.decodeIfPresent(Int.self, forKey: .focusStepGoal)
        focusStepsWalked = try container.decodeIfPresent(Int.self, forKey: .focusStepsWalked)
        focusStepsCheckedAt = try container.decodeIfPresent(Date.self, forKey: .focusStepsCheckedAt)
        pausedUntil = try container.decodeIfPresent(Date.self, forKey: .pausedUntil)
        sosUntil = try container.decodeIfPresent(Date.self, forKey: .sosUntil)
        focusModeOn = try container.decodeIfPresent(Bool.self, forKey: .focusModeOn) ?? false
        openUntil = try container.decodeIfPresent(Date.self, forKey: .openUntil)
        opensUsed = try container.decodeIfPresent(Int.self, forKey: .opensUsed) ?? 0
        limitReachedDay = try container.decodeIfPresent(String.self, forKey: .limitReachedDay)
        pauseRequestedAt = try container.decodeIfPresent(Date.self, forKey: .pauseRequestedAt)
        statsDay = try container.decodeIfPresent(String.self, forKey: .statsDay)
        pausesUsed = try container.decodeIfPresent(Int.self, forKey: .pausesUsed) ?? 0
        closedCount = try container.decodeIfPresent(Int.self, forKey: .closedCount) ?? 0
    }

    /// Resets the daily counters when `date` falls on a new day.
    mutating func rollOver(to date: Date, calendar: Calendar) {
        let key = DayKey.string(for: date, calendar: calendar)
        guard statsDay != key else { return }
        statsDay = key
        pausesUsed = 0
        closedCount = 0
        opensUsed = 0
    }

    /// Opens an app under the open limit until `end`.
    mutating func recordOpen(at date: Date, until end: Date, calendar: Calendar) {
        rollOver(to: date, calendar: calendar)
        opensUsed += 1
        openUntil = end
    }

    /// Opens used on the day containing `date`.
    func opens(on date: Date, calendar: Calendar) -> Int {
        statsDay == DayKey.string(for: date, calendar: calendar) ? opensUsed : 0
    }

    mutating func startPause(at date: Date, until end: Date, calendar: Calendar) {
        rollOver(to: date, calendar: calendar)
        pausesUsed += 1
        pausedUntil = end
    }

    mutating func recordClose(at date: Date, calendar: Calendar) {
        rollOver(to: date, calendar: calendar)
        closedCount += 1
    }

    /// Counters for the day containing `date`; zero when the stored counters belong to another day.
    func counts(on date: Date, calendar: Calendar) -> (pauses: Int, closed: Int) {
        guard statsDay == DayKey.string(for: date, calendar: calendar) else { return (0, 0) }
        return (pausesUsed, closedCount)
    }
}

enum DayKey {
    static func string(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func dayBefore(_ date: Date, calendar: Calendar) -> String {
        string(for: calendar.date(byAdding: .day, value: -1, to: date) ?? date, calendar: calendar)
    }
}
