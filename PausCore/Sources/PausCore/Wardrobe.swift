import Foundation

/// Things Pip can wear, bought with seeds earned from quests, focus sessions and daily rewards.
struct WardrobeItem: Identifiable, Equatable {
    enum Kind: String, CaseIterable, Codable {
        case hat, glasses, neck, color
    }

    let id: String
    let name: String
    let kind: Kind
    let price: Int
    var needsPro = false

    var isFree: Bool { price == 0 }

    static var all: [WardrobeItem] { [
        WardrobeItem(id: "hat-cap", name: L("Keps"), kind: .hat, price: 40),
        WardrobeItem(id: "hat-flower", name: L("Blomma"), kind: .hat, price: 50),
        WardrobeItem(id: "hat-beanie", name: L("Mössa"), kind: .hat, price: 60),
        WardrobeItem(id: "hat-party", name: L("Partyhatt"), kind: .hat, price: 80),
        WardrobeItem(id: "hat-chef", name: L("Kockmössa"), kind: .hat, price: 120),
        WardrobeItem(id: "hat-crown", name: L("Krona"), kind: .hat, price: 300, needsPro: true),
        WardrobeItem(id: "glasses-round", name: L("Runda glasögon"), kind: .glasses, price: 60),
        WardrobeItem(id: "glasses-sun", name: L("Solglasögon"), kind: .glasses, price: 70),
        WardrobeItem(id: "glasses-heart", name: L("Hjärtglasögon"), kind: .glasses, price: 120, needsPro: true),
        WardrobeItem(id: "neck-scarf", name: L("Halsduk"), kind: .neck, price: 50),
        WardrobeItem(id: "neck-bow", name: L("Fluga"), kind: .neck, price: 70),
        WardrobeItem(id: "neck-medal", name: L("Medalj"), kind: .neck, price: 150),
        WardrobeItem(id: "color-mint", name: L("Mint"), kind: .color, price: 0),
        WardrobeItem(id: "color-ocean", name: L("Hav"), kind: .color, price: 100),
        WardrobeItem(id: "color-sunset", name: L("Solnedgång"), kind: .color, price: 100),
        WardrobeItem(id: "color-lava", name: L("Lava"), kind: .color, price: 120),
        WardrobeItem(id: "color-galaxy", name: L("Galax"), kind: .color, price: 150, needsPro: true),
        WardrobeItem(id: "color-gold", name: L("Guld"), kind: .color, price: 400, needsPro: true),
    ] }

    static func with(id: String) -> WardrobeItem? {
        all.first { $0.id == id }
    }
}

/// What Pip wears: at most one item of each kind, by id.
struct Outfit: Codable, Equatable {
    var hat: String?
    var glasses: String?
    var neck: String?
    var color: String?

    static let none = Outfit()

    func item(for kind: WardrobeItem.Kind) -> String? {
        switch kind {
        case .hat: return hat
        case .glasses: return glasses
        case .neck: return neck
        case .color: return color
        }
    }

    mutating func set(_ id: String?, for kind: WardrobeItem.Kind) {
        switch kind {
        case .hat: hat = id
        case .glasses: glasses = id
        case .neck: neck = id
        case .color: color = id
        }
    }
}

/// How many seeds things earn.
enum Seeds {
    static let dailyReward = 5
    static let dayUnderLimit = 5
    /// One seed per this many focus minutes, at least one per session.
    static let focusMinutesPerSeed = 10

    static func forQuest(_ quest: Quest) -> Int {
        max(2, quest.xp / 5)
    }

    static func forFocus(minutes: Int) -> Int {
        max(1, minutes / focusMinutesPerSeed)
    }
}

extension PlayerProgress {
    enum PurchaseResult: Equatable {
        case bought, alreadyOwned, needsPro, tooFewSeeds
    }

    func owns(_ item: WardrobeItem) -> Bool {
        item.isFree || ownedItems.contains(item.id)
    }

    /// Buys `item` with seeds. Pro items need Pro.
    mutating func buy(_ item: WardrobeItem, isPro: Bool) -> PurchaseResult {
        guard !owns(item) else { return .alreadyOwned }
        guard !item.needsPro || isPro else { return .needsPro }
        guard seeds >= item.price else { return .tooFewSeeds }
        seeds -= item.price
        ownedItems.insert(item.id)
        return .bought
    }

    /// Puts `item` on Pip, or takes it off when Pip already wears it. Taking off a color goes back to Pip's own.
    mutating func toggle(_ item: WardrobeItem) {
        guard owns(item) else { return }
        outfit.set(outfit.item(for: item.kind) == item.id ? nil : item.id, for: item.kind)
    }
}
