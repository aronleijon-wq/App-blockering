import Foundation

/// Paus's levels as a journey through four lands, with a chest after every level that opens once the next is reached.
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
        Land(index: 4, name: L("Molnen"), tagline: L("Bland legender"), symbol: "cloud.fill", firstLevel: 10, lastLevel: nil),
    ] }

    static func land(for level: Int) -> Land {
        lands.first { $0.contains(level) } ?? lands[lands.count - 1]
    }

    /// Seeds in the chest after `level`, a little more the further along it is.
    static func chestSeeds(after level: Int) -> Int {
        10 + 5 * max(1, level)
    }
}

extension PlayerProgress {
    /// Whether the chest after `level` can be opened now: the next level is reached and it isn't opened yet.
    func canOpenChest(after level: Int) -> Bool {
        level < self.level && !openedChests.contains(level)
    }

    /// Opens the chest after `level`, returning the seeds it held, or nil when it can't be opened.
    mutating func openChest(after level: Int) -> Int? {
        guard canOpenChest(after: level) else { return nil }
        openedChests.insert(level)
        let found = Journey.chestSeeds(after: level)
        seeds += found
        return found
    }
}
