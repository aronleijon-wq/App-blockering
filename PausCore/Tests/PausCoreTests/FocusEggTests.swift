import XCTest
@testable import PausCore

final class FocusEggTests: XCTestCase {
    private let calendar = TestCalendar.stockholm
    private let monday = TestCalendar.date(2026, 11, 9, 10, 0)

    func testLongerSessionsHaveBetterOdds() {
        XCTAssertNil(FocusEgg.rarity(minutes: 5, roll: 0), "too short to hatch")
        for minutes in [10, 25, 50, 90, 180] {
            XCTAssertEqual(FocusEgg.odds(minutes: minutes).reduce(0, +), 100, "\(minutes)")
        }
        XCTAssertLessThan(FocusEgg.odds(minutes: 15)[3], FocusEgg.odds(minutes: 90)[3])
        XCTAssertEqual(FocusEgg.rarity(minutes: 25, roll: 0), .common)
        XCTAssertEqual(FocusEgg.rarity(minutes: 25, roll: 99), .legendary)
        XCTAssertEqual(FocusEgg.roll(session: 3, day: "2026-11-09"), FocusEgg.roll(session: 3, day: "2026-11-09"), "the same session rolls the same")
        let rolls = (0..<500).map { FocusEgg.roll(session: $0, day: "2026-11-09") }
        XCTAssertTrue(rolls.allSatisfy { (0..<100).contains($0) })
        XCTAssertGreaterThan(Set(rolls).count, 80, "rolls spread out")
    }

    func testEveryFocusSessionHatchesAnEggAndPlainOnesEndInAnEpic() {
        var progress = PlayerProgress()
        var best: [FocusEgg.Rarity] = []
        for _ in 0..<40 {
            let rewards = progress.record(.focusCompleted(minutes: 25), at: monday, calendar: calendar)
            let eggs = rewards.compactMap { reward -> FocusEgg.Rarity? in
                if case .egg(let raw, _, _) = reward { return FocusEgg.Rarity(rawValue: raw) }
                return nil
            }
            XCTAssertEqual(eggs.count, 1)
            best.append(contentsOf: eggs)
        }
        XCTAssertEqual(progress.eggsHatchedCount, 40)
        // Never more than pityAfter - 1 plain eggs in a row.
        var plain = 0
        for rarity in best {
            plain = rarity >= .epic ? 0 : plain + 1
            XCTAssertLessThan(plain, FocusEgg.pityAfter)
        }
        XCTAssertNil(progress.record(.focusCompleted(minutes: 5), at: monday, calendar: calendar).first { reward in
            if case .egg = reward { return true }
            return false
        }, "a short session hatches nothing")
    }

    func testEggColorsCantBeBought() {
        let opal = WardrobeItem.with(id: "color-opal")!
        var progress = PlayerProgress()
        progress.seeds = 10_000
        XCTAssertEqual(progress.buy(opal, isPro: true), .seasonOnly)
    }

    func testTheYearAddsUpItsDays() {
        var progress = PlayerProgress()
        progress.history = [
            "2026-03-02": DaySummary(focusMinutes: 50, focusSessions: 2, closes: 3),
            "2026-11-03": DaySummary(focusMinutes: 120, focusSessions: 3, closes: 1),
            "2025-12-30": DaySummary(focusMinutes: 999, focusSessions: 9),
        ]
        progress.record(.focusCompleted(minutes: 30), at: monday, calendar: calendar)
        let year = YearInReview.make(from: progress, year: 2026, at: monday, calendar: calendar)
        XCTAssertEqual(year.focusMinutes, 200)
        XCTAssertEqual(year.focusSessions, 6)
        XCTAssertEqual(year.closes, 4)
        XCTAssertEqual(year.focusDays, 3)
        XCTAssertEqual(year.bestDay, "2026-11-03")
        XCTAssertEqual(year.bestDayMinutes, 120)
        XCTAssertEqual(year.bestMonth, 11)
        XCTAssertEqual(year.eggs, 1)

        XCTAssertEqual(YearInReview.season(at: TestCalendar.date(2026, 12, 3, 12, 0), calendar: calendar), 2026)
        XCTAssertEqual(YearInReview.season(at: TestCalendar.date(2027, 1, 10, 12, 0), calendar: calendar), 2026)
        XCTAssertNil(YearInReview.season(at: monday, calendar: calendar))
    }
}
