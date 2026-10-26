import Foundation

/// Something the user did that can earn XP.
enum ProgressEvent: Equatable {
    case focusCompleted(minutes: Int)
    case closedBlockedApp
    case declinedPause
    case claimedDailyReward
    case dayUnderLimit
    /// Took a pause from a block anyway. Costs XP and league points after the first one each day.
    case tookPause
    /// Turned off Paus's Screen Time access. Costs XP, points and the streak.
    case disabledProtection
    /// Ended a focus session early.
    case abandonedFocus
    /// Turned off a block while it was on, by changing the rules or the apps.
    case escapedBlock
    /// The guarded apps have been used for `minutes` today. Only makes Pip sadder.
    case scrolled(minutes: Int)
    /// Used up the daily limit. Only makes Pip sadder.
    case reachedDailyLimit
}

enum Reward: Codable, Equatable, Hashable {
    case xp(Int)
    case levelUp(Int)
    case achievement(String)
    case quest(String)
    case division(Int, promoted: Bool)
    /// XP taken away for giving in. Never costs a level.
    case xpLost(Int)

    /// Rewards worth a celebration screen; plain XP and losses only move the progress bar.
    var isCelebration: Bool {
        switch self {
        case .xp, .xpLost: return false
        default: return true
        }
    }
}

/// Counters for one day. They drive the daily quests and the daily XP caps.
struct DailyCounts: Codable, Equatable {
    var day: String?
    var focusSessions: Int
    var focusMinutes: Int
    var closes: Int
    var declines: Int
    var completedQuests: Set<String>
    /// Focus minutes already counted toward league points today.
    var focusPoints: Int
    var pauses: Int
    /// The highest usage threshold of the guarded apps already reported today.
    var scrolledMinutes: Int

    init(day: String? = nil, focusSessions: Int = 0, focusMinutes: Int = 0, closes: Int = 0, declines: Int = 0, completedQuests: Set<String> = [], focusPoints: Int = 0, pauses: Int = 0, scrolledMinutes: Int = 0) {
        self.day = day
        self.focusSessions = focusSessions
        self.focusMinutes = focusMinutes
        self.closes = closes
        self.declines = declines
        self.completedQuests = completedQuests
        self.focusPoints = focusPoints
        self.pauses = pauses
        self.scrolledMinutes = scrolledMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decodeIfPresent(String.self, forKey: .day)
        focusSessions = try container.decodeIfPresent(Int.self, forKey: .focusSessions) ?? 0
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 0
        closes = try container.decodeIfPresent(Int.self, forKey: .closes) ?? 0
        declines = try container.decodeIfPresent(Int.self, forKey: .declines) ?? 0
        completedQuests = try container.decodeIfPresent(Set<String>.self, forKey: .completedQuests) ?? []
        focusPoints = try container.decodeIfPresent(Int.self, forKey: .focusPoints) ?? 0
        pauses = try container.decodeIfPresent(Int.self, forKey: .pauses) ?? 0
        scrolledMinutes = try container.decodeIfPresent(Int.self, forKey: .scrolledMinutes) ?? 0
    }
}

/// XP, level, streak, quests and achievements.
struct PlayerProgress: Codable, Equatable {
    enum XP {
        static let focusBonus = 10
        static let close = 5
        static let closeDailyCap = 10
        static let decline = 10
        static let declineDailyCap = 5
        static let dailyRewardBase = 10
        static let dailyRewardPerStreakDay = 5
        static let dailyRewardMaxStreakBonus = 6
        static let dayUnderLimit = 30
        static let abandonedFocus = 15
        static let escapedBlock = 25
        static let disabledProtection = 100

        /// XP the `number`th pause of a day costs, the same as its league points: free, then 10, 20 and 40.
        static func pausePenalty(forPause number: Int) -> Int {
            League.pausePenalty(forPause: number)
        }
    }

    static let maxPendingRewards = 20

