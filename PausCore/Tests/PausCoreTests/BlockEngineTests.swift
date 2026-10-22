import XCTest
@testable import PausCore

final class BlockEngineTests: XCTestCase {
    private let calendar = TestCalendar.stockholm
    private let monday10 = TestCalendar.date(2026, 10, 19, 10, 0)
    private let school = BlockSchedule(name: "Skola", weekdays: TestCalendar.weekdays, startMinute: 8 * 60, endMinute: 15 * 60)

    private func engine(rules: PausRules = PausRules(), runtime: PausRuntime = PausRuntime()) -> BlockEngine {
        BlockEngine(rules: rules, runtime: runtime, calendar: calendar)
    }

    func testNothingBlockedWithoutRules() {
        XCTAssertNil(engine().reason(at: monday10))
        XCTAssertFalse(engine().shouldShield(at: monday10))
    }

    func testVacationRestsSchedulesAndLimitButNotFocus() {
        let rules = PausRules(dailyLimitMinutes: 30, schedules: [school], vacationUntil: monday10.addingTimeInterval(3600))
        XCTAssertNil(engine(rules: rules, runtime: PausRuntime(limitReachedDay: "2026-10-19")).reason(at: monday10))
        let focusEnd = monday10.addingTimeInterval(25 * 60)
        XCTAssertEqual(engine(rules: rules, runtime: PausRuntime(focusEndsAt: focusEnd)).reason(at: monday10), .focus(until: focusEnd))
        // Once the vacation is over the schedule applies again.
        XCTAssertNotNil(engine(rules: rules).reason(at: monday10.addingTimeInterval(2 * 3600)))
    }

    func testFreeUsersDontGetUninstallProtection() {
        let rules = PausRules(preventUninstall: true, adultFilter: true)
        XCTAssertFalse(rules.effective(isPro: false).preventUninstall)
        XCTAssertTrue(rules.effective(isPro: false).adultFilter)
        XCTAssertTrue(rules.effective(isPro: true).preventUninstall)
    }

    func testFocusWinsOverSchedule() {
        let focusEnd = monday10.addingTimeInterval(25 * 60)
        let sut = engine(rules: PausRules(schedules: [school]), runtime: PausRuntime(focusEndsAt: focusEnd))
        XCTAssertEqual(sut.reason(at: monday10), .focus(until: focusEnd))
    }

    func testExpiredFocusFallsBackToSchedule() {
        let sut = engine(rules: PausRules(schedules: [school]), runtime: PausRuntime(focusEndsAt: monday10))
        XCTAssertEqual(sut.reason(at: monday10), .schedule(name: "Skola", until: TestCalendar.date(2026, 10, 19, 15, 0)))
    }

    func testDailyLimitOnlyCountsTheDayItWasReached() {
        let rules = PausRules(dailyLimitMinutes: 30)
        let today = engine(rules: rules, runtime: PausRuntime(limitReachedDay: "2026-10-19"))
        let yesterday = engine(rules: rules, runtime: PausRuntime(limitReachedDay: "2026-10-18"))
        XCTAssertEqual(today.reason(at: monday10), .dailyLimit(minutes: 30))
        XCTAssertNil(yesterday.reason(at: monday10))
    }

    func testRemovedLimitNoLongerBlocks() {
        let sut = engine(rules: PausRules(dailyLimitMinutes: nil), runtime: PausRuntime(limitReachedDay: "2026-10-19"))
        XCTAssertNil(sut.reason(at: monday10))
    }

    func testPauseLiftsSchedule() {
        let runtime = PausRuntime(pausedUntil: monday10.addingTimeInterval(300))
        let sut = engine(rules: PausRules(schedules: [school]), runtime: runtime)
        XCTAssertNotNil(sut.reason(at: monday10))
        XCTAssertFalse(sut.shouldShield(at: monday10))
        XCTAssertTrue(sut.shouldShield(at: monday10.addingTimeInterval(301)))
    }

    func testPauseDoesNotLiftStrictFocus() {
        let runtime = PausRuntime(focusEndsAt: monday10.addingTimeInterval(1500), pausedUntil: monday10.addingTimeInterval(300))
        XCTAssertTrue(engine(rules: PausRules(strictFocus: true), runtime: runtime).shouldShield(at: monday10))
        XCTAssertFalse(engine(rules: PausRules(strictFocus: false), runtime: runtime).shouldShield(at: monday10))
    }

