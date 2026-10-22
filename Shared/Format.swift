import Foundation

/// Swedish display text shared by the app and the shield.
enum Format {
    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: Language.current.locale))
    }

    /// "4:05" or "1:02:03" until `end`.
    static func countdown(to end: Date, from now: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(now).rounded(.up)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let rest = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }

    static func minutes(_ value: Int) -> String {
        switch value {
        case ..<60: return "\(value) min"
        case _ where value % 60 == 0: return "\(value / 60) h"
        default: return "\(value / 60) h \(value % 60) min"
        }
    }

    /// "08:30" for minutes after midnight.
    static func clock(minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    static func reason(_ reason: BlockReason) -> String {
        switch reason {
        case .focus(let until):
            return L("Fokuspass till \(time(until))")
        case .schedule(let name, let until):
            return L("Schemat ”\(name)” gäller till \(time(until))")
        case .dailyLimit(let minutes):
            return L("Du har använt dina \(Format.minutes(minutes)) för idag")
        }
    }

    static func weekdays(_ days: Set<Int>) -> String {
        switch days {
        case Set(1...7): return L("Varje dag")
        case [2, 3, 4, 5, 6]: return L("Vardagar")
        case [1, 7]: return L("Helger")
        default: return Weekday.mondayFirst.filter { days.contains($0.number) }.map(\.short).joined(separator: ", ")
        }
    }
}

struct Weekday {
    /// `Calendar` weekday number, 1 = Sunday.
    let number: Int
    let letter: String
    let short: String
    let name: String

    /// Monday to Sunday, named in the app's language.
    static var mondayFirst: [Weekday] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Language.current.locale
        return [2, 3, 4, 5, 6, 7, 1].map { number in
            Weekday(
                number: number,
                letter: calendar.veryShortStandaloneWeekdaySymbols[number - 1],
                short: calendar.shortStandaloneWeekdaySymbols[number - 1],
                name: calendar.standaloneWeekdaySymbols[number - 1]
            )
        }
    }
}
