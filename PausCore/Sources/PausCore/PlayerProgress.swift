import Foundation

/// Something the user did that can earn XP.
enum ProgressEvent: Equatable {
    case focusCompleted(minutes: Int)
    /// A step session walked to its goal, worth its minutes like a focus session.
    case stepFocusCompleted(minutes: Int)
    /// Added a friend or sent an invite.
    case challengedFriend
    /// Won a weekly duel against a friend.
    case wonDuel
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
    /// Unblocked everything with SOS. Costs more each time the same day.
    case usedSOS
    /// The guarded apps have been used for `minutes` today. Only makes Pip sadder.
    case scrolled(minutes: Int)
    /// Used up the daily limit. Only makes Pip sadder.
    case reachedDailyLimit
    /// Opened Paus. Changes nothing itself, but lets the quests about the whole day be checked in the evening.
    case checkIn
    /// An adult filter lock of `days` days ran its course. `challenge` when it was the November challenge.
    case finishedAdultLock(days: Int, challenge: Bool)
}

enum Reward: Codable, Equatable, Hashable {
    case xp(Int)
    case levelUp(Int)
    case achievement(String)
    case quest(String)
    case division(Int, promoted: Bool)
    /// XP taken away for giving in. Never costs a level.
    case xpLost(Int)
    /// An adult filter lock of this many days ran its course.
    case lockCompleted(days: Int)
    /// A season item for Pip, earned with a season quest.
    case item(String)

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
    var sosUses: Int
    var stepSessions = 0
    /// Focus sessions finished before 10 and from 20 on.
    var morningSessions = 0
    var eveningSessions = 0
    var rewardClaimed = 0
    /// The longest finished focus session, in minutes.
    var longestSession = 0
    var friendActions = 0

    init(day: String? = nil, focusSessions: Int = 0, focusMinutes: Int = 0, closes: Int = 0, declines: Int = 0, completedQuests: Set<String> = [], focusPoints: Int = 0, pauses: Int = 0, scrolledMinutes: Int = 0, sosUses: Int = 0) {
        self.day = day
        self.focusSessions = focusSessions
        self.focusMinutes = focusMinutes
        self.closes = closes
        self.declines = declines
        self.completedQuests = completedQuests
        self.focusPoints = focusPoints
        self.pauses = pauses
        self.scrolledMinutes = scrolledMinutes
        self.sosUses = sosUses
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
        sosUses = try container.decodeIfPresent(Int.self, forKey: .sosUses) ?? 0
        stepSessions = try container.decodeIfPresent(Int.self, forKey: .stepSessions) ?? 0
        morningSessions = try container.decodeIfPresent(Int.self, forKey: .morningSessions) ?? 0
        eveningSessions = try container.decodeIfPresent(Int.self, forKey: .eveningSessions) ?? 0
        rewardClaimed = try container.decodeIfPresent(Int.self, forKey: .rewardClaimed) ?? 0
        longestSession = try container.decodeIfPresent(Int.self, forKey: .longestSession) ?? 0
        friendActions = try container.decodeIfPresent(Int.self, forKey: .friendActions) ?? 0
    }
}

/// Counters for one league week, for the weekly quests.
struct WeeklyCounts: Codable, Equatable {
    var key: String?
    var focusSessions = 0
    var focusMinutes = 0
    var closes = 0
    var declines = 0
    var stepSessions = 0
    /// Days with at least one finished focus session.
    var focusDays = 0
    /// Daily quests finished, bonus quests included.
    var dailyQuests = 0
    var daysUnderLimit = 0
    /// Days the guarded apps were used less than `Quest.calmDayMinutes`.
    var lowScrollDays = 0
    var completedQuests: Set<String> = []

    init(key: String? = nil) {
        self.key = key
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decodeIfPresent(String.self, forKey: .key)
        focusSessions = try container.decodeIfPresent(Int.self, forKey: .focusSessions) ?? 0
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 0
        closes = try container.decodeIfPresent(Int.self, forKey: .closes) ?? 0
        declines = try container.decodeIfPresent(Int.self, forKey: .declines) ?? 0
        stepSessions = try container.decodeIfPresent(Int.self, forKey: .stepSessions) ?? 0
        focusDays = try container.decodeIfPresent(Int.self, forKey: .focusDays) ?? 0
        dailyQuests = try container.decodeIfPresent(Int.self, forKey: .dailyQuests) ?? 0
        daysUnderLimit = try container.decodeIfPresent(Int.self, forKey: .daysUnderLimit) ?? 0
        lowScrollDays = try container.decodeIfPresent(Int.self, forKey: .lowScrollDays) ?? 0
        completedQuests = try container.decodeIfPresent(Set<String>.self, forKey: .completedQuests) ?? []
    }
}

