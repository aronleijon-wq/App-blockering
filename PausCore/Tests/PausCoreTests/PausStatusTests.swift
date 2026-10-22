import XCTest
@testable import PausCore

final class PausStatusTests: XCTestCase {
    private let calendar = TestCalendar.stockholm
    private let monday10 = TestCalendar.date(2026, 10, 19, 10, 0)
    private let school = BlockSchedule(name: "Skola", weekdays: TestCalendar.weekdays, startMinute: 8 * 60, endMinute: 15 * 60)

    override func setUp() {
        super.setUp()
        Language.override = .sv
    }

    override func tearDown() {
        Language.override = nil
        super.tearDown()
    }

    func testFreeWithoutRules() {
        XCTAssertEqual(PausStatus.at(monday10, rules: PausRules(), runtime: PausRuntime(), calendar: calendar), .free)
    }

    func testSchedule() {
        let status = PausStatus.at(monday10, rules: PausRules(schedules: [school]), runtime: PausRuntime(), calendar: calendar)
        XCTAssertEqual(status.kind, .schedule)
        XCTAssertEqual(status.title, "Skola")
        XCTAssertEqual(status.end, TestCalendar.date(2026, 10, 19, 15, 0))
        XCTAssertTrue(status.isBlocking)
    }

    func testFocus() {
        let end = monday10.addingTimeInterval(25 * 60)
        let status = PausStatus.at(monday10, rules: PausRules(), runtime: PausRuntime(focusStartedAt: monday10, focusEndsAt: end), calendar: calendar)
        XCTAssertEqual(status, PausStatus(kind: .focus, title: "Fokuspass", start: monday10, end: end))
    }

    func testPauseDuringSchedule() {
        let rules = PausRules(schedules: [school], pause: PauseRules(minutes: 5))
        let until = monday10.addingTimeInterval(4 * 60)
        let status = PausStatus.at(monday10, rules: rules, runtime: PausRuntime(pausedUntil: until), calendar: calendar)
        XCTAssertEqual(status.kind, .pause)
        XCTAssertEqual(status.end, until)
        XCTAssertEqual(status.start, until.addingTimeInterval(-5 * 60))
        XCTAssertFalse(status.isBlocking)
    }

    func testLimitLastsUntilMidnight() {
        let status = PausStatus.at(monday10, rules: PausRules(dailyLimitMinutes: 30), runtime: PausRuntime(limitReachedDay: "2026-10-19"), calendar: calendar)
        XCTAssertEqual(status.kind, .limit)
        XCTAssertEqual(status.end, TestCalendar.date(2026, 10, 20, 0, 0))
    }
}
