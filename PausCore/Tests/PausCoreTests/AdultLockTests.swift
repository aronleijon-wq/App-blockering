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
        XCTAssertTrue(rewards.contains(.item(AdultLock.challengeItem)), "the NNN medal")
        XCTAssertTrue(progress.owns(WardrobeItem.with(id: AdultLock.challengeItem)!))
        XCTAssertEqual(progress.buy(WardrobeItem.with(id: AdultLock.challengeItem)!, isPro: true), .alreadyOwned)

        var other = PlayerProgress()
        other.seeds = 10_000
        other.record(.finishedAdultLock(days: 30, challenge: false), at: november2, calendar: calendar)
        XCTAssertFalse(other.owns(WardrobeItem.with(id: AdultLock.challengeItem)!), "only the NNN challenge gives the medal")
        XCTAssertEqual(other.buy(WardrobeItem.with(id: AdultLock.challengeItem)!, isPro: true), .seasonOnly)
    }

    func testAGivenUpLockLetsGoADayLaterUnlessTakenBack() throws {
        let end = AdultLock.endOfMonth(after: november2, calendar: calendar)
        XCTAssertTrue(AdultLock.canGiveUp(until: end, at: november2))
        XCTAssertFalse(AdultLock.canGiveUp(until: november2.addingTimeInterval(20 * 3600), at: november2), "ends sooner than the wait")

        let release = november2.addingTimeInterval(AdultLock.giveUpDelay)
        let rules = PausRules(adultFilter: true, adultFilterLockedUntil: end, adultFilterLockedAt: november2, adultFilterReleaseAt: release)
        XCTAssertTrue(rules.isAdultFilterLocked(at: november2.addingTimeInterval(3600)), "still locked while waiting")
        XCTAssertTrue(rules.isGivingUpAdultLock(at: november2.addingTimeInterval(3600)))
        XCTAssertFalse(rules.isAdultFilterLocked(at: release))
        XCTAssertTrue(rules.blocksAdultSites(at: release), "the filter stays on until turned off")

        let roundTripped = try JSONDecoder().decode(PausRules.self, from: JSONEncoder().encode(rules))
        XCTAssertEqual(roundTripped, rules)
        XCTAssertNil(try JSONDecoder().decode(PausRules.self, from: Data(#"{"adultFilter": true}"#.utf8)).adultFilterReleaseAt)
    }

    func testGivingUpCostsALotOfXPAndTheMedalForTheYear() {
        XCTAssertEqual(AdultLock.giveUpXP(days: 3), 200)
        XCTAssertEqual(AdultLock.giveUpXP(days: 29), 2 * AdultLock.rewardXP(days: 29))

        var progress = PlayerProgress()
        progress.xp = 1_000
        XCTAssertEqual(progress.giveUpAdultLock(days: 29), 580)
        XCTAssertEqual(progress.xp, 420)
        progress.giveUpAdultLock(days: 29)
        XCTAssertEqual(progress.xp, 0, "never below zero")

        let rules = PausRules(adultChallengeForfeitedYear: 2026)
        XCTAssertTrue(rules.hasForfeitedChallenge(at: november2, calendar: calendar))
        XCTAssertFalse(rules.hasForfeitedChallenge(at: TestCalendar.date(2027, 11, 2, 12, 0), calendar: calendar), "next November is a new chance")
        XCTAssertFalse(PausRules().hasForfeitedChallenge(at: november2, calendar: calendar))
    }

    func testTheChallengeIsOfferedUpTo34() {
        XCTAssertTrue(AdultLock.offersChallenge(to: .under18))
        XCTAssertTrue(AdultLock.offersChallenge(to: .from18))
        XCTAssertTrue(AdultLock.offersChallenge(to: .from25))
        XCTAssertFalse(AdultLock.offersChallenge(to: .from35))
        XCTAssertFalse(AdultLock.offersChallenge(to: .from55))
        XCTAssertTrue(AdultLock.offersChallenge(to: nil), "no answer from the intro")
    }
}
