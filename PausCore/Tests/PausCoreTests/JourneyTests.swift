import XCTest
@testable import PausCore

final class JourneyTests: XCTestCase {
    func testLevelsFallIntoLands() {
        XCTAssertEqual(Journey.land(for: 1).index, 1)
        XCTAssertEqual(Journey.land(for: 3).index, 1)
        XCTAssertEqual(Journey.land(for: 4).index, 2)
        XCTAssertEqual(Journey.land(for: 9).index, 3)
        XCTAssertEqual(Journey.land(for: 10).index, 4)
        XCTAssertEqual(Journey.land(for: 40).index, 4, "the clouds go on for ever")
    }

    func testAChestOpensOnceTheNextLevelIsReached() {
        var progress = PlayerProgress(xp: Level.xpRequired(for: 3))
        XCTAssertEqual(progress.level, 3)
        XCTAssertNil(progress.openChest(after: 3), "level 4 isn't reached yet")
        let seeds = progress.seeds
        XCTAssertEqual(progress.openChest(after: 2), Journey.chestSeeds(after: 2))
        XCTAssertEqual(progress.seeds, seeds + Journey.chestSeeds(after: 2))
        XCTAssertNil(progress.openChest(after: 2), "once only")
        XCTAssertTrue(progress.canOpenChest(after: 1))
    }
}