/// XP, level, streak, quests and achievements.
struct PlayerProgress: Codable, Equatable {
    enum XP {
        static let focusBonus = 10
        static let close = 5
        /// Low, so closing a blocked app over and over can't be farmed for points.
        static let closeDailyCap = 3
        static let decline = 10
        static let declineDailyCap = 2
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
    /// This league week's counters, for the weekly quests.
    var week = WeeklyCounts()
    /// This month's counters, for the season quests. Keyed by `Season.key`.
    var month = WeeklyCounts()
    /// Whether quests for Pro features, such as step sessions, can be picked. Set before each event.
    var includesProQuests = false
    /// November challenges finished: the adult filter locked for the rest of November.
    var challengesWon = 0
    /// Whether screen time is measured: apps are picked to guard and no vacation is on. Without it, quests about
    /// the whole day would be free, so they can't complete. Set before each event.
    var tracksUsage = true
    /// Seeds to spend in Pip's wardrobe, and what has been bought and is worn.
    var seeds = 0
    var ownedItems: Set<String> = []
    var outfit = Outfit.none
    /// Finished days, by day key, for the focus calendar and the weekly report.
    var history: [String: DaySummary] = [:]
    /// The league week before this one, kept so duels can be settled against it.
    var lastWeek: FinishedWeek?

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
        week = try container.decodeIfPresent(WeeklyCounts.self, forKey: .week) ?? WeeklyCounts()
        month = try container.decodeIfPresent(WeeklyCounts.self, forKey: .month) ?? WeeklyCounts()
        includesProQuests = try container.decodeIfPresent(Bool.self, forKey: .includesProQuests) ?? false
        challengesWon = try container.decodeIfPresent(Int.self, forKey: .challengesWon) ?? 0
        tracksUsage = try container.decodeIfPresent(Bool.self, forKey: .tracksUsage) ?? true
        seeds = try container.decodeIfPresent(Int.self, forKey: .seeds) ?? 0
        ownedItems = try container.decodeIfPresent(Set<String>.self, forKey: .ownedItems) ?? []
        outfit = try container.decodeIfPresent(Outfit.self, forKey: .outfit) ?? .none
        history = try container.decodeIfPresent([String: DaySummary].self, forKey: .history) ?? [:]
        lastWeek = try container.decodeIfPresent(FinishedWeek.self, forKey: .lastWeek)
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
        let hour = calendar.component(.hour, from: date)
        if firstDay == nil { firstDay = day }
        var settled: [Reward] = []
        if today.day != day {
            settled = settleEndedDay()
            archive(today)
            today = DailyCounts(day: day)
        }
        rollWeek(at: date, calendar: calendar)
        if week.key != weekKey { week = WeeklyCounts(key: weekKey) }
        let monthKey = Season.key(for: date, calendar: calendar)
        if month.key != monthKey { month = WeeklyCounts(key: monthKey) }
        recoverOvernight(at: date, calendar: calendar)
        let levelBefore = level
        var gained = 0
        var lost = 0
        var points = 0
        var healthChange = 0
        var celebrated: [Reward] = []

