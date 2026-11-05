import Foundation

/// Things Pip can wear, and the shapes Pip can take, bought with seeds earned from quests, focus sessions and daily rewards.
struct WardrobeItem: Identifiable, Equatable {
    enum Kind: String, CaseIterable, Codable {
        case hat, glasses, shirt, neck, back, color, shape
    }

    let id: String
    let name: String
    let kind: Kind
    let price: Int
    var needsPro = false

    /// Only earned, never bought: with a season's quests (see `Season`), or the NNN challenge's medal.
    var isSeasonal: Bool { Season.isSeasonItem(id) || id == AdultLock.challengeItem }
    var isFree: Bool { price == 0 && !isSeasonal }

    static var all: [WardrobeItem] { [
        WardrobeItem(id: "hat-cap", name: L("Keps"), kind: .hat, price: 40),
        WardrobeItem(id: "hat-flower", name: L("Blomma"), kind: .hat, price: 50),
        WardrobeItem(id: "hat-beanie", name: L("Mössa"), kind: .hat, price: 60),
        WardrobeItem(id: "hat-ninja", name: L("Ninjapannband"), kind: .hat, price: 80),
        WardrobeItem(id: "hat-party", name: L("Partyhatt"), kind: .hat, price: 90),
        WardrobeItem(id: "hat-cat", name: L("Kattöron"), kind: .hat, price: 120),
        WardrobeItem(id: "hat-bunny", name: L("Kaninöron"), kind: .hat, price: 140),
        WardrobeItem(id: "hat-bucket", name: L("Buckethatt"), kind: .hat, price: 170),
        WardrobeItem(id: "hat-chef", name: L("Kockmössa"), kind: .hat, price: 150),
        WardrobeItem(id: "hat-headphones", name: L("Hörlurar"), kind: .hat, price: 160),
        WardrobeItem(id: "hat-cowboy", name: L("Cowboyhatt"), kind: .hat, price: 180),
        WardrobeItem(id: "hat-devil", name: L("Djävulshorn"), kind: .hat, price: 200),
        WardrobeItem(id: "hat-grad", name: L("Studentmössa"), kind: .hat, price: 220),
        WardrobeItem(id: "hat-viking", name: L("Vikingahjälm"), kind: .hat, price: 260),
        WardrobeItem(id: "hat-pirate", name: L("Piratmössa"), kind: .hat, price: 280),
        WardrobeItem(id: "hat-wizard", name: L("Trollkarlshatt"), kind: .hat, price: 300),
        WardrobeItem(id: "hat-halo", name: L("Gloria"), kind: .hat, price: 450, needsPro: true),
        WardrobeItem(id: "hat-tiara", name: L("Diadem"), kind: .hat, price: 650, needsPro: true),
        WardrobeItem(id: "hat-crown", name: L("Krona"), kind: .hat, price: 800, needsPro: true),
        WardrobeItem(id: "hat-fire", name: L("Eldfrisyr"), kind: .hat, price: 900, needsPro: true),
        WardrobeItem(id: "hat-santa", name: L("Tomteluva"), kind: .hat, price: 0),
        WardrobeItem(id: "glasses-round", name: L("Runda glasögon"), kind: .glasses, price: 60),
        WardrobeItem(id: "glasses-3d", name: L("3D-glasögon"), kind: .glasses, price: 70),
        WardrobeItem(id: "glasses-sun", name: L("Solglasögon"), kind: .glasses, price: 90),
        WardrobeItem(id: "glasses-star", name: L("Stjärnglasögon"), kind: .glasses, price: 140),
        WardrobeItem(id: "glasses-monocle", name: L("Monokel"), kind: .glasses, price: 180),
        WardrobeItem(id: "glasses-aviator", name: L("Pilotglasögon"), kind: .glasses, price: 200),
        WardrobeItem(id: "glasses-pixel", name: L("Pixelbrillor"), kind: .glasses, price: 220),
        WardrobeItem(id: "glasses-ski", name: L("Skidglasögon"), kind: .glasses, price: 250),
        WardrobeItem(id: "glasses-heart", name: L("Hjärtglasögon"), kind: .glasses, price: 300, needsPro: true),
        WardrobeItem(id: "glasses-visor", name: L("Cybervisir"), kind: .glasses, price: 500, needsPro: true),
        WardrobeItem(id: "glasses-laser", name: L("Laserögon"), kind: .glasses, price: 850, needsPro: true),
        WardrobeItem(id: "glasses-gold", name: L("Guldbågar"), kind: .glasses, price: 0),
        WardrobeItem(id: "shirt-white", name: L("Vit t-shirt"), kind: .shirt, price: 60),
        WardrobeItem(id: "shirt-black", name: L("Svart t-shirt"), kind: .shirt, price: 80),
        WardrobeItem(id: "shirt-stripes", name: L("Randig tröja"), kind: .shirt, price: 140),
        WardrobeItem(id: "shirt-hoodie", name: L("Hoodie"), kind: .shirt, price: 200),
        WardrobeItem(id: "shirt-hawaii", name: L("Hawaiiskjorta"), kind: .shirt, price: 240),
        WardrobeItem(id: "shirt-jersey", name: L("Fotbollströja"), kind: .shirt, price: 280),
        WardrobeItem(id: "shirt-flag", name: L("Flaggtröja"), kind: .shirt, price: 300),
        WardrobeItem(id: "shirt-leather", name: L("Skinnjacka"), kind: .shirt, price: 450),
        WardrobeItem(id: "shirt-tux", name: L("Smoking"), kind: .shirt, price: 700, needsPro: true),
        WardrobeItem(id: "shirt-armor", name: L("Rustning"), kind: .shirt, price: 950, needsPro: true),
        WardrobeItem(id: "neck-scarf", name: L("Halsduk"), kind: .neck, price: 50),
        WardrobeItem(id: "neck-tie", name: L("Slips"), kind: .neck, price: 60),
        WardrobeItem(id: "neck-bandana", name: L("Bandana"), kind: .neck, price: 90),
        WardrobeItem(id: "neck-bow", name: L("Fluga"), kind: .neck, price: 100),
        WardrobeItem(id: "neck-lei", name: L("Blomkrans"), kind: .neck, price: 140),
        WardrobeItem(id: "neck-medal", name: L("Medalj"), kind: .neck, price: 250),
        WardrobeItem(id: "neck-chain", name: L("Guldkedja"), kind: .neck, price: 400),
        WardrobeItem(id: "neck-diamond", name: L("Diamantkedja"), kind: .neck, price: 1000, needsPro: true),
        WardrobeItem(id: "neck-iron-medal", name: L("NNN-medalj"), kind: .neck, price: 0),
        WardrobeItem(id: "back-cape", name: L("Superhjältemantel"), kind: .back, price: 250),
        WardrobeItem(id: "back-guitar", name: L("Gitarr"), kind: .back, price: 300),
        WardrobeItem(id: "back-skateboard", name: L("Skateboard"), kind: .back, price: 320),
        WardrobeItem(id: "back-bat", name: L("Fladdermusvingar"), kind: .back, price: 350),
        WardrobeItem(id: "back-wings", name: L("Änglavingar"), kind: .back, price: 600, needsPro: true),
        WardrobeItem(id: "back-jetpack", name: L("Jetpack"), kind: .back, price: 700, needsPro: true),
        WardrobeItem(id: "back-dragon", name: L("Drakvingar"), kind: .back, price: 950, needsPro: true),
        WardrobeItem(id: "color-mint", name: L("Mint"), kind: .color, price: 0),
        WardrobeItem(id: "color-ice", name: L("Is"), kind: .color, price: 100),
        WardrobeItem(id: "color-ocean", name: L("Hav"), kind: .color, price: 120),
        WardrobeItem(id: "color-sunset", name: L("Solnedgång"), kind: .color, price: 120),
        WardrobeItem(id: "color-candy", name: L("Sockervadd"), kind: .color, price: 150),
        WardrobeItem(id: "color-lava", name: L("Lava"), kind: .color, price: 180),
        WardrobeItem(id: "color-toxic", name: L("Toxic"), kind: .color, price: 180),
        WardrobeItem(id: "color-shadow", name: L("Skugga"), kind: .color, price: 250),
        WardrobeItem(id: "color-neon", name: L("Neon"), kind: .color, price: 280),
        WardrobeItem(id: "color-ruby", name: L("Rubin"), kind: .color, price: 320),
        WardrobeItem(id: "color-emerald", name: L("Smaragd"), kind: .color, price: 320),
        WardrobeItem(id: "color-galaxy", name: L("Galax"), kind: .color, price: 400, needsPro: true),
        WardrobeItem(id: "color-midnight", name: L("Midnatt"), kind: .color, price: 450, needsPro: true),
        WardrobeItem(id: "color-gold", name: L("Guld"), kind: .color, price: 900, needsPro: true),
        WardrobeItem(id: "color-rainbow", name: L("Regnbåge"), kind: .color, price: 1200, needsPro: true),
        WardrobeItem(id: "color-iron", name: L("Järnvilja"), kind: .color, price: 0),
        WardrobeItem(id: "color-frost", name: L("Frost"), kind: .color, price: 0),
        WardrobeItem(id: "color-dawn", name: L("Gryning"), kind: .color, price: 0),
        WardrobeItem(id: "shape-round", name: L("Rund"), kind: .shape, price: 0),
        WardrobeItem(id: "shape-tall", name: L("Lång"), kind: .shape, price: 120),
        WardrobeItem(id: "shape-wide", name: L("Bred"), kind: .shape, price: 120),
        WardrobeItem(id: "shape-egg", name: L("Ägg"), kind: .shape, price: 150),
        WardrobeItem(id: "shape-pear", name: L("Päron"), kind: .shape, price: 150),
        WardrobeItem(id: "shape-square", name: L("Kub"), kind: .shape, price: 220),
        WardrobeItem(id: "shape-drop", name: L("Droppe"), kind: .shape, price: 260),
        WardrobeItem(id: "shape-ghost", name: L("Spöke"), kind: .shape, price: 400),
        WardrobeItem(id: "shape-heart", name: L("Hjärta"), kind: .shape, price: 600, needsPro: true),
    ] }