    var xp: Int
    var streak: Int
    var bestStreak: Int
    var lastActiveDay: String?
    var lastRewardDay: String?
    var firstDay: String?
    /// The last day that was checked for staying under the daily limit.
    var lastSettledDay: String?
    var focusSessions: Int
    var focusMinutes: Int
    var closes: Int
    var declines: Int
    var unlocked: Set<String>
    var today: DailyCounts
    /// Celebrations earned while the app wasn't showing, oldest first.
    var pendingRewards: [Reward]
    var weekKey: String?
    var weeklyPoints: Int
    var division: Division
    /// The league group joined this week, if any.
    var leagueGroupID: String?
    /// A week that ended but whose division change hasn't been settled yet.
    var finishedWeek: FinishedWeek?
    /// How often each pause reason was picked, keyed by `PauseReason` raw value.
    var pauseReasons: [String: Int]
    /// Pip's health, 0...100. See `PipHealth`.
    var health: Int
    /// The day health last recovered overnight.
    var healthDay: String?

    init(
        xp: Int = 0,
        streak: Int = 0,
        bestStreak: Int = 0,
        lastActiveDay: String? = nil,
        lastRewardDay: String? = nil,
        firstDay: String? = nil,
        lastSettledDay: String? = nil,
        focusSessions: Int = 0,
        focusMinutes: Int = 0,
        closes: Int = 0,
        declines: Int = 0,
        unlocked: Set<String> = [],
        today: DailyCounts = DailyCounts(),
        pendingRewards: [Reward] = [],
        weekKey: String? = nil,
        weeklyPoints: Int = 0,
        division: Division = .brons,
        leagueGroupID: String? = nil,
        finishedWeek: FinishedWeek? = nil,
        pauseReasons: [String: Int] = [:],
        health: Int = PipHealth.start,
        healthDay: String? = nil
    ) {
        self.xp = xp
        self.streak = streak
        self.bestStreak = bestStreak
        self.lastActiveDay = lastActiveDay
        self.lastRewardDay = lastRewardDay
        self.firstDay = firstDay
        self.lastSettledDay = lastSettledDay
        self.focusSessions = focusSessions
        self.focusMinutes = focusMinutes
        self.closes = closes
        self.declines = declines
        self.unlocked = unlocked
        self.today = today
        self.pendingRewards = pendingRewards
        self.weekKey = weekKey
        self.weeklyPoints = weeklyPoints
        self.division = division
        self.leagueGroupID = leagueGroupID
        self.finishedWeek = finishedWeek
        self.pauseReasons = pauseReasons
        self.health = health
        self.healthDay = healthDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        xp = try container.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        bestStreak = try container.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
        lastActiveDay = try container.decodeIfPresent(String.self, forKey: .lastActiveDay)
        lastRewardDay = try container.decodeIfPresent(String.self, forKey: .lastRewardDay)
        firstDay = try container.decodeIfPresent(String.self, forKey: .firstDay)
        lastSettledDay = try container.decodeIfPresent(String.self, forKey: .lastSettledDay)
        focusSessions = try container.decodeIfPresent(Int.self, forKey: .focusSessions) ?? 0
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 0
        closes = try container.decodeIfPresent(Int.self, forKey: .closes) ?? 0
        declines = try container.decodeIfPresent(Int.self, forKey: .declines) ?? 0
        unlocked = try container.decodeIfPresent(Set<String>.self, forKey: .unlocked) ?? []
        today = try container.decodeIfPresent(DailyCounts.self, forKey: .today) ?? DailyCounts()
        pendingRewards = try container.decodeIfPresent([Reward].self, forKey: .pendingRewards) ?? []
        weekKey = try container.decodeIfPresent(String.self, forKey: .weekKey)
        weeklyPoints = try container.decodeIfPresent(Int.self, forKey: .weeklyPoints) ?? 0
        division = try container.decodeIfPresent(Division.self, forKey: .division) ?? .brons
        leagueGroupID = try container.decodeIfPresent(String.self, forKey: .leagueGroupID)
        finishedWeek = try container.decodeIfPresent(FinishedWeek.self, forKey: .finishedWeek)
        pauseReasons = try container.decodeIfPresent([String: Int].self, forKey: .pauseReasons) ?? [:]
        health = try container.decodeIfPresent(Int.self, forKey: .health) ?? PipHealth.start
        healthDay = try container.decodeIfPresent(String.self, forKey: .healthDay)
    }