    func testCanPauseRequiresAnActiveNonStrictBlock() {
        let focus = PausRuntime(focusEndsAt: monday10.addingTimeInterval(1500))
        XCTAssertFalse(engine().canPause(at: monday10), "nothing is blocked")
        XCTAssertFalse(engine(rules: PausRules(strictFocus: true), runtime: focus).canPause(at: monday10))
        XCTAssertTrue(engine(rules: PausRules(strictFocus: false), runtime: focus).canPause(at: monday10))
        XCTAssertTrue(engine(rules: PausRules(schedules: [school])).canPause(at: monday10))
    }

    func testCanPauseRespectsSettingsAndDailyAllowance() {
        var disabled = PausRules(schedules: [school])
        disabled.pause.isEnabled = false
        XCTAssertFalse(engine(rules: disabled).canPause(at: monday10))

        var rules = PausRules(schedules: [school])
        rules.pause.maxPerDay = 2
        let usedUp = PausRuntime(statsDay: "2026-10-19", pausesUsed: 2)
        XCTAssertEqual(engine(rules: rules, runtime: usedUp).pausesLeft(at: monday10), 0)
        XCTAssertFalse(engine(rules: rules, runtime: usedUp).canPause(at: monday10))

        let usedYesterday = PausRuntime(statsDay: "2026-10-18", pausesUsed: 2)
        XCTAssertEqual(engine(rules: rules, runtime: usedYesterday).pausesLeft(at: monday10), 2)
    }

    func testCannotStackPauses() {
        let runtime = PausRuntime(pausedUntil: monday10.addingTimeInterval(120))
        XCTAssertFalse(engine(rules: PausRules(schedules: [school]), runtime: runtime).canPause(at: monday10))
    }

    func testScheduleOverridesAbsorbEarlyCallbacks() {
        let sut = engine(rules: PausRules(schedules: [school]))
        let justBeforeStart = TestCalendar.date(2026, 10, 19, 7, 59).addingTimeInterval(59)
        XCTAssertNil(sut.reason(at: justBeforeStart))
        XCTAssertNotNil(sut.reason(at: justBeforeStart, scheduleOverrides: [school.id: true]))

        let justBeforeEnd = TestCalendar.date(2026, 10, 19, 14, 59).addingTimeInterval(59)
        XCTAssertNotNil(sut.reason(at: justBeforeEnd))
        XCTAssertNil(sut.reason(at: justBeforeEnd, scheduleOverrides: [school.id: false]))
    }

    func testStartOverrideRespectsWeekdays() {
        // A daily DeviceActivity interval also fires on Saturday; the schedule itself is weekdays only.
        let saturdayStart = TestCalendar.date(2026, 10, 24, 8, 0)
        let sut = engine(rules: PausRules(schedules: [school]))
        XCTAssertNil(sut.reason(at: saturdayStart, scheduleOverrides: [school.id: true]))
    }
}

final class PausRuntimeTests: XCTestCase {
    private let calendar = TestCalendar.stockholm

    func testStartPauseCountsAndRollsOverDays() {
        var runtime = PausRuntime(statsDay: "2026-10-18", pausesUsed: 3, closedCount: 7)
        let now = TestCalendar.date(2026, 10, 19, 10, 0)
        runtime.startPause(at: now, until: now.addingTimeInterval(300), calendar: calendar)
        XCTAssertEqual(runtime.statsDay, "2026-10-19")
        XCTAssertEqual(runtime.pausesUsed, 1)
        XCTAssertEqual(runtime.closedCount, 0)
        XCTAssertEqual(runtime.pausedUntil, now.addingTimeInterval(300))
    }

    func testCountsAreZeroOnAnotherDay() {
        let runtime = PausRuntime(statsDay: "2026-10-18", pausesUsed: 2, closedCount: 5)
        let counts = runtime.counts(on: TestCalendar.date(2026, 10, 19, 9, 0), calendar: calendar)
        XCTAssertEqual(counts.pauses, 0)
        XCTAssertEqual(counts.closed, 0)
    }

    func testRulesDecodeMissingKeysAsDefaults() throws {
        let rules = try JSONDecoder().decode(PausRules.self, from: Data(#"{"dailyLimitMinutes":45}"#.utf8))
        XCTAssertEqual(rules.dailyLimitMinutes, 45)
        XCTAssertEqual(rules.schedules, [])
        XCTAssertTrue(rules.strictFocus)
        XCTAssertEqual(rules.pause, PauseRules())
    }

    func testRuntimeRoundTrips() throws {
        let runtime = PausRuntime(focusEndsAt: Date(timeIntervalSince1970: 1_800_000_000), limitReachedDay: "2026-10-19", pausesUsed: 1)
        let data = try JSONEncoder().encode(runtime)
        XCTAssertEqual(try JSONDecoder().decode(PausRuntime.self, from: data), runtime)
    }
}