        switch event {
        case .focusCompleted(let minutes), .stepFocusCompleted(let minutes):
            guard minutes > 0 else { return [] }
            focusSessions += 1
            focusMinutes += minutes
            today.focusSessions += 1
            today.focusMinutes += minutes
            today.longestSession = max(today.longestSession, minutes)
            if hour < 10 { today.morningSessions += 1 }
            if hour >= 20 { today.eveningSessions += 1 }
            if case .stepFocusCompleted = event {
                today.stepSessions += 1
                count { $0.stepSessions += 1 }
            }
            let firstToday = today.focusSessions == 1
            count { counts in
                counts.focusSessions += 1
                counts.focusMinutes += minutes
                if firstToday { counts.focusDays += 1 }
            }
            seeds += Seeds.forFocus(minutes: minutes)
            gained = minutes + XP.focusBonus
            points = min(minutes, max(0, League.Points.focusDailyCap - today.focusPoints))
            today.focusPoints += points
            healthChange = points / PipHealth.focusMinutesPerPoint
            markActive(at: date, calendar: calendar)
        case .closedBlockedApp:
            closes += 1
            today.closes += 1
            week.closes += 1
            gained = today.closes <= XP.closeDailyCap ? XP.close : 0
            points = gained > 0 ? League.Points.close : 0
            healthChange = gained > 0 ? PipHealth.closedBlockedApp : 0
            markActive(at: date, calendar: calendar)
        case .declinedPause:
            declines += 1
            today.declines += 1
            week.declines += 1
            gained = today.declines <= XP.declineDailyCap ? XP.decline : 0
            points = gained > 0 ? League.Points.decline : 0
            healthChange = gained > 0 ? PipHealth.declinedPause : 0
            markActive(at: date, calendar: calendar)
        case .claimedDailyReward:
            guard lastRewardDay != day else { return [] }
            lastRewardDay = day
            today.rewardClaimed = 1
            seeds += Seeds.dailyReward
            // Extend the streak first so the reward reflects it.
            markActive(at: date, calendar: calendar)
            gained = XP.dailyRewardBase + XP.dailyRewardPerStreakDay * min(streak, XP.dailyRewardMaxStreakBonus)
            points = League.Points.dailyReward
            healthChange = PipHealth.dailyReward
        case .dayUnderLimit:
            count { $0.daysUnderLimit += 1 }
            seeds += Seeds.dayUnderLimit
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
        case .challengedFriend:
            guard today.friendActions == 0 else { return [] }
            today.friendActions = 1
        case .wonDuel:
            gained = Duel.winXP
            seeds += Duel.winSeeds
        case .usedSOS:
            today.sosUses += 1
            lost = League.sosPenalty(forUse: today.sosUses)
            points = -lost
            healthChange = -PipHealth.sosCost(forUse: today.sosUses)
        case .checkIn:
            break
        case .finishedAdultLock(let days, let challenge):
            guard days >= AdultLock.minRewardDays else { return [] }
            gained = AdultLock.rewardXP(days: days)
            seeds += AdultLock.rewardSeeds(days: days)
            if challenge { challengesWon += 1 }
            celebrated.append(.lockCompleted(days: days))
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
        rewards.append(contentsOf: celebrated)

        for quest in Quest.available(for: day, week: week.key ?? "", includesPro: includesProQuests, level: level)
        where !isDone(quest) && canComplete(quest) && quest.isMet(today: today, week: week, dayIsOver: false, hour: hour) {
            if quest.tier == .weekly {
                week.completedQuests.insert(quest.id)
            } else {
                today.completedQuests.insert(quest.id)
                count { $0.dailyQuests += 1 }
            }
            seeds += Seeds.forQuest(quest)
            gained += quest.xp
            rewards.append(.quest(quest.id))
        }
        // Finishing the three daily quests can unlock the bonus quest, which may already be done.
        if let bonus = Quest.bonus(for: day, includesPro: includesProQuests, level: level),
           Quest.daily(for: day, includesPro: includesProQuests, level: level).allSatisfy({ today.completedQuests.contains($0.id) }),
           !today.completedQuests.contains(bonus.id), canComplete(bonus),
           bonus.isMet(today: today, week: week, dayIsOver: false, hour: hour) {
            today.completedQuests.insert(bonus.id)
            count { $0.dailyQuests += 1 }
            seeds += Seeds.forQuest(bonus)
            gained += bonus.xp
            rewards.append(.quest(bonus.id))
        }
        let season = completeSeasonQuests()
        gained += season.xp
        rewards.append(contentsOf: season.rewards)

        xp += gained
        if level > levelBefore {
            rewards.append(contentsOf: (levelBefore + 1...level).map(Reward.levelUp))
        }
        for achievement in Achievement.all where !unlocked.contains(achievement.id) && achievement.isEarned(self) {
            unlocked.insert(achievement.id)
            rewards.append(.achievement(achievement.id))
        }

        queueCelebrations(rewards)
        return rewards + settled
    }

    private mutating func queueCelebrations(_ rewards: [Reward]) {
        pendingRewards.append(contentsOf: rewards.filter(\.isCelebration))
        if pendingRewards.count > Self.maxPendingRewards {
            pendingRewards.removeFirst(pendingRewards.count - Self.maxPendingRewards)
        }
    }

    /// When a day ends: its quests about the whole day that held until midnight are done, and a calm day counts
    /// for the week. Covers users who didn't open Paus in the evening. Applied on its own, so the event that
    /// starts the new day can't drop it.
    private mutating func settleEndedDay() -> [Reward] {
        guard let ended = today.day, tracksUsage else { return [] }
        if today.scrolledMinutes < Quest.calmDayMinutes {
            count { $0.lowScrollDays += 1 }
        }
        let levelBefore = level
        var rewards: [Reward] = []
        let daily = Quest.daily(for: ended, includesPro: includesProQuests, level: level)
        var candidates = daily.filter(\.isEvening)
        if let bonus = Quest.bonus(for: ended, includesPro: includesProQuests, level: level) {
            candidates.append(bonus)
        }
        for quest in candidates where !today.completedQuests.contains(quest.id) {
            let isBonus = !daily.contains(where: { $0.id == quest.id })
            if isBonus && !daily.allSatisfy({ today.completedQuests.contains($0.id) }) { continue }
            guard quest.isMet(today: today, week: week, dayIsOver: true, hour: 0) else { continue }
            today.completedQuests.insert(quest.id)
            count { $0.dailyQuests += 1 }
            seeds += Seeds.forQuest(quest)
            xp += quest.xp
            rewards.append(.quest(quest.id))
        }
        // The last day of a league week can finish a weekly quest before the week rolls over.
        if let key = week.key {
            for quest in Quest.weekly(for: key, includesPro: includesProQuests, level: level)
            where !week.completedQuests.contains(quest.id) && quest.isMet(today: today, week: week, dayIsOver: true, hour: 0) {
                week.completedQuests.insert(quest.id)
                seeds += Seeds.forQuest(quest)
                xp += quest.xp
                rewards.append(.quest(quest.id))
            }
        }
        // And the last day of a month a season quest.
        let season = completeSeasonQuests()
        xp += season.xp
        rewards += season.rewards
        if level > levelBefore {
            rewards.append(contentsOf: (levelBefore + 1...level).map(Reward.levelUp))
        }
        queueCelebrations(rewards)
        return rewards
    }