    /// The item with `id`. A worn flag shirt such as "shirt-flag-SE" is the flag shirt.
    static func with(id: String) -> WardrobeItem? {
        let base = flagCountry(of: id) == nil ? id : flagShirt
        return all.first { $0.id == base }
    }

    /// The shirt with the wearer's country's flag. Pip wears it with the country, as "shirt-flag-SE", so the league
    /// shows the flag its owner chose.
    static let flagShirt = "shirt-flag"

    /// The id Pip wears this item as: the flag shirt with `country`'s flag, anything else as it is.
    func wornID(country: String) -> String {
        id == Self.flagShirt ? Self.flagShirtID(country: country) : id
    }

    static func flagShirtID(country: String) -> String {
        "\(flagShirt)-\(Country.code(from: country))"
    }

    /// The country on a worn flag shirt, such as "SE" for "shirt-flag-SE".
    static func flagCountry(of id: String?) -> String? {
        guard let id, id.hasPrefix(flagShirt + "-") else { return nil }
        let code = String(id.dropFirst(flagShirt.count + 1))
        return Country.code(from: code) == code ? code : nil
    }
}

/// What Pip wears: at most one item of each kind, by id.
struct Outfit: Codable, Equatable {
    var hat: String?
    var glasses: String?
    var neck: String?
    /// Wings, a cape or a jetpack, drawn behind Pip.
    var back: String?
    var color: String?
    /// A shirt, drawn over the lower part of Pip. A flag shirt carries its country, as "shirt-flag-SE".
    var shirt: String?
    /// Pip's shape, such as "shape-tall". Pip is round without one.
    var shape: String?