    var level: Int { Level.level(forXP: xp) }

    var healthStage: PipHealth.Stage { PipHealth.Stage(health: health) }

    /// The streak as of `date`; it lapses after a whole day without activity.
    func currentStreak(at date: Date, calendar: Calendar) -> Int {
        let today = DayKey.string(for: date, calendar: calendar)
        guard let lastActiveDay, lastActiveDay == today || lastActiveDay == DayKey.dayBefore(date, calendar: calendar) else { return 0 }
        return streak
    }

    func canClaimDailyReward(at date: Date, calendar: Calendar) -> Bool {
        lastRewardDay != DayKey.string(for: date, calendar: calendar)
    }

    /// XP the daily reward gives if claimed at `date`, counting the streak it would extend.
    func dailyRewardXP(at date: Date, calendar: Calendar) -> Int {
        var preview = self
        preview.markActive(at: date, calendar: calendar)
        return XP.dailyRewardBase + XP.dailyRewardPerStreakDay * min(preview.streak, XP.dailyRewardMaxStreakBonus)
    }

    /// Today's counters, or empty ones when the stored counters are from another day.
    func counts(at date: Date, calendar: Calendar) -> DailyCounts {
        let day = DayKey.string(for: date, calendar: calendar)
        return today.day == day ? today : DailyCounts(day: day)
    }

