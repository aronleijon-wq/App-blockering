import XCTest
@testable import PausCore

final class AdultLockTests: XCTestCase {
    private let calendar = TestCalendar.stockholm
    private let november2 = TestCalendar.date(2026, 11, 2, 14, 30)

    func testTheRestOfNovemberEndsAsDecemberStarts() {
        let end = AdultLock.endOfMonth(after: november2, calendar: calendar)
        XCTAssertEqual(end, TestCalendar.date(2026, 12, 1, 0, 0))
        XCTAssertEqual(AdultLock.daysLeft(until: end, from: november2, calendar: calendar), 29, "today counts")
        XCTAssertEqual(AdultLock.daysLeft(until: end, from: TestCalendar.date(2026, 11, 30, 23, 0), calendar: calendar), 1)
        XCTAssertEqual(AdultLock.daysLeft(until: end, from: end, calendar: calendar), 0)
    }

    func testDaysCountTodayAndEndAtMidnight() {
        XCTAssertEqual(AdultLock.end(days: 7, from: november2, calendar: calendar), TestCalendar.date(2026, 11, 9, 0, 0))
        XCTAssertEqual(AdultLock.end(days: 0, from: november2, calendar: calendar), TestCalendar.date(2026, 11, 3, 0, 0), "at least a day")
        let longest = AdultLock.end(days: 10_000, from: november2, calendar: calendar)
        XCTAssertEqual(AdultLock.daysLeft(until: longest, from: november2, calendar: calendar), AdultLock.maxDays)
    }

    func testALockKeepsTheFilterOnUntilItEnds() {
        let end = AdultLock.endOfMonth(after: november2, calendar: calendar)
        let rules = PausRules(adultFilter: false, adultFilterLockedUntil: end)
        XCTAssertTrue(rules.isAdultFilterLocked(at: november2))
        XCTAssertTrue(rules.blocksAdultSites(at: november2))
        XCTAssertTrue(rules.effective(isPro: false).blocksAdultSites(at: november2), "free users can lock it too")
        XCTAssertFalse(rules.isAdultFilterLocked(at: end))
        XCTAssertFalse(rules.blocksAdultSites(at: end), "after the lock, the filter follows its own setting")
        XCTAssertTrue(PausRules(adultFilter: true).blocksAdultSites(at: november2))
    }

    func testOldSavedRulesHaveNoLock() throws {
        let rules = try JSONDecoder().decode(PausRules.self, from: Data(#"{"adultFilter": true}"#.utf8))
        XCTAssertNil(rules.adultFilterLockedUntil)
        XCTAssertTrue(rules.blocksAdultSites(at: november2))
        let locked = PausRules(adultFilterLockedUntil: november2.addingTimeInterval(86_400))
        let roundTripped = try JSONDecoder().decode(PausRules.self, from: JSONEncoder().encode(locked))
        XCTAssertEqual(roundTripped, locked)
    }

    func testTheChallengeIsOfferedInNovemberWhileThereIsTimeLeft() {
        XCTAssertTrue(AdultLock.offersChallenge(at: november2, calendar: calendar))
        XCTAssertFalse(AdultLock.offersChallenge(at: TestCalendar.date(2026, 11, 29, 12, 0), calendar: calendar), "two days left")
        XCTAssertFalse(AdultLock.offersChallenge(at: TestCalendar.date(2026, 10, 15, 12, 0), calendar: calendar))

        let december = TestCalendar.date(2026, 12, 1, 0, 0)
        XCTAssertTrue(AdultLock.isChallenge(from: november2, to: december, calendar: calendar))
        XCTAssertTrue(AdultLock.isChallenge(from: november2, to: december.addingTimeInterval(7 * 86_400), calendar: calendar), "extended")
        XCTAssertFalse(AdultLock.isChallenge(from: november2, to: TestCalendar.date(2026, 11, 9, 0, 0), calendar: calendar))
        XCTAssertFalse(AdultLock.isChallenge(from: TestCalendar.date(2026, 10, 30, 12, 0), to: december, calendar: calendar))
    }

    func testAFinishedLockPaysOutAndTheChallengeEarnsATrophy() {
        XCTAssertEqual(AdultLock.rewardXP(days: AdultLock.minRewardDays - 1), 0)
        XCTAssertEqual(AdultLock.rewardXP(days: 29), 290)
        XCTAssertEqual(AdultLock.rewardXP(days: 365), AdultLock.rewardXP(days: AdultLock.maxRewardDays))

        var progress = PlayerProgress()
        XCTAssertEqual(progress.record(.finishedAdultLock(days: 3, challenge: false), at: november2, calendar: calendar), [], "too short to earn")

        let rewards = progress.record(.finishedAdultLock(days: 29, challenge: true), at: november2, calendar: calendar)
        XCTAssertTrue(rewards.contains(.lockCompleted(days: 29)))
        XCTAssertTrue(rewards.contains(.achievement("november")))
        XCTAssertTrue(progress.pendingRewards.contains(.lockCompleted(days: 29)))
        XCTAssertGreaterThanOrEqual(progress.xp, AdultLock.rewardXP(days: 29))
        XCTAssertGreaterThanOrEqual(progress.seeds, AdultLock.rewardSeeds(days: 29))
        XCTAssertEqual(progress.challengesWon, 1)
    }
}
