import XCTest
@testable import PausCore

final class StepUnlockTests: XCTestCase {
    private let calendar = TestCalendar.stockholm
    private let monday10 = TestCalendar.date(2026, 10, 19, 10, 0)
    private let rules = StepRules(isEnabled: true, stepsPerUnlock: 1000, minutesPerUnlock: 5, maxMinutesPerDay: 30)

    private func unlock(_ runtime: PausRuntime = PausRuntime()) -> StepUnlock {
        StepUnlock(rules: rules, runtime: runtime, calendar: calendar)
    }

    func testEveryThousandStepsBuyFiveMinutes() {
        XCTAssertEqual(unlock().availableMinutes(walked: 999, at: monday10), 0)
        XCTAssertEqual(unlock().availableMinutes(walked: 2_400, at: monday10), 10)
        XCTAssertEqual(unlock().stepsToNext(walked: 2_400, at: monday10), 600)
        XCTAssertEqual(unlock().cost(minutes: 10), 2_000)
    }

    func testDailyCapLimitsMinutes() {
        XCTAssertEqual(unlock().availableMinutes(walked: 20_000, at: monday10), 30)
        XCTAssertNil(unlock().stepsToNext(walked: 20_000, at: monday10))
    }

    func testSpentStepsCountAgainstTheDay() {
        var runtime = PausRuntime()
        let end = monday10.addingTimeInterval(10 * 60)
        runtime.spendSteps(2_000, minutes: 10, at: monday10, until: end, calendar: calendar)
        XCTAssertEqual(runtime.pausedUntil, end)
        XCTAssertEqual(runtime.counts(on: monday10, calendar: calendar).pauses, 0)
        XCTAssertEqual(unlock(runtime).availableMinutes(walked: 2_500, at: monday10), 0)
        XCTAssertEqual(unlock(runtime).stepsToNext(walked: 2_500, at: monday10), 500)
        XCTAssertEqual(unlock(runtime).minutesLeftToday(at: monday10), 20)
        // A new day starts from zero.
        let tuesday = TestCalendar.date(2026, 10, 20, 10, 0)
        XCTAssertEqual(unlock(runtime).availableMinutes(walked: 2_500, at: tuesday), 10)
    }

    func testChoicesGoFromOneUnlockToAll() {
        XCTAssertEqual(unlock().choices(walked: 500, at: monday10), [])
        XCTAssertEqual(unlock().choices(walked: 1_000, at: monday10), [5])
        XCTAssertEqual(unlock().choices(walked: 4_000, at: monday10), [5, 10, 20])
    }

    func testStrictFocusCantBeWalkedOutOf() {
        let focus = PausRuntime(focusEndsAt: monday10.addingTimeInterval(1800))
        let strict = BlockEngine(rules: PausRules(strictFocus: true, steps: rules), runtime: focus, calendar: calendar)
        XCTAssertFalse(strict.canSpendSteps(at: monday10))
        let relaxed = BlockEngine(rules: PausRules(strictFocus: false, steps: rules), runtime: focus, calendar: calendar)
        XCTAssertTrue(relaxed.canSpendSteps(at: monday10))
        // Nothing to unlock when nothing is blocked.
        XCTAssertFalse(BlockEngine(rules: PausRules(steps: rules), runtime: PausRuntime(), calendar: calendar).canSpendSteps(at: monday10))
    }

    func testWalkingIsPro() {
        XCTAssertFalse(PausRules(steps: rules).effective(isPro: false).steps.isEnabled)
        XCTAssertTrue(PausRules(steps: rules).effective(isPro: true).steps.isEnabled)
    }

    func testOldSavedRulesDecodeWithWalkingOff() throws {
        let decoded = try JSONDecoder().decode(PausRules.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded.steps, StepRules())
        XCTAssertFalse(decoded.steps.isEnabled)
    }
}
