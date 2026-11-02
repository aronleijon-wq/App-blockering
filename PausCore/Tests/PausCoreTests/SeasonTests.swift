import XCTest
@testable import PausCore

final class SeasonTests: XCTestCase {
    private let calendar = TestCalendar.stockholm
    private let november2 = TestCalendar.date(2026, 11, 2, 14, 30)

    override func setUp() {
        super.setUp()
        Language.override = .sv
    }

    override func tearDown() {
        Language.override = nil
        super.tearDown()
    }

    func testLegendGoesOnInRounds() {
        XCTAssertEqual(Level.title(for: 10), "Legend")
        XCTAssertEqual(Level.title(for: 11), "Legend II")
        XCTAssertEqual(Level.title(for: 14), "Legend V")
        XCTAssertEqual(Level.title(for: 19), "Legend X")
        XCTAssertEqual(Level.prestige(for: 10), 0)
        XCTAssertEqual(Level.prestige(for: 12), 2)
        XCTAssertEqual(Level.roman(2024), "MMXXIV")
    }

    func testFocusQuestsGrowWithTheLevel() {
        let quest = Quest.with(id: "focus-90")!
        XCTAssertEqual(quest.scaled(forLevel: 1).target, 90)
        let legend = quest.scaled(forLevel: 10)
        XCTAssertEqual(legend.target, 180)
        XCTAssertEqual(legend.title, "Fokusera 3 timmar")
        XCTAssertGreaterThan(legend.xp, quest.xp)
        XCTAssertEqual(Quest.with(id: "scroll-60")!.scaled(forLevel: 20).target, 60, "screen time quests stay as they are")
        XCTAssertLessThanOrEqual(Quest.with(id: "focus-120")!.scaled(forLevel: 30).target, 240, "capped")
        // The same day's quests, only bigger.
        let day = "2026-11-02"
        XCTAssertEqual(Quest.daily(for: day, level: 12).map(\.id), Quest.daily(for: day).map(\.id))
    }

    func testTrophyFamiliesShowTheirBestMedal() {
        let focus = Achievement.shelf.first { $0.first?.family == "focus" }!
        XCTAssertEqual(focus.map(\.tier), [.bronze, .silver, .gold, .diamond])
        let none = Achievement.shown(in: focus, unlocked: [])
        XCTAssertFalse(none.isUnlocked)
        XCTAssertEqual(none.achievement.id, "focus-10")
        let silver = Achievement.shown(in: focus, unlocked: ["focus-10", "focus-100"])
        XCTAssertTrue(silver.isUnlocked)
        XCTAssertEqual(silver.achievement.tier, .silver)
        XCTAssertEqual(silver.next?.id, "focus-500")
        XCTAssertEqual(Set(Achievement.all.map(\.id)).count, Achievement.all.count, "ids are unique")
    }

    func testSeasonsHaveTheirOwnQuestsItemsAndTrophy() {
        let season = Season.at(november2, calendar: calendar)
        XCTAssertEqual(season.key, "2026-11")
        XCTAssertEqual(season.items, ["color-iron"])
        XCTAssertEqual(Season.containing(questID: season.quests[1].id), season)
        XCTAssertEqual(Achievement.with(id: season.trophyID)?.title, "Säsong: Järnvilja")
        XCTAssertEqual(Season.with(key: "2027-05").items, [], "a month without items of its own")
        XCTAssertEqual(season.daysLeft(from: november2, calendar: calendar), 29)

        let iron = WardrobeItem.with(id: "color-iron")!
        XCTAssertTrue(iron.isSeasonal)
        XCTAssertFalse(iron.isFree)
        var progress = PlayerProgress()
        progress.seeds = 10_000
        XCTAssertEqual(progress.buy(iron, isPro: true), .seasonOnly, "season items can't be bought")
    }

    func testFinishingASeasonQuestGivesItsItem() {
        var progress = PlayerProgress()
        let rewards = progress.record(.focusCompleted(minutes: 900), at: november2, calendar: calendar)
        let season = Season.at(november2, calendar: calendar)
        XCTAssertTrue(rewards.contains(.quest(season.quests[0].id)))
        XCTAssertTrue(rewards.contains(.item("color-iron")))
        XCTAssertTrue(progress.owns(WardrobeItem.with(id: "color-iron")!))
        XCTAssertFalse(progress.unlocked.contains(season.trophyID), "not all three yet")
        XCTAssertEqual(progress.monthCounts(at: november2, calendar: calendar).focusMinutes, 900)
        XCTAssertEqual(progress.monthCounts(at: TestCalendar.date(2026, 12, 2, 12, 0), calendar: calendar).focusMinutes, 0, "a new month starts empty")
    }
}
