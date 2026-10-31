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

    func testFriendCodes() {
        let code = FriendCode.make()
        XCTAssertEqual(code.count, FriendCode.length)
        XCTAssertTrue(code.allSatisfy { FriendCode.alphabet.contains($0) })
        XCTAssertEqual(FriendCode.normalized(" k7p-2qx "), "K7P2QX")
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

final class PausePenaltyTests: XCTestCase {
    private let calendar = TestCalendar.stockholm
    private let monday = TestCalendar.date(2026, 10, 19, 10, 0)

    func testPenaltyGrowsWithEachPause() {
        XCTAssertEqual((1...5).map(League.pausePenalty(forPause:)), [0, 10, 20, 40, 40])
    }

    func testPausesCostWeeklyPointsButNeverGoBelowZero() {
        var progress = PlayerProgress()
        progress.record(.dayUnderLimit, at: monday, calendar: calendar)
        XCTAssertEqual(progress.nextPausePenalty(at: monday, calendar: calendar), 0)
        progress.record(.tookPause, at: monday, calendar: calendar)
        XCTAssertEqual(progress.weeklyPoints, 30, "first pause is free")
        XCTAssertEqual(progress.nextPausePenalty(at: monday, calendar: calendar), 10)
        progress.record(.tookPause, at: monday, calendar: calendar)
        progress.record(.tookPause, at: monday, calendar: calendar)
        XCTAssertEqual(progress.weeklyPoints, 0, "30 - 10 - 20")
        progress.record(.tookPause, at: monday, calendar: calendar)
        XCTAssertEqual(progress.weeklyPoints, 0)

        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        XCTAssertEqual(progress.nextPausePenalty(at: tuesday, calendar: calendar), 0, "a new day starts free")
    }

    func testPausesTakeXPButNeverALevel() {
        var progress = PlayerProgress(xp: 250)
        XCTAssertEqual(progress.record(.tookPause, at: monday, calendar: calendar), [], "the first pause is free")
        XCTAssertEqual(progress.record(.tookPause, at: monday, calendar: calendar), [.xpLost(10)])
        progress.record(.tookPause, at: monday, calendar: calendar)
        XCTAssertEqual(progress.xp, 220)
        // Level 2 starts at 100 XP; a 40 XP pause can't take the player below it.
        progress.xp = 120
        XCTAssertEqual(progress.record(.tookPause, at: monday, calendar: calendar), [.xpLost(20)])
        XCTAssertEqual(progress.xp, 100)
        XCTAssertEqual(progress.level, 2)
        XCTAssertEqual(progress.record(.tookPause, at: monday, calendar: calendar), [], "nothing left to take")
    }

    func testGivingInCostsXPPointsAndHealth() {
        var progress = PlayerProgress(xp: 500, health: 80)
        progress.record(.claimedDailyReward, at: monday, calendar: calendar)
        let points = progress.weeklyPoints
        let xp = progress.xp
        XCTAssertEqual(progress.record(.abandonedFocus, at: monday, calendar: calendar), [.xpLost(PlayerProgress.XP.abandonedFocus)])
        progress.record(.escapedBlock, at: monday, calendar: calendar)
        XCTAssertEqual(progress.xp, xp - PlayerProgress.XP.abandonedFocus - PlayerProgress.XP.escapedBlock)
        XCTAssertEqual(progress.weeklyPoints, max(0, points - League.Points.abandonedFocus - League.Points.escapedBlock))
        XCTAssertEqual(progress.health, 85 - PipHealth.abandonedFocus - PipHealth.escapedBlock)
        XCTAssertTrue(progress.pendingRewards.allSatisfy(\.isCelebration), "losses aren't celebrated")
    }

    func testDisablingProtectionCostsPointsAndStreak() {
        var progress = PlayerProgress()
        progress.record(.claimedDailyReward, at: monday, calendar: calendar)
        progress.weeklyPoints = 150
        progress.record(.disabledProtection, at: monday, calendar: calendar)
        XCTAssertEqual(progress.weeklyPoints, 50)
        XCTAssertEqual(progress.currentStreak(at: monday, calendar: calendar), 0)
        XCTAssertEqual(progress.bestStreak, 1)
    }

    func testPauseReasonsAreTallied() {
        var progress = PlayerProgress()
        progress.recordPauseReason(.bored)
        progress.recordPauseReason(.bored)
        progress.recordPauseReason(.message)
        XCTAssertEqual(progress.pauseReasons, ["bored": 2, "message": 1])
    }

    func testReflectionQuestionsRotate() {
        XCTAssertNotEqual(ReflectionQuestions.question(at: 0, offset: 0), ReflectionQuestions.question(at: 6, offset: 0))
        XCTAssertEqual(ReflectionQuestions.question(at: 0, offset: ReflectionQuestions.all.count), ReflectionQuestions.question(at: 0, offset: 0))
    }
}

final class NicknameSuggestionTests: XCTestCase {
    func testEverySuggestionIsAllowed() {
        for language in Language.allCases {
            for word in Nickname.suggestionWords(in: language) {
                for animal in Nickname.suggestionAnimals(in: language) {
                    for number in 10...99 {
                        let name = "\(word)\(animal)\(number)"
                        XCTAssertNil(Nickname.problem(with: name), name)
                    }
                }
            }
        }
    }

    func testSuggestionsVary() {
        let names = Nickname.suggestions(count: 3, seed: 12345, language: .sv)
        XCTAssertEqual(names.count, 3)
        XCTAssertEqual(Set(names).count, 3)
        XCTAssertEqual(Nickname.suggestions(count: 3, seed: 12345, language: .sv), names, "the same seed gives the same names")
        XCTAssertNotEqual(Nickname.suggestions(count: 3, seed: 12345, language: .en), names, "English players get English names")
    }
}