    /// Applies `event`, returning everything it earned. Celebrations are also queued in `pendingRewards`.
    @discardableResult
    mutating func record(_ event: ProgressEvent, at date: Date, calendar: Calendar) -> [Reward] {
        let day = DayKey.string(for: date, calendar: calendar)
        if firstDay == nil { firstDay = day }
        if today.day != day { today = DailyCounts(day: day) }
        rollWeek(at: date, calendar: calendar)
        recoverOvernight(at: date, calendar: calendar)
        let levelBefore = level
        var gained = 0
        var lost = 0
        var points = 0
        var healthChange = 0

        switch event {
        case .focusCompleted(let minutes):
            guard minutes > 0 else { return [] }
            focusSessions += 1
            focusMinutes += minutes
            today.focusSessions += 1
            today.focusMinutes += minutes
            gained = minutes + XP.focusBonus
            points = min(minutes, max(0, League.Points.focusDailyCap - today.focusPoints))
            today.focusPoints += points
            healthChange = points / PipHealth.focusMinutesPerPoint
            markActive(at: date, calendar: calendar)
        case .closedBlockedApp:
            closes += 1
            today.closes += 1
            gained = today.closes <= XP.closeDailyCap ? XP.close : 0
            points = gained > 0 ? League.Points.close : 0
            healthChange = gained > 0 ? PipHealth.closedBlockedApp : 0
            markActive(at: date, calendar: calendar)
        case .declinedPause:
            declines += 1
            today.declines += 1
            gained = today.declines <= XP.declineDailyCap ? XP.decline : 0
            points = gained > 0 ? League.Points.decline : 0
            healthChange = gained > 0 ? PipHealth.declinedPause : 0
            markActive(at: date, calendar: calendar)
        case .claimedDailyReward:
            guard lastRewardDay != day else { return [] }
            lastRewardDay = day
            // Extend the streak first so the reward reflects it.
            markActive(at: date, calendar: calendar)
            gained = XP.dailyRewardBase + XP.dailyRewardPerStreakDay * min(streak, XP.dailyRewardMaxStreakBonus)
            points = League.Points.dailyReward
            healthChange = PipHealth.dailyReward
        case .dayUnderLimit:
            gained = XP.dayUnderLimit
            points = League.Points.dayUnderLimit
            healthChange = PipHealth.dayUnderLimit
        case .tookPause:
            today.pauses += 1
            lost = XP.pausePenalty(forPause: today.pauses)
            points = -League.pausePenalty(forPause: today.pauses)
            healthChange = -PipHealth.pauseCost(forPause: today.pauses)
        case .disabledProtection:
            lost = XP.disabledProtection
            points = -League.Points.disabledProtectionPenalty
            healthChange = -PipHealth.disabledProtection
            streak = 0
            lastActiveDay = nil
        case .scrolled(let minutes):
            // Thresholds can be reported again when monitoring restarts, so only new steps count.
            let reached = min(minutes, PipHealth.scrollMaxMinutes)
            guard reached > today.scrolledMinutes else { return [] }
            let steps = reached / PipHealth.scrollStepMinutes - today.scrolledMinutes / PipHealth.scrollStepMinutes
            today.scrolledMinutes = reached
            healthChange = -steps * PipHealth.perScrollStep
        case .reachedDailyLimit:
            healthChange = -PipHealth.reachedDailyLimit
        case .abandonedFocus:
            lost = XP.abandonedFocus
            points = -League.Points.abandonedFocus
            healthChange = -PipHealth.abandonedFocus
        case .escapedBlock:
            lost = XP.escapedBlock
            points = -League.Points.escapedBlock
            healthChange = -PipHealth.escapedBlock
        }
        health = min(PipHealth.maximum, max(0, health + healthChange))
        weeklyPoints = max(0, weeklyPoints + points)

        var rewards: [Reward] = []
        // Giving in costs XP, but never below the start of the current level, so levels stay earned.
        let taken = min(lost, xp - Level.xpRequired(for: level))
        if taken > 0 {
            xp -= taken
            rewards.append(.xpLost(taken))
        }
        if gained > 0 { rewards.append(.xp(gained)) }

        for quest in Quest.daily(for: day) where !today.completedQuests.contains(quest.id) && quest.progress(in: today) >= quest.target {
            today.completedQuests.insert(quest.id)
            gained += quest.xp
            rewards.append(.quest(quest.id))
        }

        xp += gained
        if level > levelBefore {
            rewards.append(contentsOf: (levelBefore + 1...level).map(Reward.levelUp))
        }
        for achievement in Achievement.all where !unlocked.contains(achievement.id) && achievement.isEarned(self) {
            unlocked.insert(achievement.id)
            rewards.append(.achievement(achievement.id))
        }

        pendingRewards.append(contentsOf: rewards.filter(\.isCelebration))
        if pendingRewards.count > Self.maxPendingRewards {
            pendingRewards.removeFirst(pendingRewards.count - Self.maxPendingRewards)
        }
        return rewards
    }

    /// Awards staying under the daily limit, once, for the day before `date`.
    @discardableResult
    mutating func settleDayUnderLimit(limitWasSet: Bool, limitReachedDay: String?, at date: Date, calendar: Calendar) -> [Reward] {
        let yesterday = DayKey.dayBefore(date, calendar: calendar)
        guard lastSettledDay != yesterday else { return [] }
        lastSettledDay = yesterday
        // Only days the user actually had Paus count.
        guard limitWasSet, limitReachedDay != yesterday, let firstDay, firstDay <= yesterday else { return [] }
        return record(.dayUnderLimit, at: date, calendar: calendar)
    }

    /// Gives Pip the night's recovery once a day has passed since the last one.
    mutating func recoverOvernight(at date: Date, calendar: Calendar) {
        let day = DayKey.string(for: date, calendar: calendar)
        guard healthDay != day else { return }
        if healthDay != nil {
            health = min(PipHealth.maximum, health + PipHealth.overnight)
        }
        healthDay = day
    }

    /// Health the next pause today would cost.
    func nextPauseHealthCost(at date: Date, calendar: Calendar) -> Int {
        PipHealth.pauseCost(forPause: counts(at: date, calendar: calendar).pauses + 1)
    }

    /// League points the next pause today would cost.
    func nextPausePenalty(at date: Date, calendar: Calendar) -> Int {
        League.pausePenalty(forPause: counts(at: date, calendar: calendar).pauses + 1)
    }

