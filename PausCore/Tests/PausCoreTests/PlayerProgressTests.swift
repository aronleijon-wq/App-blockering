import XCTest
@testable import PausCore

final class PlayerProgressTests: XCTestCase {
    private let calendar = TestCalendar.stockholm
    private let monday = TestCalendar.date(2026, 10, 19, 10, 0)

    private func day(_ offset: Int, from date: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: date)!
    }

    func testLevelCurve() {
        XCTAssertEqual(Level.level(forXP: 0), 1)
        XCTAssertEqual(Level.level(forXP: 99), 1)
        XCTAssertEqual(Level.level(forXP: 100), 2)
        XCTAssertEqual(Level.level(forXP: 299), 2)
        XCTAssertEqual(Level.level(forXP: 300), 3)
        XCTAssertEqual(Level.level(forXP: 4500), 10)
        XCTAssertEqual(Level.fraction(forXP: 200), 0.5, accuracy: 0.0001)
        XCTAssertEqual(Level.title(for: 1), "Scrollzombie")
        XCTAssertEqual(Level.title(for: 42), "Legend")
    }

    func testFocusSessionEarnsMinutesPlusBonus() {
        var progress = PlayerProgress()
        let rewards = progress.record(.focusCompleted(minutes: 25), at: monday, calendar: calendar)
        XCTAssertEqual(rewards.first, .xp(35))
        XCTAssertEqual(progress.focusSessions, 1)
        XCTAssertEqual(progress.focusMinutes, 25)
        XCTAssertTrue(rewards.contains(.achievement("first-focus")))
        XCTAssertEqual(progress.pendingRewards.filter { if case .xp = $0 { return true }; return false }, [], "plain XP isn't queued")
    }

    func testCloseXPIsCappedPerDay() {
        var progress = PlayerProgress()
        for _ in 0..<(PlayerProgress.XP.closeDailyCap + 3) {
            progress.record(.closedBlockedApp, at: monday, calendar: calendar)
        }
        let questXP = Quest.daily(for: "2026-10-19")
            .filter { $0.metric == .closes && $0.target <= PlayerProgress.XP.closeDailyCap + 3 }
            .map(\.xp).reduce(0, +)
        XCTAssertEqual(progress.xp, PlayerProgress.XP.close * PlayerProgress.XP.closeDailyCap + questXP)
        XCTAssertEqual(progress.closes, PlayerProgress.XP.closeDailyCap + 3)
    }

    func testDailyRewardOncePerDayAndGrowsWithStreak() {
        var progress = PlayerProgress()
        XCTAssertEqual(progress.dailyRewardXP(at: monday, calendar: calendar), 15)
        XCTAssertEqual(progress.record(.claimedDailyReward, at: monday, calendar: calendar).first, .xp(15))
        XCTAssertFalse(progress.canClaimDailyReward(at: monday, calendar: calendar))
        XCTAssertEqual(progress.record(.claimedDailyReward, at: monday, calendar: calendar), [])

        let tuesday = day(1, from: monday)
        XCTAssertTrue(progress.canClaimDailyReward(at: tuesday, calendar: calendar))
        XCTAssertEqual(progress.record(.claimedDailyReward, at: tuesday, calendar: calendar).first, .xp(20))
        XCTAssertEqual(progress.streak, 2)
    }

    func testStreakResetsAfterAMissedDay() {
        var progress = PlayerProgress()
        progress.record(.claimedDailyReward, at: monday, calendar: calendar)
        progress.record(.claimedDailyReward, at: day(1, from: monday), calendar: calendar)
        XCTAssertEqual(progress.currentStreak(at: day(2, from: monday), calendar: calendar), 2, "still alive the next day")
        XCTAssertEqual(progress.currentStreak(at: day(3, from: monday), calendar: calendar), 0, "lapsed after a missed day")

        progress.record(.claimedDailyReward, at: day(3, from: monday), calendar: calendar)
        XCTAssertEqual(progress.streak, 1)
        XCTAssertEqual(progress.bestStreak, 2)
    }

    func testQuestCompletesOnceAndAddsXP() {
        let quests = Quest.daily(for: "2026-10-19")
        XCTAssertEqual(Set(quests.map(\.id)).count, 3, "three distinct quests")

        var progress = PlayerProgress()
        progress.record(.focusCompleted(minutes: 50), at: monday, calendar: calendar)
        progress.record(.focusCompleted(minutes: 50), at: monday, calendar: calendar)
        let focusQuests = quests.filter { [Quest.Metric.focusSessions, .focusMinutes].contains($0.metric) }
        for quest in focusQuests {
            XCTAssertTrue(progress.today.completedQuests.contains(quest.id), quest.id)
        }
        let completedCount = progress.pendingRewards.filter { if case .quest = $0 { return true }; return false }.count
        XCTAssertEqual(completedCount, focusQuests.count)
    }

    func testCountersResetOnNewDay() {
        var progress = PlayerProgress()
        progress.record(.closedBlockedApp, at: monday, calendar: calendar)
        XCTAssertEqual(progress.counts(at: monday, calendar: calendar).closes, 1)
        XCTAssertEqual(progress.counts(at: day(1, from: monday), calendar: calendar).closes, 0)
    }

    func testLevelUpIsReported() {
        var progress = PlayerProgress(xp: 95)
        let rewards = progress.record(.closedBlockedApp, at: monday, calendar: calendar)
        XCTAssertTrue(rewards.contains(.levelUp(2)))
        XCTAssertTrue(progress.pendingRewards.contains(.levelUp(2)))
    }

    func testDayUnderLimitIsAwardedOnceForYesterday() {
        var progress = PlayerProgress(firstDay: "2026-10-18")
        let first = progress.settleDayUnderLimit(limitWasSet: true, limitReachedDay: nil, at: monday, calendar: calendar)
        XCTAssertEqual(first.first, .xp(PlayerProgress.XP.dayUnderLimit))
        XCTAssertEqual(progress.settleDayUnderLimit(limitWasSet: true, limitReachedDay: nil, at: monday, calendar: calendar), [])
    }

    func testDayUnderLimitSkipsReachedLimitAndFirstDay() {
        var reached = PlayerProgress(firstDay: "2026-10-18")
        XCTAssertEqual(reached.settleDayUnderLimit(limitWasSet: true, limitReachedDay: "2026-10-18", at: monday, calendar: calendar), [])

        var newUser = PlayerProgress(firstDay: "2026-10-19")
        XCTAssertEqual(newUser.settleDayUnderLimit(limitWasSet: true, limitReachedDay: nil, at: monday, calendar: calendar), [])

        var noLimit = PlayerProgress(firstDay: "2026-10-01")
        XCTAssertEqual(noLimit.settleDayUnderLimit(limitWasSet: false, limitReachedDay: nil, at: monday, calendar: calendar), [])
    }

    func testPendingRewardsAreBounded() {
        var progress = PlayerProgress(pendingRewards: Array(repeating: .quest("x"), count: PlayerProgress.maxPendingRewards))
        progress.record(.focusCompleted(minutes: 30), at: monday, calendar: calendar)
        XCTAssertEqual(progress.pendingRewards.count, PlayerProgress.maxPendingRewards)
    }

    func testProgressDecodesFromEmptyJSON() throws {
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: Data("{}".utf8))
        XCTAssertEqual(progress, PlayerProgress())
    }

    func testMascotMood() {
        let streaky = PlayerProgress(streak: 4, lastActiveDay: "2026-10-19")
        XCTAssertEqual(MascotMood.current(reason: .focus(until: monday), isPaused: false, progress: PlayerProgress(), at: monday, calendar: calendar), .zen)
        XCTAssertEqual(MascotMood.current(reason: .dailyLimit(minutes: 30), isPaused: false, progress: PlayerProgress(), at: monday, calendar: calendar), .sad)
        XCTAssertEqual(MascotMood.current(reason: nil, isPaused: false, progress: streaky, at: monday, calendar: calendar), .hyped)
        XCTAssertEqual(MascotMood.current(reason: nil, isPaused: false, progress: PlayerProgress(), at: monday, calendar: calendar), .happy)
        let lateNight = TestCalendar.date(2026, 10, 19, 23, 30)
        XCTAssertEqual(MascotMood.current(reason: nil, isPaused: false, progress: PlayerProgress(), at: lateNight, calendar: calendar), .sleepy)
    }

    func testFreeRulesDropProFeatures() {
        let school = BlockSchedule(name: "Skola", weekdays: [2], startMinute: 480, endMinute: 900)
        let evening = BlockSchedule(name: "Kväll", weekdays: [2], startMinute: 1200, endMinute: 1380)
        let rules = PausRules(dailyLimitMinutes: 30, schedules: [school, evening], strictFocus: true)
        let free = rules.effective(isPro: false)
        XCTAssertEqual(free.schedules, [school])
        XCTAssertNil(free.dailyLimitMinutes)
        XCTAssertFalse(free.strictFocus)
        XCTAssertEqual(rules.effective(isPro: true), rules)
    }
}
