import XCTest
@testable import PausCore

final class LeagueTests: XCTestCase {
    private let calendar = TestCalendar.stockholm
    private let monday = TestCalendar.date(2026, 10, 19, 10, 0)

    func testWeekKeyAndEnd() {
        XCTAssertEqual(League.weekKey(for: monday, calendar: calendar), "2026-W43")
        // Sunday night still belongs to the same week, Monday starts the next.
        XCTAssertEqual(League.weekKey(for: TestCalendar.date(2026, 10, 25, 23, 59), calendar: calendar), "2026-W43")
        XCTAssertEqual(League.weekKey(for: TestCalendar.date(2026, 10, 26, 0, 0), calendar: calendar), "2026-W44")
        XCTAssertEqual(League.weekEnd(for: monday, calendar: calendar), TestCalendar.date(2026, 10, 26, 0, 0))
        // ISO weeks around New Year belong to the year of their Thursday.
        XCTAssertEqual(League.weekKey(for: TestCalendar.date(2027, 1, 1, 12, 0), calendar: calendar), "2026-W53")
    }

    func testFocusPointsAreCappedPerDay() {
        var progress = PlayerProgress()
        progress.record(.focusCompleted(minutes: 90), at: monday, calendar: calendar)
        progress.record(.focusCompleted(minutes: 90), at: monday, calendar: calendar)
        XCTAssertEqual(progress.weeklyPoints, League.Points.focusDailyCap)
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        progress.record(.focusCompleted(minutes: 25), at: tuesday, calendar: calendar)
        XCTAssertEqual(progress.weeklyPoints, League.Points.focusDailyCap + 25)
    }

    func testEventsEarnPoints() {
        var progress = PlayerProgress()
        progress.record(.claimedDailyReward, at: monday, calendar: calendar)
        progress.record(.closedBlockedApp, at: monday, calendar: calendar)
        progress.record(.declinedPause, at: monday, calendar: calendar)
        progress.record(.dayUnderLimit, at: monday, calendar: calendar)
        XCTAssertEqual(progress.weeklyPoints, League.Points.dailyReward + League.Points.close + League.Points.decline + League.Points.dayUnderLimit)
    }

    func testNewWeekKeepsTheFinishedOneToSettle() {
        var progress = PlayerProgress(division: .silver, leagueGroupID: "g1")
        progress.record(.claimedDailyReward, at: monday, calendar: calendar)
        progress.leagueGroupID = "g1"
        let nextMonday = TestCalendar.date(2026, 10, 26, 9, 0)
        progress.rollWeek(at: nextMonday, calendar: calendar)
        XCTAssertEqual(progress.finishedWeek, FinishedWeek(weekKey: "2026-W43", points: League.Points.dailyReward, division: .silver, groupID: "g1"))
        XCTAssertEqual(progress.weeklyPoints, 0)
        XCTAssertNil(progress.leagueGroupID)
        XCTAssertEqual(progress.pointsThisWeek(at: monday, calendar: calendar), 0)
    }

    func testSettlingByRankInGroup() {
        let week = FinishedWeek(weekKey: "2026-W43", points: 300, division: .silver, groupID: "g1")
        XCTAssertEqual(League.nextDivision(after: week, rank: 1, groupSize: 30), .guld)
        XCTAssertEqual(League.nextDivision(after: week, rank: 6, groupSize: 30), .guld)
        XCTAssertEqual(League.nextDivision(after: week, rank: 7, groupSize: 30), .silver)
        XCTAssertEqual(League.nextDivision(after: week, rank: 24, groupSize: 30), .silver)
        XCTAssertEqual(League.nextDivision(after: week, rank: 25, groupSize: 30), .brons)
    }

    func testSmallGroupsNeverRelegate() {
        let week = FinishedWeek(weekKey: "2026-W43", points: 0, division: .silver, groupID: "g1")
        XCTAssertEqual(League.nextDivision(after: week, rank: 2, groupSize: 2), .silver)
        XCTAssertEqual(League.nextDivision(after: week, rank: 1, groupSize: 2), .guld)
    }

    func testSettlingByPointsWithoutGroup() {
        XCTAssertEqual(League.nextDivision(after: FinishedWeek(weekKey: "w", points: 200, division: .brons), rank: nil, groupSize: nil), .silver)
        XCTAssertEqual(League.nextDivision(after: FinishedWeek(weekKey: "w", points: 0, division: .brons), rank: nil, groupSize: nil), .brons)
        XCTAssertEqual(League.nextDivision(after: FinishedWeek(weekKey: "w", points: 50, division: .guld), rank: nil, groupSize: nil), .silver)
        XCTAssertEqual(League.nextDivision(after: FinishedWeek(weekKey: "w", points: 9999, division: .legend), rank: nil, groupSize: nil), .legend)
    }

    func testSettleQueuesCelebration() {
        var progress = PlayerProgress(division: .brons, finishedWeek: FinishedWeek(weekKey: "w", points: 10, division: .brons, groupID: "g"))
        let rewards = progress.settleFinishedWeek(rank: 1, groupSize: 20)
        XCTAssertEqual(rewards, [.division(Division.silver.rawValue, promoted: true)])
        XCTAssertEqual(progress.division, .silver)
        XCTAssertNil(progress.finishedWeek)
        XCTAssertEqual(progress.settleFinishedWeek(rank: 1, groupSize: 20), [])
    }

    func testNicknameRules() {
        XCTAssertNil(Nickname.problem(with: "Scrollfri_Elsa"))
        XCTAssertNil(Nickname.problem(with: "Åsa.92"))
        XCTAssertEqual(Nickname.problem(with: "ab"), .tooShort)
        XCTAssertEqual(Nickname.problem(with: String(repeating: "a", count: 17)), .tooLong)
        XCTAssertEqual(Nickname.problem(with: "hej du"), .invalidCharacters)
        XCTAssertEqual(Nickname.problem(with: "FuckTikTok"), .notAllowed)
        XCTAssertEqual(Nickname.problem(with: "sh1t_lord"), .notAllowed)
        XCTAssertEqual(Nickname.problem(with: "PausAdmin"), .notAllowed)
    }
}