    mutating func recordPauseReason(_ reason: PauseReason) {
        pauseReasons[reason.rawValue, default: 0] += 1
    }

    /// League points for the week containing `date`; zero when the stored points belong to an earlier week.
    func pointsThisWeek(at date: Date, calendar: Calendar) -> Int {
        weekKey == League.weekKey(for: date, calendar: calendar) ? weeklyPoints : 0
    }

    /// Starts a new league week when `date` is in a later week, keeping the old one to settle.
    mutating func rollWeek(at date: Date, calendar: Calendar) {
        let key = League.weekKey(for: date, calendar: calendar)
        guard weekKey != key else { return }
        if let weekKey, finishedWeek == nil {
            finishedWeek = FinishedWeek(weekKey: weekKey, points: weeklyPoints, division: division, groupID: leagueGroupID)
        }
        weekKey = key
        weeklyPoints = 0
        leagueGroupID = nil
    }

    /// Moves to the division the finished week earned and queues a celebration when it changed.
    @discardableResult
    mutating func settleFinishedWeek(rank: Int?, groupSize: Int?) -> [Reward] {
        guard let week = finishedWeek else { return [] }
        finishedWeek = nil
        let next = League.nextDivision(after: week, rank: rank, groupSize: groupSize)
        guard next != division else { return [] }
        let reward = Reward.division(next.rawValue, promoted: next > division)
        division = next
        pendingRewards.append(reward)
        return [reward]
    }

    private mutating func markActive(at date: Date, calendar: Calendar) {
        let day = DayKey.string(for: date, calendar: calendar)
        guard lastActiveDay != day else { return }
        streak = lastActiveDay == DayKey.dayBefore(date, calendar: calendar) ? streak + 1 : 1
        lastActiveDay = day
        bestStreak = max(bestStreak, streak)
    }
}

enum Level {
    static var titles: [String] { [
        L("Scrollzombie"), L("Uppvaknad"), L("Nyfiken"), L("Fokusfrö"), L("Skärmtämjare"),
        L("Flowjägare"), L("Zen-ninja"), L("Dopamindetektiv"), L("Tidsmästare"), "Legend",
    ] }

    /// Total XP needed to reach `level`: 0, 100, 300, 600, 1000, …
    static func xpRequired(for level: Int) -> Int {
        50 * (level - 1) * level
    }

    static func level(forXP xp: Int) -> Int {
        var level = 1
        while xpRequired(for: level + 1) <= xp { level += 1 }
        return level
    }

    static func title(for level: Int) -> String {
        titles[min(max(level, 1), titles.count) - 1]
    }

    /// PlayerProgress from the start of the current level to the next, 0...1.
    static func fraction(forXP xp: Int) -> Double {
        let level = level(forXP: xp)
        let start = xpRequired(for: level)
        let end = xpRequired(for: level + 1)
        return Double(xp - start) / Double(end - start)
    }
}

struct Quest: Identifiable {
    enum Metric {
        case focusSessions, focusMinutes, closes, declines
    }

    let id: String
    let title: String
    let symbol: String
    let metric: Metric
    let target: Int
    let xp: Int

    func progress(in counts: DailyCounts) -> Int {
        switch metric {
        case .focusSessions: return counts.focusSessions
        case .focusMinutes: return counts.focusMinutes
        case .closes: return counts.closes
        case .declines: return counts.declines
        }
    }

    static var pool: [Quest] { [
        Quest(id: "focus-1", title: L("Klara ett fokuspass"), symbol: "scope", metric: .focusSessions, target: 1, xp: 40),
        Quest(id: "focus-50", title: L("Fokusera 50 minuter"), symbol: "timer", metric: .focusMinutes, target: 50, xp: 60),
        Quest(id: "close-3", title: L("Stäng en blockerad app 3 gånger"), symbol: "hand.raised.fill", metric: .closes, target: 3, xp: 30),
        Quest(id: "decline-1", title: L("Tacka nej till en paus"), symbol: "wind", metric: .declines, target: 1, xp: 25),
        Quest(id: "focus-2", title: L("Klara två fokuspass"), symbol: "bolt.fill", metric: .focusSessions, target: 2, xp: 70),
    ] }

