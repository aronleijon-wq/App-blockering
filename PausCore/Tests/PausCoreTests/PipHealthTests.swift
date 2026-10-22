import XCTest
@testable import PausCore

final class PipHealthTests: XCTestCase {
    private let calendar = TestCalendar.stockholm
    private let monday = TestCalendar.date(2026, 10, 19, 10, 0)

    func testStages() {
        XCTAssertEqual(PipHealth.Stage(health: 0), .wrecked)
        XCTAssertEqual(PipHealth.Stage(health: 14), .wrecked)
        XCTAssertEqual(PipHealth.Stage(health: 15), .sick)
        XCTAssertEqual(PipHealth.Stage(health: 35), .down)
        XCTAssertEqual(PipHealth.Stage(health: 60), .okay)
        XCTAssertEqual(PipHealth.Stage(health: 100), .great)
        XCTAssertEqual(PlayerProgress().health, PipHealth.start)
    }

    func testPausesHurtMoreEachTime() {
        var progress = PlayerProgress(health: 100)
        progress.record(.tookPause, at: monday, calendar: calendar)
        XCTAssertEqual(progress.health, 95)
        XCTAssertEqual(progress.nextPauseHealthCost(at: monday, calendar: calendar), 10)
        progress.record(.tookPause, at: monday, calendar: calendar)
        progress.record(.tookPause, at: monday, calendar: calendar)
        progress.record(.tookPause, at: monday, calendar: calendar)
        XCTAssertEqual(progress.health, 100 - 5 - 10 - 15 - 25)
    }

    func testScrollingCountsEachStepOnce() {
        var progress = PlayerProgress(health: 100)
        progress.record(.scrolled(minutes: 30), at: monday, calendar: calendar)
        XCTAssertEqual(progress.health, 95)
        // A repeated threshold, as after monitoring restarts, changes nothing.
        progress.record(.scrolled(minutes: 30), at: monday, calendar: calendar)
        XCTAssertEqual(progress.health, 95)
        // A skipped threshold still counts.
        progress.record(.scrolled(minutes: 90), at: monday, calendar: calendar)
        XCTAssertEqual(progress.health, 85)
        progress.record(.scrolled(minutes: 60), at: monday, calendar: calendar)
        XCTAssertEqual(progress.health, 85)
        progress.record(.scrolled(minutes: 1000), at: monday, calendar: calendar)
        XCTAssertEqual(progress.health, 100 - 12 * PipHealth.perScrollStep)
    }

    func testScrollingDoesNotCostPointsOrXP() {
        var progress = PlayerProgress()
        progress.record(.claimedDailyReward, at: monday, calendar: calendar)
        let xp = progress.xp
        let rewards = progress.record(.scrolled(minutes: 120), at: monday, calendar: calendar)
        XCTAssertEqual(rewards, [])
        XCTAssertEqual(progress.pointsThisWeek(at: monday, calendar: calendar), League.Points.dailyReward)
        XCTAssertEqual(progress.xp, xp)
    }

    func testGoodHabitsHeal() {
        var progress = PlayerProgress(health: 20)
        progress.record(.focusCompleted(minutes: 50), at: monday, calendar: calendar)
        XCTAssertEqual(progress.health, 30)
        progress.record(.declinedPause, at: monday, calendar: calendar)
        progress.record(.closedBlockedApp, at: monday, calendar: calendar)
        progress.record(.claimedDailyReward, at: monday, calendar: calendar)
        XCTAssertEqual(progress.health, 30 + 5 + 2 + 5)
    }

    func testHealthStaysInRange() {
        var progress = PlayerProgress(health: 10)
        progress.record(.disabledProtection, at: monday, calendar: calendar)
        XCTAssertEqual(progress.health, 0)
        progress = PlayerProgress(health: 99)
        progress.record(.claimedDailyReward, at: monday, calendar: calendar)
        XCTAssertEqual(progress.health, 100)
    }

    func testRecoversOncePerNight() {
        var progress = PlayerProgress(health: 40)
        progress.recoverOvernight(at: monday, calendar: calendar)
        XCTAssertEqual(progress.health, 40, "the first day sets the baseline")
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        progress.recoverOvernight(at: tuesday, calendar: calendar)
        progress.recoverOvernight(at: tuesday.addingTimeInterval(3600), calendar: calendar)
        XCTAssertEqual(progress.health, 40 + PipHealth.overnight)
    }

    func testOldSavesStartHealthy() throws {
        let json = #"{"xp": 120, "streak": 2}"#.data(using: .utf8)!
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: json)
        XCTAssertEqual(progress.health, PipHealth.start)
        XCTAssertEqual(progress.today.scrolledMinutes, 0)
    }

    func testLowHealthChangesMood() {
        XCTAssertEqual(MascotMood.current(reason: nil, isPaused: false, progress: PlayerProgress(health: 5), at: monday, calendar: calendar), .wrecked)
        XCTAssertEqual(MascotMood.current(reason: nil, isPaused: false, progress: PlayerProgress(health: 25), at: monday, calendar: calendar), .crying)
        XCTAssertEqual(MascotMood.current(reason: nil, isPaused: false, progress: PlayerProgress(health: 50), at: monday, calendar: calendar), .sad)
        XCTAssertEqual(MascotMood.current(reason: .focus(until: monday), isPaused: false, progress: PlayerProgress(health: 5), at: monday, calendar: calendar), .zen, "focus calms Pip down")
    }
}
