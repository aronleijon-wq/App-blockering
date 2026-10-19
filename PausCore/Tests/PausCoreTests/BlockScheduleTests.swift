import XCTest
@testable import PausCore

final class BlockScheduleTests: XCTestCase {
    private let calendar = TestCalendar.stockholm

    func testDaytimeWindowOnSelectedWeekday() {
        let school = BlockSchedule(name: "Skola", weekdays: TestCalendar.weekdays, startMinute: 8 * 60, endMinute: 15 * 60)
        // 2026-10-19 is a Monday.
        let window = school.activeWindow(containing: TestCalendar.date(2026, 10, 19, 10, 0), calendar: calendar)
        XCTAssertEqual(window?.start, TestCalendar.date(2026, 10, 19, 8, 0))
        XCTAssertEqual(window?.end, TestCalendar.date(2026, 10, 19, 15, 0))
    }

    func testDaytimeWindowBoundaries() {
        let school = BlockSchedule(name: "Skola", weekdays: TestCalendar.weekdays, startMinute: 8 * 60, endMinute: 15 * 60)
        XCTAssertNil(school.activeWindow(containing: TestCalendar.date(2026, 10, 19, 7, 59), calendar: calendar))
        XCTAssertNotNil(school.activeWindow(containing: TestCalendar.date(2026, 10, 19, 8, 0), calendar: calendar))
        XCTAssertNil(school.activeWindow(containing: TestCalendar.date(2026, 10, 19, 15, 0), calendar: calendar))
    }

    func testInactiveOnUnselectedWeekday() {
        let school = BlockSchedule(name: "Skola", weekdays: TestCalendar.weekdays, startMinute: 8 * 60, endMinute: 15 * 60)
        // 2026-10-24 is a Saturday.
        XCTAssertNil(school.activeWindow(containing: TestCalendar.date(2026, 10, 24, 10, 0), calendar: calendar))
    }

    func testOvernightWindowBelongsToTheDayItStarts() {
        // Friday night only: 22:00 to 07:00.
        let night = BlockSchedule(name: "Natt", weekdays: [6], startMinute: 22 * 60, endMinute: 7 * 60)
        XCTAssertTrue(night.crossesMidnight)
        XCTAssertNotNil(night.activeWindow(containing: TestCalendar.date(2026, 10, 23, 23, 0), calendar: calendar))
        let saturdayMorning = night.activeWindow(containing: TestCalendar.date(2026, 10, 24, 6, 0), calendar: calendar)
        XCTAssertEqual(saturdayMorning?.end, TestCalendar.date(2026, 10, 24, 7, 0))
        XCTAssertNil(night.activeWindow(containing: TestCalendar.date(2026, 10, 24, 23, 0), calendar: calendar))
        XCTAssertNil(night.activeWindow(containing: TestCalendar.date(2026, 10, 22, 23, 0), calendar: calendar))
    }

    func testDisabledScheduleIsNeverActive() {
        let school = BlockSchedule(name: "Skola", weekdays: TestCalendar.weekdays, startMinute: 8 * 60, endMinute: 15 * 60, isEnabled: false)
        XCTAssertNil(school.activeWindow(containing: TestCalendar.date(2026, 10, 19, 10, 0), calendar: calendar))
    }

    func testDurationMinutes() {
        XCTAssertEqual(BlockSchedule(name: "a", weekdays: [2], startMinute: 480, endMinute: 900).durationMinutes, 420)
        XCTAssertEqual(BlockSchedule(name: "b", weekdays: [2], startMinute: 1320, endMinute: 420).durationMinutes, 540)
        XCTAssertEqual(BlockSchedule(name: "c", weekdays: [2], startMinute: 600, endMinute: 600).durationMinutes, 1440)
    }

    func testDecodingDefaultsMissingEnabledFlag() throws {
        let json = #"{"id":"6F2D9E1A-0B7C-4C55-9D0E-3A1B2C3D4E5F","name":"Kväll","weekdays":[1,7],"startMinute":1260,"endMinute":1380}"#
        let schedule = try JSONDecoder().decode(BlockSchedule.self, from: Data(json.utf8))
        XCTAssertTrue(schedule.isEnabled)
        XCTAssertEqual(schedule.weekdays, [1, 7])
    }
}

enum TestCalendar {
    static let stockholm: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return calendar
    }()

    /// Monday through Friday in `Calendar` numbering.
    static let weekdays: Set<Int> = [2, 3, 4, 5, 6]

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        stockholm.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
