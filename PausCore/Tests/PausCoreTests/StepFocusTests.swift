import XCTest
@testable import PausCore

final class StepFocusTests: XCTestCase {
    private let calendar = TestCalendar.stockholm
    private let monday10 = TestCalendar.date(2026, 10, 19, 10, 0)
    private let school = BlockSchedule(name: "Skola", weekdays: TestCalendar.weekdays, startMinute: 8 * 60, endMinute: 15 * 60)

    private func stepSession(goal: Int = 2000) -> PausRuntime {
        PausRuntime(focusStartedAt: monday10, focusEndsAt: monday10.addingTimeInterval(StepFocus.backstop), focusStepGoal: goal)
    }

    func testAStepSessionBlocksUntilItEnds() {
        let engine = BlockEngine(rules: PausRules(strictFocus: false), runtime: stepSession(), calendar: calendar)
        XCTAssertEqual(engine.reason(at: monday10.addingTimeInterval(3600)), .stepFocus(goal: 2000))
        XCTAssertTrue(engine.shouldShield(at: monday10.addingTimeInterval(3600)))
        XCTAssertNil(engine.reason(at: monday10.addingTimeInterval(StepFocus.backstop + 1)))
    }

    func testAStepSessionCantBePausedEvenWithoutStrictFocus() {
        var runtime = stepSession()
        XCTAssertFalse(BlockEngine(rules: PausRules(strictFocus: false), runtime: runtime, calendar: calendar).canPause(at: monday10))
        // Not even a pause that somehow got started lifts it.
        runtime.pausedUntil = monday10.addingTimeInterval(300)
        XCTAssertTrue(BlockEngine(rules: PausRules(strictFocus: false), runtime: runtime, calendar: calendar).shouldShield(at: monday10))
    }

    func testAStepSessionWinsOverASchedule() {
        let engine = BlockEngine(rules: PausRules(schedules: [school]), runtime: stepSession(goal: 5000), calendar: calendar)
        XCTAssertEqual(engine.reason(at: monday10), .stepFocus(goal: 5000))
    }

    func testRewardGrowsWithTheWalkUpToACap() {
        XCTAssertEqual(StepFocus.rewardMinutes(from: monday10, to: monday10.addingTimeInterval(20 * 60)), 20)
        XCTAssertEqual(StepFocus.rewardMinutes(from: monday10, to: monday10.addingTimeInterval(10)), 1)
        XCTAssertEqual(StepFocus.rewardMinutes(from: monday10, to: monday10.addingTimeInterval(5 * 3600)), StepFocus.maxRewardMinutes)
    }

    func testOldSavedRuntimeHasNoStepSession() throws {
        let decoded = try JSONDecoder().decode(PausRuntime.self, from: Data("{}".utf8))
        XCTAssertNil(decoded.focusStepGoal)
    }

    func testStatusHasNoCountdownForAStepSession() {
        let status = PausStatus.at(monday10.addingTimeInterval(60), rules: PausRules(), runtime: stepSession(), calendar: calendar)
        XCTAssertEqual(status.kind, .focus)
        XCTAssertNil(status.end)
    }
}
