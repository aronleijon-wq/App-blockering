import XCTest
@testable import PausCore

final class ComebackTests: XCTestCase {
    private let calendar = TestCalendar.stockholm
    private let monday = TestCalendar.date(2026, 11, 9, 10, 0)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: monday)!
    }

    func testTheFirstWeekGivesMoreEachDayAndAColorOnTheSeventh() {
        var progress = PlayerProgress()
        XCTAssertEqual(progress.nextFirstWeekDay, 1)
        let first = progress.record(.claimedDailyReward, at: day(0), calendar: calendar)
        XCTAssertTrue(first.contains(.firstWeekDay(1, seeds: FirstWeek.bonusSeeds(day: 1))))
        XCTAssertEqual(progress.seeds, Seeds.dailyReward + FirstWeek.bonusSeeds(day: 1))
        XCTAssertTrue(progress.record(.claimedDailyReward, at: day(0), calendar: calendar).isEmpty, "once a day")

        // Days don't have to be in a row.
        for offset in [1, 2, 4, 5, 6] {
            progress.record(.claimedDailyReward, at: day(offset), calendar: calendar)
        }
        XCTAssertEqual(progress.rewardDays, 6)
        XCTAssertFalse(progress.owns(WardrobeItem.with(id: FirstWeek.item)!))
        let seventh = progress.record(.claimedDailyReward, at: day(8), calendar: calendar)
        XCTAssertTrue(seventh.contains(.item(FirstWeek.item)))
        XCTAssertTrue(progress.owns(WardrobeItem.with(id: FirstWeek.item)!))
        XCTAssertNil(progress.nextFirstWeekDay)
        let eighth = progress.record(.claimedDailyReward, at: day(9), calendar: calendar)
        XCTAssertFalse(eighth.contains { if case .firstWeekDay = $0 { return true }; return false })
        XCTAssertEqual(progress.buy(WardrobeItem.with(id: FirstWeek.item)!, isPro: true), .alreadyOwned)
    }

    func testAStreakFreezeSavesTheStreakThroughAMissedDay() {
        var progress = PlayerProgress()
        progress.record(.claimedDailyReward, at: day(0), calendar: calendar)
        progress.record(.claimedDailyReward, at: day(1), calendar: calendar)
        XCTAssertEqual(progress.streak, 2)

        progress.seeds = StreakFreeze.price - 1
        XCTAssertFalse(progress.buyStreakFreeze(), "too few seeds")
        progress.seeds = 1_000
        XCTAssertTrue(progress.buyStreakFreeze())
        XCTAssertTrue(progress.buyStreakFreeze())
        XCTAssertFalse(progress.buyStreakFreeze(), "at most two")
        XCTAssertEqual(progress.streakFreezes, 2)

        // Day 2 missed: still alive, and the next claim uses one freeze.
        XCTAssertEqual(progress.currentStreak(at: day(3), calendar: calendar), 2)
        let rewards = progress.record(.claimedDailyReward, at: day(3), calendar: calendar)
        XCTAssertTrue(rewards.contains(.streakSaved(1)))
        XCTAssertEqual(progress.streak, 3)
        XCTAssertEqual(progress.streakFreezes, 1)

        // Two days missed with one freeze left: the streak starts over and the freeze is kept.
        XCTAssertEqual(progress.currentStreak(at: day(6), calendar: calendar), 0)
        progress.record(.claimedDailyReward, at: day(6), calendar: calendar)
        XCTAssertEqual(progress.streak, 1)
        XCTAssertEqual(progress.streakFreezes, 1)
    }

    func testComingBackAfterAFewDaysGivesAGiftOnce() {
        var progress = PlayerProgress()
        progress.record(.claimedDailyReward, at: day(0), calendar: calendar)
        XCTAssertFalse(progress.record(.checkIn, at: day(2), calendar: calendar).contains(.comeback(seeds: Comeback.seeds)),
                       "one day missed isn't away")
        let seeds = progress.seeds
        let rewards = progress.record(.checkIn, at: day(3), calendar: calendar)
        XCTAssertTrue(rewards.contains(.comeback(seeds: Comeback.seeds)))
        // Settling the days away can pay quests too, so at least the gift.
        XCTAssertGreaterThanOrEqual(progress.seeds, seeds + Comeback.seeds)
        XCTAssertFalse(progress.record(.checkIn, at: day(3), calendar: calendar).contains(.comeback(seeds: Comeback.seeds)), "once")
        var newcomer = PlayerProgress()
        XCTAssertFalse(newcomer.record(.checkIn, at: day(0), calendar: calendar).contains(.comeback(seeds: Comeback.seeds)),
                       "not for someone new")
    }

    func testOldSavedProgressHasNoFreezesOrRewardDays() throws {
        let data = try JSONEncoder().encode(PlayerProgress())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "streakFreezes")
        json.removeValue(forKey: "rewardDays")
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(progress.streakFreezes, 0)
        XCTAssertEqual(progress.rewardDays, 0)
    }
}
