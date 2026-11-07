import Foundation

/// Paus's levels as a journey through lands, with a chest after every level that opens once the next is reached.
/// The last land goes on for ever, so the road never ends.
enum Journey {
    struct Land: Equatable {
        let index: Int
        let name: String
        let tagline: String
        let symbol: String
        let firstLevel: Int
        /// Nil for the last land, which goes on for ever.
        let lastLevel: Int?

        func contains(_ level: Int) -> Bool {
            level >= firstLevel && (lastLevel.map { level <= $0 } ?? true)
        }
    }

    static var lands: [Land] { [
        Land(index: 1, name: L("Skogen"), tagline: L("Lär känna Pip"), symbol: "tree.fill", firstLevel: 1, lastLevel: 3),
        Land(index: 2, name: L("Havet"), tagline: L("Bygg vanan"), symbol: "water.waves", firstLevel: 4, lastLevel: 6),
        Land(index: 3, name: L("Bergen"), tagline: L("Bli stark"), symbol: "mountain.2.fill", firstLevel: 7, lastLevel: 9),
        Land(index: 4, name: L("Molnen"), tagline: L("Bland legender"), symbol: "cloud.fill", firstLevel: 10, lastLevel: 12),
        Land(index: 5, name: L("Rymden"), tagline: L("Bortom himlen"), symbol: "moon.stars.fill", firstLevel: 13, lastLevel: 15),
        Land(index: 6, name: L("Vulkanen"), tagline: L("Genom elden"), symbol: "flame.fill", firstLevel: 16, lastLevel: 18),
        Land(index: 7, name: L("Kristallgrottan"), tagline: L("Skatter i mörkret"), symbol: "diamond.fill", firstLevel: 19, lastLevel: 21),
        Land(index: 8, name: L("Galaxen"), tagline: L("Bland stjärnorna"), symbol: "sparkles", firstLevel: 22, lastLevel: 24),
        Land(index: 9, name: L("Mytlandet"), tagline: L("Där legender blir myter"), symbol: "infinity", firstLevel: 25, lastLevel: nil),
    ] }

    static func land(for level: Int) -> Land {
        lands.first { $0.contains(level) } ?? lands[lands.count - 1]
    }

    // MARK: Chests

    /// What a chest held.
    struct Chest: Equatable {
        enum Kind: Equatable {
            /// Seeds.
            case small
            /// Seeds and a surprise from the wardrobe, every third level.
            case item
            /// Three times the seeds, and at the milestones something that only this chest gives, every fifth level.
            case big
        }

        let kind: Kind
        let seeds: Int
        var item: String?
    }

    static func chestKind(after level: Int) -> Chest.Kind {
        level % 5 == 0 ? .big : level % 3 == 0 ? .item : .small
    }

    /// Seeds in the chest after `level`, a little more the further along it is, and three times as many in a big one.
    static func chestSeeds(after level: Int) -> Int {
        let base = 10 + 5 * max(1, level)
        return chestKind(after: level) == .big ? base * 3 : base
    }

    /// Seeds a chest gives instead when the thing it would give is already owned.
    static let seedsInsteadOfItem = 50

    /// The items only big chests give, by the level they come after.
    static let chestItems: [Int: String] = [
        5: "color-aurora", 10: "color-treasure", 15: "color-cosmos", 20: "color-phoenix", 25: "color-myth",
    ]

    /// The item only the big chest after `level` gives, if it gives one.
    static func chestItem(after level: Int) -> String? {
        chestItems[level]
    }

    /// The level whose chest gives item `id`, for the items no shop sells.
    static func chestLevel(giving id: String) -> Int? {
        chestItems.first { $0.value == id }?.key
    }

    /// A surprise from the wardrobe for the item chest after `level`: something for sale without Pro that isn't owned.
    static func surpriseItem(after level: Int, owned: Set<String>) -> String? {
        let pool = WardrobeItem.all.filter { item in
            !item.needsPro && !item.isSeasonal && !item.isFree && item.price <= 400 && !owned.contains(item.id)
        }
        guard !pool.isEmpty else { return nil }
        return pool[(level * 7_919) % pool.count].id
    }
}

extension PlayerProgress {
    /// Whether the chest after `level` can be opened now: the next level is reached and it isn't opened yet.
    func canOpenChest(after level: Int) -> Bool {
        level < self.level && !openedChests.contains(level)
    }

    /// Opens the chest after `level`, returning what it held, or nil when it can't be opened.
    mutating func openChest(after level: Int) -> Journey.Chest? {
        guard canOpenChest(after: level) else { return nil }
        openedChests.insert(level)
        let kind = Journey.chestKind(after: level)
        var item: String?
        switch kind {
        case .small: item = nil
        case .item: item = Journey.surpriseItem(after: level, owned: ownedItems)
        case .big: item = Journey.chestItem(after: level).flatMap { ownedItems.contains($0) ? nil : $0 }
        }
        var found = Journey.chestSeeds(after: level)
        if kind == .item && item == nil {
            found += Journey.seedsInsteadOfItem
        }
        seeds += found
        if let item {
            ownedItems.insert(item)
        }
        return Journey.Chest(kind: kind, seeds: found, item: item)
    }
}
