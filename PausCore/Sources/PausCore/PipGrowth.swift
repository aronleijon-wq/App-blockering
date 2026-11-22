import Foundation

/// Pip grows up with the hours of focus: from a baby to a master. A Pip someone has raised for weeks is a reason to
/// stay. It never shrinks back.
enum PipGrowth {
    enum Stage: Int, Codable, CaseIterable, Comparable {
        case baby, child, teen, adult, master

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }

        var name: String {
            switch self {
            case .baby: return L("Bebis")
            case .child: return L("Liten")
            case .teen: return L("Tonåring")
            case .adult: return L("Vuxen")
            case .master: return L("Mästare")
            }
        }

        /// Hours of focus in all that reach this stage.
        var hours: Int {
            switch self {
            case .baby: return 0
            case .child: return 3
            case .teen: return 10
            case .adult: return 30
            case .master: return 75
            }
        }

        var next: Stage? { Stage(rawValue: rawValue + 1) }

        /// How big Pip is drawn, smaller while young.
        var scale: Double {
            switch self {
            case .baby: return 0.8
            case .child: return 0.88
            case .teen: return 0.95
            case .adult, .master: return 1
            }
        }

        /// How big Pip's eyes are, bigger while young.
        var eyeScale: Double {
            switch self {
            case .baby: return 1.25
            case .child: return 1.12
            case .teen: return 1.04
            case .adult, .master: return 1
            }
        }
    }

    static func stage(focusMinutes: Int) -> Stage {
        Stage.allCases.last { focusMinutes >= $0.hours * 60 } ?? .baby
    }
}

extension PlayerProgress {
    var growthStage: PipGrowth.Stage { PipGrowth.stage(focusMinutes: focusMinutes) }

    /// Minutes of focus left to the next stage, or nil at the last one.
    var minutesToNextStage: Int? {
        growthStage.next.map { max(0, $0.hours * 60 - focusMinutes) }
    }

    /// How far along the way to the next stage, 0...1.
    var growthFraction: Double {
        let stage = growthStage
        guard let next = stage.next else { return 1 }
        let start = stage.hours * 60, end = next.hours * 60
        return Double(focusMinutes - start) / Double(max(1, end - start))
    }
}

/// Pip's letter about the week: the focus so far against last week's.
struct WeeklyLetter: Equatable {
    let thisWeekMinutes: Int
    let lastWeekMinutes: Int
    let sessions: Int
    let quests: Int

    /// The change in percent against last week, or nil without a last week to compare with.
    var change: Int? {
        guard lastWeekMinutes > 0 else { return nil }
        return Int((Double(thisWeekMinutes - lastWeekMinutes) / Double(lastWeekMinutes) * 100).rounded())
    }

    /// The week from Monday that `date` is in, and the one before, from the day history and today.
    static func make(from progress: PlayerProgress, at date: Date, calendar: Calendar) -> WeeklyLetter {
        var days = progress.history
        let today = progress.counts(at: date, calendar: calendar)
        if let key = today.day { days[key] = DaySummary(today) }
        let weekday = calendar.component(.weekday, from: date)
        let sinceMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -sinceMonday, to: calendar.startOfDay(for: date)) ?? date
        func keys(from start: Date) -> [String] {
            (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }.map { DayKey.string(for: $0, calendar: calendar) }
        }
        let lastMonday = calendar.date(byAdding: .day, value: -7, to: monday) ?? monday
        let this = keys(from: monday).compactMap { days[$0] }
        let last = keys(from: lastMonday).compactMap { days[$0] }
        return WeeklyLetter(
            thisWeekMinutes: this.reduce(0) { $0 + $1.focusMinutes },
            lastWeekMinutes: last.reduce(0) { $0 + $1.focusMinutes },
            sessions: this.reduce(0) { $0 + $1.focusSessions },
            quests: this.reduce(0) { $0 + $1.quests }
        )
    }

    var title: String {
        if thisWeekMinutes == 0 { return L("Pips veckobrev 💌") }
        if let change, change > 0 { return L("Din vecka: +\(change) % fokus 📈") }
        return L("Din vecka med Pip 💜")
    }

    var body: String {
        let hours = Double(thisWeekMinutes) / 60
        let time = hours >= 1 ? L("\(Int(hours.rounded())) h") : L("\(thisWeekMinutes) min")
        if thisWeekMinutes == 0 {
            return L("Inget fokus den här veckan än. Ett pass i kväll, så har Pip något att skryta om.")
        }
        if let change, change > 0 {
            return L("\(time) fokus på \(sessions) pass, mer än förra veckan. Pip är så stolt. Håll i det!")
        }
        if change != nil {
            return L("\(time) fokus på \(sessions) pass. Lite mindre än förra veckan, men en ny vecka börjar i morgon.")
        }
        return L("\(time) fokus på \(sessions) pass och \(quests) uppdrag klara. Pip är stolt över dig.")
    }
}