    /// Three quests for `day`, the same on every device and process.
    static func daily(for day: String) -> [Quest] {
        let seed = day.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        // A step of 2 through 5 quests visits three distinct ones.
        return (0..<3).map { pool[(seed + $0 * 2) % pool.count] }
    }

    static func with(id: String) -> Quest? {
        pool.first { $0.id == id }
    }
}

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let isEarned: (PlayerProgress) -> Bool

    static var all: [Achievement] { [
        Achievement(id: "first-focus", title: L("Första fokuset"), detail: L("Klara ett fokuspass"), symbol: "scope") { $0.focusSessions >= 1 },
        Achievement(id: "focus-10", title: L("Fokusmaskin"), detail: L("Klara 10 fokuspass"), symbol: "bolt.fill") { $0.focusSessions >= 10 },
        Achievement(id: "hours-10", title: L("Tio timmar"), detail: L("Fokusera 10 timmar totalt"), symbol: "hourglass") { $0.focusMinutes >= 600 },
        Achievement(id: "streak-3", title: L("Tre i rad"), detail: L("Håll igång en streak i 3 dagar"), symbol: "flame") { $0.bestStreak >= 3 },
        Achievement(id: "streak-7", title: L("En hel vecka"), detail: L("Håll igång en streak i 7 dagar"), symbol: "flame.fill") { $0.bestStreak >= 7 },
        Achievement(id: "streak-30", title: L("Månadens legend"), detail: L("Håll igång en streak i 30 dagar"), symbol: "calendar") { $0.bestStreak >= 30 },
        Achievement(id: "close-10", title: L("Nej tack, TikTok"), detail: L("Stäng en blockerad app 10 gånger"), symbol: "hand.raised.fill") { $0.closes >= 10 },
        Achievement(id: "close-100", title: L("Järnvilja"), detail: L("Stäng en blockerad app 100 gånger"), symbol: "shield.fill") { $0.closes >= 100 },
        Achievement(id: "decline-5", title: L("Andades och avstod"), detail: L("Tacka nej till en paus 5 gånger"), symbol: "wind") { $0.declines >= 5 },
        Achievement(id: "level-5", title: L("Skärmtämjare"), detail: L("Nå nivå 5"), symbol: "star.fill") { $0.level >= 5 },
        Achievement(id: "level-10", title: "Legend", detail: L("Nå nivå 10"), symbol: "crown.fill") { $0.level >= 10 },
    ] }

    static func with(id: String) -> Achievement? {
        all.first { $0.id == id }
    }
}

/// How the mascot feels, derived from what is going on right now.
enum MascotMood: String, CaseIterable {
    case happy, zen, sleepy, sad, proud, hyped, crying, wrecked

    static func current(reason: BlockReason?, isPaused: Bool, progress: PlayerProgress, at date: Date, calendar: Calendar) -> MascotMood {
        switch reason {
        case .focus, .stepFocus: return .zen
        default: break
        }
        switch progress.healthStage {
        case .wrecked: return .wrecked
        case .sick: return .crying
        case .down: return .sad
        case .okay, .great: break
        }
        if isPaused { return .sad }
        if case .dailyLimit = reason { return .sad }
        let hour = calendar.component(.hour, from: date)
        if hour >= 23 || hour < 6 { return .sleepy }
        let counts = progress.counts(at: date, calendar: calendar)
        if counts.completedQuests.count >= 3 { return .proud }
        if progress.currentStreak(at: date, calendar: calendar) >= 3 { return .hyped }
        return .happy
    }
}

extension PausRules {
    /// The rules in force without Pro: one schedule, no daily limit, no strict focus and no uninstall protection.
    func effective(isPro: Bool) -> PausRules {
        guard !isPro else { return self }
        var rules = self
        rules.schedules = Array(schedules.prefix(1))
        rules.dailyLimitMinutes = nil
        rules.strictFocus = false
        rules.preventUninstall = false
        return rules
    }
}
