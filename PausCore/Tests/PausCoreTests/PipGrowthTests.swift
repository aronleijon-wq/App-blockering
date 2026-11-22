import XCTest
@testable import PausCore

final class PipGrowthTests: XCTestCase {
    private let calendar = TestCalendar.stockholm
    // A Wednesday.
    private let wednesday = TestCalendar.date(2026, 11, 18, 10, 0)

    func testPipGrowsWithTheHoursOfFocusAndCelebratesEachStage() {
        XCTAssertEqual(PipGrowth.stage(focusMinutes: 0), .baby)
        XCTAssertEqual(PipGrowth.stage(focusMinutes: 3 * 60), .child)
        XCTAssertEqual(PipGrowth.stage(focusMinutes: 75 * 60), .master)
        XCTAssertEqual(PipGrowth.stage(focusMinutes: 10_000 * 60), .master)

        var progress = PlayerProgress()
        progress.record(.focusCompleted(minutes: 120), at: wednesday, calendar: calendar)
        XCTAssertEqual(progress.growthStage, .baby)
        XCTAssertEqual(progress.minutesToNextStage, 60)
        XCTAssertEqual(progress.growthFraction, 120.0 / 180.0, accuracy: 0.001)
        let rewards = progress.record(.focusCompleted(minutes: 60), at: wednesday, calendar: calendar)
        XCTAssertTrue(rewards.contains(.grewUp(PipGrowth.Stage.child.rawValue)))
        XCTAssertFalse(progress.record(.focusCompleted(minutes: 30), at: wednesday, calendar: calendar)
            .contains { if case .grewUp = $0 { return true }; return false }, "only when a stage is reached")
    }

    func testTheWeeklyLetterComparesWithLastWeek() {
        var progress = PlayerProgress()
        progress.history = [
            "2026-11-10": DaySummary(focusMinutes: 60, focusSessions: 2),  // Last week's Tuesday.
            "2026-11-16": DaySummary(focusMinutes: 50, focusSessions: 1, quests: 2),  // This Monday.
            "2026-11-15": DaySummary(focusMinutes: 30, focusSessions: 1),  // Last Sunday.
        ]
        progress.record(.focusCompleted(minutes: 70), at: wednesday, calendar: calendar)
        let letter = WeeklyLetter.make(from: progress, at: wednesday, calendar: calendar)
        XCTAssertEqual(letter.thisWeekMinutes, 120)
        XCTAssertEqual(letter.lastWeekMinutes, 90)
        XCTAssertEqual(letter.sessions, 2)
        XCTAssertEqual(letter.change, 33)
        XCTAssertNil(WeeklyLetter(thisWeekMinutes: 10, lastWeekMinutes: 0, sessions: 1, quests: 0).change)
    }
}
