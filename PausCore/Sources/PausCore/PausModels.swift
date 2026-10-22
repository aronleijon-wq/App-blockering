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
    /// Schedules and the daily limit rest until this date. Focus sessions still work.
    var vacationUntil: Date?

    init(
        dailyLimitMinutes: Int? = nil,
        schedules: [BlockSchedule] = [],
        strictFocus: Bool = true,
        pause: PauseRules = PauseRules(),
        preventUninstall: Bool = false,
        adultFilter: Bool = false,
        vacationUntil: Date? = nil
    ) {
        self.dailyLimitMinutes = dailyLimitMinutes
        self.schedules = schedules
        self.strictFocus = strictFocus
        self.pause = pause
        self.preventUninstall = preventUninstall
        self.adultFilter = adultFilter
        self.vacationUntil = vacationUntil
    }

    func isOnVacation(at date: Date) -> Bool {
        guard let vacationUntil else { return false }
        return vacationUntil > date
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
        vacationUntil = try container.decodeIfPresent(Date.self, forKey: .vacationUntil)
    }
}

/// State written by both the app and its extensions while blocks run.
struct PausRuntime: Codable, Equatable {
    var focusStartedAt: Date?
    var focusEndsAt: Date?
    var pausedUntil: Date?
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
        pausedUntil: Date? = nil,
        limitReachedDay: String? = nil,
        pauseRequestedAt: Date? = nil,
        statsDay: String? = nil,
        pausesUsed: Int = 0,
        closedCount: Int = 0
    ) {
        self.focusStartedAt = focusStartedAt
        self.focusEndsAt = focusEndsAt
        self.pausedUntil = pausedUntil
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
        pausedUntil = try container.decodeIfPresent(Date.self, forKey: .pausedUntil)
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