    /// Counts toward this week's and this month's quests alike.
    private mutating func count(_ change: (inout WeeklyCounts) -> Void) {
        change(&week)
        change(&month)
    }

    /// Completes this month's season quests that are met. Each of the first quests gives Pip one of the season's
    /// items, and finishing all of them the season's trophy. Returns the XP for the caller to add.
    private mutating func completeSeasonQuests() -> (xp: Int, rewards: [Reward]) {
        guard let key = month.key else { return (0, []) }
        let season = Season.with(key: key)
        var xpGained = 0
        var rewards: [Reward] = []
        for (index, quest) in season.quests.enumerated()
        where !month.completedQuests.contains(quest.id) && canComplete(quest) && quest.isMet(today: today, week: month, dayIsOver: false, hour: 0) {
            month.completedQuests.insert(quest.id)
            seeds += Seeds.forQuest(quest)
            xpGained += quest.xp
            rewards.append(.quest(quest.id))
            if index < season.items.count, !ownedItems.contains(season.items[index]) {
                ownedItems.insert(season.items[index])
                rewards.append(.item(season.items[index]))
            }
        }
        if !unlocked.contains(season.trophyID), season.quests.allSatisfy({ month.completedQuests.contains($0.id) }) {
            unlocked.insert(season.trophyID)
            rewards.append(.achievement(season.trophyID))
        }
        return (xpGained, rewards)
    }

    /// This month's counters as of `date`; empty when the stored ones belong to an earlier month.
    func monthCounts(at date: Date, calendar: Calendar) -> WeeklyCounts {
        let key = Season.key(for: date, calendar: calendar)
        return month.key == key ? month : WeeklyCounts(key: key)
    }

    /// Quests about screen time need it measured.
    private func canComplete(_ quest: Quest) -> Bool {
        tracksUsage || !quest.needsTracking
    }

    /// Whether `quest` is already done today, or this week for a weekly quest.
    func isDone(_ quest: Quest) -> Bool {
        quest.tier == .weekly ? week.completedQuests.contains(quest.id) : today.completedQuests.contains(quest.id)
    }

