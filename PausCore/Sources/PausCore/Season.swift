import Foundation

/// A month with its own three quests, a trophy for finishing them all, and things for Pip that can only be earned
/// that month. They never come back, so they're worth showing off.
struct Season: Equatable {
    /// The month, such as "2026-11".
    let key: String
    let name: String
    let symbol: String
    /// The items the first quests give, in order. Months without their own items have none.
    let items: [String]
    /// A line under the name, for months that have one.
    var tagline: String? = nil

    var trophyID: String { "season-\(key)" }

    /// The months with a name and items of their own. Other months get the month's name and quests only.
    private static var named: [String: (name: String, symbol: String, items: [String])] { [
        "2026-11": ("Lock in", "lock.fill", ["color-iron"]),
        "2026-12": (L("Vinter"), "snowflake", ["hat-santa", "color-frost"]),
        "2027-01": (L("Nystart"), "sunrise.fill", ["glasses-gold", "color-dawn"]),
    ] }

    static func key(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    static func at(_ date: Date, calendar: Calendar) -> Season {
        with(key: key(for: date, calendar: calendar))
    }

    static func with(key: String) -> Season {
        if let named = named[key] {
            let tagline = key == "2026-11" ? L("Extra utmaningar hela november. Dags att låsa in.") : nil
            return Season(key: key, name: named.name, symbol: named.symbol, items: named.items, tagline: tagline)
        }
        return Season(key: key, name: monthName(key), symbol: "calendar", items: [])
    }

    /// The season a season quest id such as "s-2026-11-2" belongs to.
    static func containing(questID id: String) -> Season? {
        guard id.hasPrefix("s-"), id.count >= 9 else { return nil }
        return with(key: String(id.dropFirst(2).prefix(7)))
    }

    /// The season whose trophy id such as "season-2026-11" this is.
    static func containing(trophyID id: String) -> Season? {
        guard id.hasPrefix("season-") else { return nil }
        return with(key: String(id.dropFirst(7)))
    }

    /// Whether `id` is an item only a season gives.
    static func isSeasonItem(_ id: String) -> Bool {
        named.values.contains { $0.items.contains(id) }
    }

    /// The season that gives item `id`.
    static func giving(item id: String) -> Season? {
        named.first { $0.value.items.contains(id) }.map { with(key: $0.key) }
    }

    /// Three goals for the month: lots of focus, many daily quests and many calm days.
    var quests: [Quest] { [
        Quest(id: "s-\(key)-1", title: L("Fokusera 15 timmar den här månaden"), symbol: "flame.fill", metric: .focusMinutes, target: 900, xp: 400, tier: .season),
        Quest(id: "s-\(key)-2", title: L("Klara 25 dagliga uppdrag den här månaden"), symbol: "checklist", metric: .dailyQuests, target: 25, xp: 400, tier: .season),
        Quest(id: "s-\(key)-3", title: L("Scrolla mindre än 2 timmar 15 dagar"), symbol: "leaf.circle.fill", metric: .lowScrollDays, target: 15, xp: 500, tier: .season),
    ] }

    var trophy: Achievement {
        let id = trophyID
        return Achievement(id: id, title: L("Säsong: \(name)"), detail: L("Klara alla säsongsuppdrag i \(Season.monthName(key))"), symbol: symbol) {
            $0.unlocked.contains(id)
        }
    }

    /// The days left of the season, counting `date`'s day.
    func daysLeft(from date: Date, calendar: Calendar) -> Int {
        let end = calendar.dateInterval(of: .month, for: date)?.end ?? date
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: end)).day ?? 0
        return max(0, days)
    }

    /// "november 2026" in the app's language.
    static func monthName(_ key: String) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2, let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: parts[0], month: parts[1], day: 15)) else {
            return key
        }
        return date.formatted(.dateTime.month(.wide).year().locale(Language.current.locale))
    }

    static func == (lhs: Season, rhs: Season) -> Bool { lhs.key == rhs.key }
}
