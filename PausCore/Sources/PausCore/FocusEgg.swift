import Foundation

/// Every finished focus session hatches an egg, and nobody knows what's inside: mostly seeds, sometimes something to
/// wear, now and then a color only eggs give. The longer the session, the better the odds, so it pays to stay
/// focused a little longer. After a run of plain eggs, an epic one is guaranteed.
enum FocusEgg {
    enum Rarity: String, Codable, CaseIterable, Comparable {
        case common, rare, epic, legendary

        var rank: Int { Rarity.allCases.firstIndex(of: self) ?? 0 }
        static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rank < rhs.rank }

        var name: String {
            switch self {
            case .common: return L("Vanligt")
            case .rare: return L("Sällsynt")
            case .epic: return L("Episkt")
            case .legendary: return L("Legendariskt")
            }
        }

        var seeds: Int {
            switch self {
            case .common: return 8
            case .rare: return 20
            case .epic: return 45
            case .legendary: return 90
            }
        }
    }

    /// Sessions shorter than this hatch nothing.
    static let minMinutes = 10
    /// Eggs in a row below epic before the next is sure to be epic.
    static let pityAfter = 8
    /// The colors only legendary eggs give.
    static let legendaryItems = ["color-opal", "color-prism", "color-eclipse"]

    /// The chances in percent of common, rare, epic and legendary for a session of `minutes`.
    static func odds(minutes: Int) -> [Int] {
        switch minutes {
        case ..<minMinutes: return [0, 0, 0, 0]
        case ..<25: return [80, 15, 4, 1]
        case ..<50: return [66, 24, 8, 2]
        case ..<90: return [52, 30, 13, 5]
        default: return [38, 34, 20, 8]
        }
    }

    /// The rarity a roll of `roll` (0..<100) gives for a session of `minutes`, or nil when it's too short.
    static func rarity(minutes: Int, roll: Int) -> Rarity? {
        let odds = odds(minutes: minutes)
        guard odds.reduce(0, +) > 0 else { return nil }
        var edge = 0
        for (rarity, chance) in zip(Rarity.allCases, odds) {
            edge += chance
            if roll < edge { return rarity }
        }
        return .common
    }

    /// A roll in 0..<100 that's the same for the same session, so recording an event twice can't reroll it.
    static func roll(session: Int, day: String) -> Int {
        var x = day.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) } &+ UInt64(session) &* 0x9E37_79B9_7F4A_7C15
        // SplitMix64.
        x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
        x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return Int(x % 100)
    }

    static func isEggItem(_ id: String) -> Bool {
        legendaryItems.contains(id)
    }
}

extension PlayerProgress {
    /// Eggs hatched in all.
    var eggsHatchedCount: Int { eggsHatched.values.reduce(0, +) }

    /// Hatches the egg a focus session of `minutes` earned, the `focusSessions`th, on `day`.
    mutating func hatchEgg(minutes: Int, day: String) -> Reward? {
        guard var rarity = FocusEgg.rarity(minutes: minutes, roll: FocusEgg.roll(session: focusSessions, day: day)) else { return nil }
        if eggsSinceEpic + 1 >= FocusEgg.pityAfter && rarity < .epic {
            rarity = .epic
        }
        eggsSinceEpic = rarity >= .epic ? 0 : eggsSinceEpic + 1
        eggsHatched[rarity.rawValue, default: 0] += 1
        var item: String?
        switch rarity {
        case .common, .rare:
            item = nil
        case .epic:
            item = Journey.surpriseItem(after: focusSessions, owned: ownedItems)
        case .legendary:
            item = FocusEgg.legendaryItems.first { !ownedItems.contains($0) } ?? Journey.surpriseItem(after: focusSessions, owned: ownedItems)
        }
        seeds += rarity.seeds
        if let item {
            ownedItems.insert(item)
        }
        return .egg(rarity.rawValue, seeds: rarity.seeds, item: item)
    }
}