    /// This week's counters as of `date`; empty when the stored ones belong to an earlier week.
    func weekCounts(at date: Date, calendar: Calendar) -> WeeklyCounts {
        let key = League.weekKey(for: date, calendar: calendar)
        return week.key == key ? week : WeeklyCounts(key: key)
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
    /// League points (and XP) the next SOS today would cost.
    func nextSOSPenalty(at date: Date, calendar: Calendar) -> Int {
        League.sosPenalty(forUse: counts(at: date, calendar: calendar).sosUses + 1)
    }

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
        if let weekKey {
            let finished = FinishedWeek(weekKey: weekKey, points: weeklyPoints, division: division, groupID: leagueGroupID)
            if finishedWeek == nil { finishedWeek = finished }
            lastWeek = finished
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

    /// The title for `level`. Past Legend, every level is another round of it: Legend II, Legend III and so on.
    static func title(for level: Int) -> String {
        guard level > titles.count else { return titles[max(level, 1) - 1] }
        return "Legend \(roman(level - titles.count + 1))"
    }

    /// Rounds past Legend: 0 below level 11, 1 for Legend II, 2 for Legend III, …
    static func prestige(for level: Int) -> Int {
        max(0, level - titles.count)
    }

    static func roman(_ number: Int) -> String {
        let numerals: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
                                         (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var rest = max(1, number)
        var out = ""
        for (value, numeral) in numerals {
            while rest >= value {
                out += numeral
                rest -= value
            }
        }
        return out
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
        case focusSessions, focusMinutes, closes, declines, stepSessions, morningSessions, eveningSessions, rewardClaimed
        case longestSession, friendActions, focusDays, dailyQuests, daysUnderLimit
        /// The guarded apps used less than `target` minutes today. Decided in the evening.
        case scrollUnder
        /// No pause and no SOS all day. Decided in the evening.
        case noPauses
        case lowScrollDays
    }

    /// From this hour, quests about the whole day count as done if they still hold. At midnight they are settled
    /// for anyone who didn't open Paus in the evening.
    static let eveningHour = 21
    /// A calm day for the weekly quest: the guarded apps used for less than this many minutes.
    static let calmDayMinutes = 120

    enum Tier {
        case easy, medium, hard, weekly
        /// A month's quest, counted from the month's counters. See `Season`.
        case season
    }

    let id: String
    let title: String
    let symbol: String
    let metric: Metric
    let target: Int
    let xp: Int
    let tier: Tier
    /// Needs a Pro feature, so it's only picked for Pro users.
    var needsPro = false

    /// Whether the quest counts over a week or a month rather than a day.
    var countsLonger: Bool { tier == .weekly || tier == .season }

    func progress(today counts: DailyCounts, week: WeeklyCounts) -> Int {
        switch metric {
        case .focusSessions: return countsLonger ? week.focusSessions : counts.focusSessions
        case .focusMinutes: return countsLonger ? week.focusMinutes : counts.focusMinutes
        case .closes: return countsLonger ? week.closes : counts.closes
        case .declines: return countsLonger ? week.declines : counts.declines
        case .stepSessions: return countsLonger ? week.stepSessions : counts.stepSessions
        case .morningSessions: return counts.morningSessions
        case .eveningSessions: return counts.eveningSessions
        case .rewardClaimed: return counts.rewardClaimed
        case .longestSession: return counts.longestSession
        case .friendActions: return counts.friendActions
        case .focusDays: return week.focusDays
        case .dailyQuests: return week.dailyQuests
        case .daysUnderLimit: return week.daysUnderLimit
        case .scrollUnder: return counts.scrolledMinutes
        case .noPauses: return counts.pauses + counts.sosUses
        case .lowScrollDays: return week.lowScrollDays
        }
    }

    /// A quest about the whole day, which can only be decided in the evening.
    var isEvening: Bool {
        metric == .scrollUnder || metric == .noPauses
    }

    /// A quest that only means something while screen time is measured.
    var needsTracking: Bool {
        isEvening || metric == .lowScrollDays
    }

    /// Whether the quest is met: reached its target, or for a quest about the whole day, still holding in the evening.
    func isMet(today counts: DailyCounts, week: WeeklyCounts, dayIsOver: Bool, hour: Int) -> Bool {
        let evening = dayIsOver || hour >= Self.eveningHour
        switch metric {
        case .scrollUnder: return evening && counts.scrolledMinutes < target
        case .noPauses: return evening && counts.pauses == 0 && counts.sosUses == 0
        default: return progress(today: counts, week: week) >= target
        }
    }

    /// Whether a quest about the whole day still holds so far today.
    func isHolding(today counts: DailyCounts) -> Bool {
        switch metric {
        case .scrollUnder: return counts.scrolledMinutes < target
        case .noPauses: return counts.pauses == 0 && counts.sosUses == 0
        default: return true
        }
    }

    static var easyPool: [Quest] { [
        Quest(id: "reward-1", title: L("Hämta dagens belöning"), symbol: "gift.fill", metric: .rewardClaimed, target: 1, xp: 20, tier: .easy),
        Quest(id: "focus-1", title: L("Klara ett fokuspass"), symbol: "scope", metric: .focusSessions, target: 1, xp: 30, tier: .easy),
        Quest(id: "focus-25", title: L("Fokusera 25 minuter"), symbol: "timer", metric: .focusMinutes, target: 25, xp: 30, tier: .easy),
        Quest(id: "friend-1", title: L("Utmana en vän"), symbol: "person.2.fill", metric: .friendActions, target: 1, xp: 25, tier: .easy),
        Quest(id: "scroll-180", title: L("Scrolla mindre än 3 timmar i dag"), symbol: "hourglass", metric: .scrollUnder, target: 180, xp: 35, tier: .easy),
    ] }

    static var mediumPool: [Quest] { [
        Quest(id: "focus-50", title: L("Fokusera 50 minuter"), symbol: "timer", metric: .focusMinutes, target: 50, xp: 60, tier: .medium),
        Quest(id: "focus-2", title: L("Klara två fokuspass"), symbol: "bolt.fill", metric: .focusSessions, target: 2, xp: 60, tier: .medium),
        Quest(id: "morning-1", title: L("Klara ett fokuspass före kl. 10"), symbol: "sunrise.fill", metric: .morningSessions, target: 1, xp: 60, tier: .medium),
        Quest(id: "evening-1", title: L("Klara ett fokuspass efter kl. 20"), symbol: "moon.stars.fill", metric: .eveningSessions, target: 1, xp: 50, tier: .medium),
        Quest(id: "scroll-120", title: L("Scrolla mindre än 2 timmar i dag"), symbol: "hourglass", metric: .scrollUnder, target: 120, xp: 70, tier: .medium),
        Quest(id: "nopause-1", title: L("Ta ingen paus i dag"), symbol: "hand.raised.fill", metric: .noPauses, target: 1, xp: 60, tier: .medium),
        Quest(id: "step-1", title: L("Klara ett stegpass"), symbol: "figure.walk", metric: .stepSessions, target: 1, xp: 70, tier: .medium, needsPro: true),
    ] }

    static var hardPool: [Quest] { [
        Quest(id: "focus-90", title: L("Fokusera 90 minuter"), symbol: "flame.fill", metric: .focusMinutes, target: 90, xp: 100, tier: .hard),
        Quest(id: "focus-3", title: L("Klara tre fokuspass"), symbol: "bolt.fill", metric: .focusSessions, target: 3, xp: 100, tier: .hard),
        Quest(id: "long-60", title: L("Klara ett pass på minst en timme"), symbol: "hourglass", metric: .longestSession, target: 60, xp: 90, tier: .hard),
        Quest(id: "focus-120", title: L("Fokusera två timmar"), symbol: "flame.fill", metric: .focusMinutes, target: 120, xp: 120, tier: .hard),
        Quest(id: "scroll-60", title: L("Scrolla mindre än en timme i dag"), symbol: "leaf.fill", metric: .scrollUnder, target: 60, xp: 120, tier: .hard),
    ] }

    static var weeklyPool: [Quest] { [
        Quest(id: "w-focus-300", title: L("Fokusera 5 timmar den här veckan"), symbol: "trophy.fill", metric: .focusMinutes, target: 300, xp: 250, tier: .weekly),
        Quest(id: "w-focus-600", title: L("Fokusera 10 timmar den här veckan"), symbol: "trophy.fill", metric: .focusMinutes, target: 600, xp: 450, tier: .weekly),
        Quest(id: "w-sessions-10", title: L("Klara 10 fokuspass den här veckan"), symbol: "bolt.circle.fill", metric: .focusSessions, target: 10, xp: 250, tier: .weekly),
        Quest(id: "w-quests-12", title: L("Klara 12 dagliga uppdrag"), symbol: "checklist", metric: .dailyQuests, target: 12, xp: 300, tier: .weekly),
        Quest(id: "w-days-5", title: L("Fokusera fem olika dagar"), symbol: "calendar", metric: .focusDays, target: 5, xp: 250, tier: .weekly),
        Quest(id: "w-calm-5", title: L("Scrolla mindre än 2 timmar fem dagar"), symbol: "leaf.circle.fill", metric: .lowScrollDays, target: 5, xp: 300, tier: .weekly),
        Quest(id: "w-limit-3", title: L("Håll dig under din dagliga gräns tre dagar"), symbol: "checkmark.shield.fill", metric: .daysUnderLimit, target: 3, xp: 200, tier: .weekly, needsPro: true),
        Quest(id: "w-steps-3", title: L("Klara tre stegpass den här veckan"), symbol: "figure.walk.circle.fill", metric: .stepSessions, target: 3, xp: 250, tier: .weekly, needsPro: true),
    ] }

    private static func seedValue(_ key: String) -> Int {
        key.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }

    /// Scatters a seed, so neighbouring days and weeks get unrelated picks. The same on every device.
    private static func mix(_ seed: Int, _ salt: UInt32) -> Int {
        var x = UInt32(truncatingIfNeeded: seed) &+ salt &* 0x9E37_79B9
        x ^= x >> 16
        x = x &* 0x7FEB_352D
        x ^= x >> 15
        x = x &* 0x846C_A68B
        x ^= x >> 16
        return Int(x)
    }

    private static func pool(_ quests: [Quest], includesPro: Bool) -> [Quest] {
        quests.filter { includesPro || !$0.needsPro }
    }

    /// One quest from `quests` that measures something none of `taken` does, so a day never asks for the same
    /// thing twice, such as 25 and 90 minutes of focus.
    private static func pick(from quests: [Quest], avoiding taken: [Quest], seed: Int, salt: UInt32) -> Quest? {
        let fresh = quests.filter { quest in !taken.contains { $0.metric == quest.metric } }
        let options = fresh.isEmpty ? quests.filter { quest in !taken.contains { $0.id == quest.id } } : fresh
        guard !options.isEmpty else { return nil }
        return options[mix(seed, salt) % options.count]
    }

    /// One easy, one medium and one hard quest for `day`, the same on every device and process.
    /// One easy, one medium and one hard quest for `day`, the same on every device and process, sized for `level`.
    static func daily(for day: String, includesPro: Bool = false, level: Int = 1) -> [Quest] {
        let seed = seedValue(day)
        var picked: [Quest] = []
        for (salt, quests) in [(1, easyPool), (2, mediumPool), (3, hardPool)] as [(UInt32, [Quest])] {
            if let quest = pick(from: pool(quests, includesPro: includesPro), avoiding: picked, seed: seed, salt: salt) {
                picked.append(quest)
            }
        }
        return picked.map { $0.scaled(forLevel: level) }
    }

    /// The extra quest that opens once the three daily ones are done: another hard one.
    static func bonus(for day: String, includesPro: Bool = false, level: Int = 1) -> Quest? {
        pick(from: pool(hardPool, includesPro: includesPro), avoiding: daily(for: day, includesPro: includesPro), seed: seedValue(day), salt: 4)?
            .scaled(forLevel: level)
    }

    /// Two quests for the league week `week`, with bigger rewards.
    static func weekly(for week: String, includesPro: Bool = false, level: Int = 1) -> [Quest] {
        let quests = pool(weeklyPool, includesPro: includesPro)
        let seed = seedValue(week)
        guard let first = pick(from: quests, avoiding: [], seed: seed, salt: 5),
              let second = pick(from: quests, avoiding: [first], seed: seed, salt: 6) else { return [] }
        return [first, second].map { $0.scaled(forLevel: level) }
    }

    /// The daily and weekly quests that can complete now. The bonus quest is handled on its own.
    static func available(for day: String, week: String, includesPro: Bool, level: Int = 1) -> [Quest] {
        daily(for: day, includesPro: includesPro, level: level) + (week.isEmpty ? [] : weekly(for: week, includesPro: includesPro, level: level))
    }

    /// The quest with `id` as sized for `level`, including a season's quests.
    static func with(id: String, level: Int = 1) -> Quest? {
        if let season = Season.containing(questID: id) {
            return season.quests.first { $0.id == id }
        }
        return (easyPool + mediumPool + hardPool + weeklyPool).first { $0.id == id }?.scaled(forLevel: level)
    }

    // MARK: Growing with the player

    /// How much bigger focus quests get with the player's level, so they keep being a stretch.
    static func scale(forLevel level: Int) -> Double {
        switch level {
        case ..<5: return 1
        case ..<10: return 1.5
        case ..<15: return 2
        default: return 2.5
        }
    }

    /// The quest with its target and XP grown for `level`. Only quests about focus grow; screen time quests don't,
    /// since less scrolling than the player's own limit would be the wrong kind of harder.
    func scaled(forLevel level: Int) -> Quest {
        let factor = Quest.scale(forLevel: level)
        guard factor > 1 else { return self }
        let weekly = tier == .weekly
        let grown = Double(target) * factor
        let newTarget: Int
        let newTitle: String
        switch metric {
        case .focusMinutes:
            if weekly {
                let hours = min(30, Int((grown / 60).rounded()))
                newTarget = hours * 60
                newTitle = L("Fokusera \(hours) timmar den här veckan")
            } else {
                newTarget = min(240, Int((grown / 5).rounded()) * 5)
                newTitle = newTarget % 60 == 0 ? L("Fokusera \(newTarget / 60) timmar") : L("Fokusera \(newTarget) minuter")
            }
        case .focusSessions:
            newTarget = min(weekly ? 30 : 6, Int(grown.rounded()))
            newTitle = weekly ? L("Klara \(newTarget) fokuspass den här veckan") : L("Klara \(newTarget) fokuspass")
        case .longestSession:
            newTarget = min(120, Int((grown / 15).rounded()) * 15)
            newTitle = L("Klara ett pass på minst \(newTarget) minuter")
        default:
            return self
        }
        guard newTarget > target else { return self }
        let newXP = Int((Double(xp) * Double(newTarget) / Double(target)).rounded())
        return Quest(id: id, title: newTitle, symbol: symbol, metric: metric, target: newTarget, xp: newXP, tier: tier, needsPro: needsPro)
    }
}

struct Achievement: Identifiable {
    /// The medal a trophy in a family of harder and harder ones gives.
    enum Tier: Int, Comparable {
        case bronze, silver, gold, diamond

        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }

        var name: String {
            switch self {
            case .bronze: return L("Brons")
            case .silver: return L("Silver")
            case .gold: return L("Guld")
            case .diamond: return L("Diamant")
            }
        }
    }

    let id: String
    let title: String
    let detail: String
    let symbol: String
    /// Set for trophies in a family, such as 10, 100, 500 and 2 000 focus sessions.
    var family: String? = nil
    var tier: Tier? = nil
    let isEarned: (PlayerProgress) -> Bool

    init(id: String, title: String, detail: String, symbol: String, family: String? = nil, tier: Tier? = nil,
         isEarned: @escaping (PlayerProgress) -> Bool) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.family = family
        self.tier = tier
        self.isEarned = isEarned
    }

    static var all: [Achievement] { [
        Achievement(id: "first-focus", title: L("Första fokuset"), detail: L("Klara ett fokuspass"), symbol: "scope") { $0.focusSessions >= 1 },
        Achievement(id: "focus-10", title: L("Fokusmaskin"), detail: L("Klara 10 fokuspass"), symbol: "bolt.fill", family: "focus", tier: .bronze) { $0.focusSessions >= 10 },
        Achievement(id: "focus-100", title: L("Fokusmaskin"), detail: L("Klara 100 fokuspass"), symbol: "bolt.fill", family: "focus", tier: .silver) { $0.focusSessions >= 100 },
        Achievement(id: "focus-500", title: L("Fokusmaskin"), detail: L("Klara 500 fokuspass"), symbol: "bolt.fill", family: "focus", tier: .gold) { $0.focusSessions >= 500 },
        Achievement(id: "focus-2000", title: L("Fokusmaskin"), detail: L("Klara 2 000 fokuspass"), symbol: "bolt.fill", family: "focus", tier: .diamond) { $0.focusSessions >= 2000 },
        Achievement(id: "hours-10", title: L("Tid tillbaka"), detail: L("Fokusera 10 timmar totalt"), symbol: "hourglass", family: "hours", tier: .bronze) { $0.focusMinutes >= 600 },
        Achievement(id: "hours-100", title: L("Tid tillbaka"), detail: L("Fokusera 100 timmar totalt"), symbol: "hourglass", family: "hours", tier: .silver) { $0.focusMinutes >= 6000 },
        Achievement(id: "hours-500", title: L("Tid tillbaka"), detail: L("Fokusera 500 timmar totalt"), symbol: "hourglass", family: "hours", tier: .gold) { $0.focusMinutes >= 30000 },
        Achievement(id: "hours-2000", title: L("Tid tillbaka"), detail: L("Fokusera 2 000 timmar totalt"), symbol: "hourglass", family: "hours", tier: .diamond) { $0.focusMinutes >= 120000 },
        Achievement(id: "streak-3", title: L("Tre i rad"), detail: L("Håll igång en streak i 3 dagar"), symbol: "flame", family: "streak", tier: .bronze) { $0.bestStreak >= 3 },
        Achievement(id: "streak-7", title: L("En hel vecka"), detail: L("Håll igång en streak i 7 dagar"), symbol: "flame.fill", family: "streak", tier: .silver) { $0.bestStreak >= 7 },
        Achievement(id: "streak-30", title: L("Månadens legend"), detail: L("Håll igång en streak i 30 dagar"), symbol: "calendar", family: "streak", tier: .gold) { $0.bestStreak >= 30 },
        Achievement(id: "streak-100", title: L("Hundra dagar"), detail: L("Håll igång en streak i 100 dagar"), symbol: "flame.circle.fill", family: "streak", tier: .diamond) { $0.bestStreak >= 100 },
        Achievement(id: "level-5", title: L("Skärmtämjare"), detail: L("Nå nivå 5"), symbol: "star.fill", family: "level", tier: .bronze) { $0.level >= 5 },
        Achievement(id: "level-10", title: "Legend", detail: L("Nå nivå 10"), symbol: "crown.fill", family: "level", tier: .silver) { $0.level >= 10 },
        Achievement(id: "level-15", title: "Legend VI", detail: L("Nå nivå 15"), symbol: "crown.fill", family: "level", tier: .gold) { $0.level >= 15 },
        Achievement(id: "level-20", title: "Legend XI", detail: L("Nå nivå 20"), symbol: "crown.fill", family: "level", tier: .diamond) { $0.level >= 20 },
        Achievement(id: "close-10", title: L("Nej tack!"), detail: L("Stäng en blockerad app 10 gånger"), symbol: "hand.raised.fill", family: "close", tier: .bronze) { $0.closes >= 10 },
        Achievement(id: "close-100", title: L("Järnvilja"), detail: L("Stäng en blockerad app 100 gånger"), symbol: "shield.fill", family: "close", tier: .silver) { $0.closes >= 100 },
        Achievement(id: "decline-5", title: L("Andades och avstod"), detail: L("Tacka nej till en paus 5 gånger"), symbol: "wind") { $0.declines >= 5 },
        Achievement(id: "november", title: L("Klarade NNN"), detail: L("Håll vuxenfiltret låst resten av november"), symbol: "trophy.fill") { $0.challengesWon >= 1 },
    ] }

    /// The trophies grouped for the shelf: each family together, the others one by one, in the order of `all`.
    static var shelf: [[Achievement]] {
        var groups: [[Achievement]] = []
        for achievement in all {
            if let family = achievement.family, let index = groups.firstIndex(where: { $0.first?.family == family }) {
                groups[index].append(achievement)
            } else {
                groups.append([achievement])
            }
        }
        return groups
    }

    /// The trophy a group shows: the best one unlocked, or the first to aim for.
    static func shown(in group: [Achievement], unlocked: Set<String>) -> (achievement: Achievement, isUnlocked: Bool, next: Achievement?) {
        guard let best = group.last(where: { unlocked.contains($0.id) }) else {
            return (group[0], false, nil)
        }
        let next = group.first { !unlocked.contains($0.id) }
        return (best, true, next)
    }

    static func with(id: String) -> Achievement? {
        if let season = Season.containing(trophyID: id) { return season.trophy }
        return all.first { $0.id == id }
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

extension MascotMood {
    /// Pip's mood on a day without Paus so far, getting worse as the day goes, like a pet left alone. Nil in the
    /// morning, when there's still plenty of time. Without a streak to lose, Pip stays merely sad.
    static func missing(hour: Int, streak: Int) -> MascotMood? {
        switch hour {
        case ..<12: return nil
        case ..<18: return .sad
        case ..<21: return streak > 0 ? .crying : .sad
        default: return streak > 0 ? .wrecked : .sad
        }
    }
}

extension PausRules {
    /// The rules in force without Pro: one schedule, no daily limit, no strict focus and no uninstall protection.
    func effective(isPro: Bool) -> PausRules {
        guard !isPro else { return self }
        var rules = self
        rules.schedules = Array(schedules.prefix(1))
        rules.dailyLimitMinutes = nil
        rules.openLimit = nil
        rules.strictFocus = false
        rules.preventUninstall = false
        return rules
    }
}
