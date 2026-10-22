import Foundation

/// League divisions, lowest first.
enum Division: Int, Codable, CaseIterable, Comparable {
    case brons, silver, guld, diamant, legend

    static func < (lhs: Division, rhs: Division) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .brons: return "Brons"
        case .silver: return "Silver"
        case .guld: return "Guld"
        case .diamant: return "Diamant"
        case .legend: return "Legend"
        }
    }

    var higher: Division { Division(rawValue: rawValue + 1) ?? self }
    var lower: Division { Division(rawValue: rawValue - 1) ?? self }

    /// Weekly points that promote when a week ends outside a league group.
    var promotionPoints: Int? {
        switch self {
        case .brons: return 200
        case .silver: return 350
        case .guld: return 500
        case .diamant: return 700
        case .legend: return nil
        }
    }

    /// Weekly points below which a week outside a league group relegates.
    var relegationPoints: Int? {
        switch self {
        case .brons: return nil
        case .silver: return 100
        case .guld: return 200
        case .diamant: return 300
        case .legend: return 400
        }
    }
}

/// A week that ended and still has to be turned into a division change.
struct FinishedWeek: Codable, Equatable {
    var weekKey: String
    var points: Int
    var division: Division
    var groupID: String?
}

enum League {
    /// Players per weekly group.
    static let groupSize = 30
    /// One in this many of a group moves up, and as many move down, at the end of the week.
    static let movingShare = 5
    /// Groups smaller than this only promote, so a duel with one friend never relegates anyone.
    static let minGroupForRelegation = 5

    enum Points {
        static let focusDailyCap = 120
        static let close = 5
        static let decline = 10
        static let dailyReward = 10
        static let dayUnderLimit = 30
        static let disabledProtectionPenalty = 100
    }

    /// League points the `number`th pause of a day costs: the first is free, then 10, 20 and 40.
    static func pausePenalty(forPause number: Int) -> Int {
        switch number {
        case ...1: return 0
        case 2: return 10
        case 3: return 20
        default: return 40
        }
    }

    /// ISO week such as "2026-W43", in the calendar's time zone.
    static func weekKey(for date: Date, calendar: Calendar) -> String {
        let iso = isoCalendar(like: calendar)
        let components = iso.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", components.yearForWeekOfYear ?? 0, components.weekOfYear ?? 0)
    }

    /// When the week containing `date` ends (Monday 00:00 after it).
    static func weekEnd(for date: Date, calendar: Calendar) -> Date {
        let iso = isoCalendar(like: calendar)
        return iso.dateInterval(of: .weekOfYear, for: date)?.end ?? date
    }

    /// Division after a week: by rank when the player was in a group, otherwise by points.
    static func nextDivision(after week: FinishedWeek, rank: Int?, groupSize: Int?) -> Division {
        if let rank, let groupSize, groupSize > 1 {
            let moving = max(1, groupSize / movingShare)
            if rank <= moving { return week.division.higher }
            if groupSize >= minGroupForRelegation, rank > groupSize - moving { return week.division.lower }
            return week.division
        }
        if let promotion = week.division.promotionPoints, week.points >= promotion { return week.division.higher }
        if let relegation = week.division.relegationPoints, week.points < relegation { return week.division.lower }
        return week.division
    }

    private static func isoCalendar(like calendar: Calendar) -> Calendar {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        return iso
    }
}

/// Validates public nicknames, which are the only thing other players see.
enum Nickname {
    enum Problem: Equatable {
        case tooShort, tooLong, invalidCharacters, notAllowed
    }

    static let minLength = 3
    static let maxLength = 16

    static func problem(with raw: String) -> Problem? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.count < minLength { return .tooShort }
        if name.count > maxLength { return .tooLong }
        let allowed = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: "_.-"))
        if name.unicodeScalars.contains(where: { !allowed.contains($0) }) { return .invalidCharacters }
        let normalized = normalize(name)
        if blocked.contains(where: { normalized.contains($0) }) { return .notAllowed }
        return nil
    }

    static let suggestionWords = ["Fokus", "Lugn", "Snabb", "Modig", "Klok", "Stark", "Glad", "Cool"]
    static let suggestionAnimals = ["Räv", "Uggla", "Tiger", "Panda", "Varg", "Lo", "Örn", "Delfin"]

    /// Fun nicknames such as "ModigRäv27". Every one passes `problem(with:)`.
    static func suggestions(count: Int, seed: Int) -> [String] {
        (0..<count).map { index in
            let value = abs(seed &+ index &* 7919)
            let word = suggestionWords[value % suggestionWords.count]
            let animal = suggestionAnimals[(value / suggestionWords.count + index) % suggestionAnimals.count]
            return "\(word)\(animal)\(10 + value % 90)"
        }
    }

    /// Lowercases and undoes common letter swaps such as "h0r4" so they can't slip past the filter.
    static func normalize(_ name: String) -> String {
        let swaps: [Character: Character] = ["0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s"]
        return String(name.lowercased().compactMap { character -> Character? in
            if let swap = swaps[character] { return swap }
            return character.isLetter ? character : nil
        })
    }

    /// Substrings that are never allowed in a nickname.
    private static let blocked: [String] = [
        "hora", "horunge", "fitta", "kuk", "knull", "javla", "jävla", "neger", "blatte", "bög", "fikus",
        "slyna", "mongo", "hitler", "nazi", "fuck", "shit", "cunt", "bitch", "whore", "slut", "nigg", "fag",
        "rape", "porn", "dick", "pussy", "cock", "admin", "moderator", "paus",
    ]
}
