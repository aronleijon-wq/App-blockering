import XCTest
@testable import PausCore

final class JourneyTests: XCTestCase {
    func testLevelsFallIntoLandsAndTheRoadNeverEnds() {
        XCTAssertEqual(Journey.land(for: 1).index, 1)
        XCTAssertEqual(Journey.land(for: 3).index, 1)
        XCTAssertEqual(Journey.land(for: 4).index, 2)
        XCTAssertEqual(Journey.land(for: 9).index, 3)
        XCTAssertEqual(Journey.land(for: 10).index, 4)
        XCTAssertEqual(Journey.land(for: 13).index, 5)
        XCTAssertEqual(Journey.land(for: 24).index, 8)
        XCTAssertEqual(Journey.land(for: 25).index, 9)
        XCTAssertEqual(Journey.land(for: 400).index, 9, "the last land goes on for ever")
        // The lands follow each other with no gaps.
        let lands = Journey.lands
        for (land, next) in zip(lands, lands.dropFirst()) {
            XCTAssertEqual(land.lastLevel.map { $0 + 1 }, next.firstLevel)
        }
    }

    func testAChestOpensOnceTheNextLevelIsReached() {
        var progress = PlayerProgress(xp: Level.xpRequired(for: 3))
        XCTAssertEqual(progress.level, 3)
        XCTAssertNil(progress.openChest(after: 3), "level 4 isn't reached yet")
        let seeds = progress.seeds
        XCTAssertEqual(progress.openChest(after: 2), Journey.Chest(kind: .small, seeds: Journey.chestSeeds(after: 2)))
        XCTAssertEqual(progress.seeds, seeds + Journey.chestSeeds(after: 2))
        XCTAssertNil(progress.openChest(after: 2), "once only")
        XCTAssertTrue(progress.canOpenChest(after: 1))
    }

    func testEveryThirdChestHoldsSomethingToWearAndEveryFifthIsBig() {
        XCTAssertEqual(Journey.chestKind(after: 1), .small)
        XCTAssertEqual(Journey.chestKind(after: 3), .item)
        XCTAssertEqual(Journey.chestKind(after: 5), .big)
        XCTAssertEqual(Journey.chestKind(after: 15), .big, "big wins over item")
        XCTAssertEqual(Journey.chestSeeds(after: 5), 3 * (10 + 5 * 5))

        var progress = PlayerProgress(xp: Level.xpRequired(for: 11))
        let item = progress.openChest(after: 3)
        XCTAssertEqual(item?.kind, .item)
        let surprise = item?.item
        XCTAssertNotNil(surprise)
        if let surprise, let wardrobeItem = WardrobeItem.with(id: surprise) {
            XCTAssertTrue(progress.owns(wardrobeItem))
            XCTAssertFalse(wardrobeItem.needsPro)
        }

        let big = progress.openChest(after: 10)
        XCTAssertEqual(big?.item, "color-treasure")
        XCTAssertTrue(progress.owns(WardrobeItem.with(id: "color-treasure")!))
        XCTAssertEqual(progress.buy(WardrobeItem.with(id: "color-aurora")!, isPro: true), .seasonOnly, "chest colors can't be bought")
        XCTAssertEqual(Journey.chestLevel(giving: "color-aurora"), 5)
    }

    func testAnItemChestGivesSeedsWhenThereIsNothingLeftToGive() {
        var owned = Set(WardrobeItem.all.map(\.id))
        XCTAssertNil(Journey.surpriseItem(after: 3, owned: owned))
        owned.remove("hat-cap")
        XCTAssertEqual(Journey.surpriseItem(after: 3, owned: owned), "hat-cap")

        var progress = PlayerProgress(xp: Level.xpRequired(for: 4))
        progress.ownedItems = Set(WardrobeItem.all.map(\.id))
        XCTAssertEqual(progress.openChest(after: 3)?.seeds, Journey.chestSeeds(after: 3) + Journey.seedsInsteadOfItem)
    }
}