    static let none = Outfit()

    /// Whether Pip wears `item`, whatever country a flag shirt shows.
    func wears(_ item: WardrobeItem) -> Bool {
        guard let worn = self.item(for: item.kind) else { return false }
        return worn == item.id || (item.id == WardrobeItem.flagShirt && WardrobeItem.flagCountry(of: worn) != nil)
    }

    func item(for kind: WardrobeItem.Kind) -> String? {
        switch kind {
        case .hat: return hat
        case .glasses: return glasses
        case .neck: return neck
        case .back: return back
        case .color: return color
        case .shirt: return shirt
        case .shape: return shape
        }
    }

    mutating func set(_ id: String?, for kind: WardrobeItem.Kind) {
        switch kind {
        case .hat: hat = id
        case .glasses: glasses = id
        case .neck: neck = id
        case .back: back = id
        case .color: color = id
        case .shirt: shirt = id
        case .shape: shape = id
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
        /// A season item, only earned with the season's quests.
        case seasonOnly
    }

    func owns(_ item: WardrobeItem) -> Bool {
        item.isFree || ownedItems.contains(item.id)
    }

    /// Buys `item` with seeds. Pro items need Pro.
    mutating func buy(_ item: WardrobeItem, isPro: Bool) -> PurchaseResult {
        guard !owns(item) else { return .alreadyOwned }
        guard !item.isSeasonal else { return .seasonOnly }
        guard !item.needsPro || isPro else { return .needsPro }
        guard seeds >= item.price else { return .tooFewSeeds }
        seeds -= item.price
        ownedItems.insert(item.id)
        return .bought
    }

    /// Puts `item` on Pip, or takes it off when Pip already wears it. Taking off a color or a shape goes back to
    /// Pip's own. The flag shirt shows `country`'s flag.
    mutating func toggle(_ item: WardrobeItem, country: String = "SE") {
        guard owns(item) else { return }
        if outfit.wears(item) {
            outfit.set(nil, for: item.kind)
        } else {
            outfit.set(item.wornID(country: country), for: item.kind)
        }
    }

    /// Puts the flag shirt on Pip with `country`'s flag, when Pip has one.
    mutating func wearFlagShirt(of country: String) {
        guard let shirt = WardrobeItem.with(id: WardrobeItem.flagShirt), owns(shirt) else { return }
        outfit.shirt = WardrobeItem.flagShirtID(country: country)
    }
}

extension Outfit {
    /// The kinds in the order `code` lists them. New kinds go last, so older apps read the ones they know and skip
    /// the rest.
    private static let order: [WardrobeItem.Kind] = [.hat, .glasses, .neck, .back, .color, .shirt, .shape]
    private static let firstKinds = 5

    /// The outfit as one short string for the league, such as "hat-cap|glasses-sun|||color-neon". A shirt and a
    /// shape follow when Pip has them: "hat-cap||||color-neon|shirt-flag-SE|shape-tall".
    var code: String {
        var parts = Self.order.map { item(for: $0) ?? "" }
        while parts.count > Self.firstKinds && parts.last == "" {
            parts.removeLast()
        }
        return parts.joined(separator: "|")
    }

    /// An outfit of just `item`, to show it on its own.
    init(wearing item: WardrobeItem, country: String = "SE") {
        self.init()
        set(item.wornID(country: country), for: item.kind)
    }

    /// The outfit in `code`, keeping only items that exist and sit where they belong, so an old app or a tampered
    /// record can't make Pip draw something unknown.
    init(code: String?) {
        self.init()
        guard let code else { return }
        let ids = code.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        for (kind, id) in zip(Self.order, ids) {
            if let item = WardrobeItem.with(id: id), item.kind == kind {
                set(id, for: kind)
            }
        }
    }
}
