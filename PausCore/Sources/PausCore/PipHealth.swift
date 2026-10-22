import Foundation

/// How Pip feels, from 0 to 100. Scrolling, pauses and going over the limit wear Pip down;
/// focus, saying no and a night's sleep bring Pip back. It never touches XP or levels.
enum PipHealth {
    static let maximum = 100
    static let start = 80

    static let overnight = 15
    static let declinedPause = 5
    static let closedBlockedApp = 2
    static let dailyReward = 5
    static let dayUnderLimit = 10
    /// Health per this many focus minutes that also counted toward league points, so the daily focus cap applies.
    static let focusMinutesPerPoint = 5

    /// Usage of the guarded apps is reported in steps of this many minutes.
    static let scrollStepMinutes = 30
    /// The last step reported; scrolling past six hours can't make Pip any sadder.
    static let scrollMaxMinutes = 360
    static let perScrollStep = 5
    static let reachedDailyLimit = 15
    static let disabledProtection = 40

    /// Health the `number`th pause of a day costs, rising like the league penalty.
    static func pauseCost(forPause number: Int) -> Int {
        switch number {
        case ...1: return 5
        case 2: return 10
        case 3: return 15
        default: return 25
        }
    }

    /// Usage thresholds, in minutes, that the monitor extension reports.
    static var scrollThresholds: [Int] {
        Array(stride(from: scrollStepMinutes, through: scrollMaxMinutes, by: scrollStepMinutes))
    }

    enum Stage: Int, Comparable, CaseIterable {
        case wrecked, sick, down, okay, great

        init(health: Int) {
            switch health {
            case ..<15: self = .wrecked
            case ..<35: self = .sick
            case ..<60: self = .down
            case ..<85: self = .okay
            default: self = .great
            }
        }

        var label: String {
            switch self {
            case .wrecked: return "Scrollsjuk"
            case .sick: return "Mår dåligt"
            case .down: return "Lite nere"
            case .okay: return "Mår okej"
            case .great: return "Pigg och glad"
            }
        }

        static func < (lhs: Stage, rhs: Stage) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}
