import Foundation

/// The age question in the intro, with an age that stands for the whole group in the life math.
enum AgeGroup: String, Codable, CaseIterable, Identifiable {
    case under18, from18, from25, from35, from45, from55

    var id: Self { self }

    var label: String {
        switch self {
        case .under18: return L("Under 18")
        case .from18: return "18–24"
        case .from25: return "25–34"
        case .from35: return "35–44"
        case .from45: return "45–54"
        case .from55: return "55+"
        }
    }

    var typicalAge: Int {
        switch self {
        case .under18: return 16
        case .from18: return 21
        case .from25: return 30
        case .from35: return 40
        case .from45: return 50
        case .from55: return 60
        }
    }
}

/// What the user answered in the intro. Stays on the phone.
struct IntroAnswers: Codable, Equatable {
    /// What Pip calls the user. Never shown to anyone else.
    var name = ""
    var ageGroup: AgeGroup = .from18
    var hoursPerDay: Double = 4
    /// Names of the apps the user said take the most time.
    var apps: [String] = []
    /// What the user would rather do with the time.
    var goals: [String] = []
}

/// The numbers the intro shows. Waking time assumes 16 waking hours a day and a life to 80,
/// the same assumptions as the ads.
enum LifeMath {
    static let lifeExpectancy = 80
    static let wakingHoursPerDay = 16.0

    /// Years of waking life spent on the phone from `age` until 80, at `hoursPerDay`.
    static func wakingYears(hoursPerDay: Double, age: Int) -> Double {
        let remainingYears = Double(max(0, lifeExpectancy - age))
        return hoursPerDay / wakingHoursPerDay * remainingYears
    }

    /// The share of each waking day spent on the phone, 0...1.
    static func shareOfWakingTime(hoursPerDay: Double) -> Double {
        min(1, max(0, hoursPerDay / wakingHoursPerDay))
    }

    static func hoursPerYear(hoursPerDay: Double) -> Int {
        Int((hoursPerDay * 365).rounded())
    }

    /// Whole 24-hour days per year.
    static func daysPerYear(hoursPerDay: Double) -> Int {
        Int((hoursPerDay * 365 / 24).rounded())
    }
}

/// What Paus promises at the end of the intro: a realistic cut, not an empty phone.
enum Plan {
    /// The share of screen time the plan aims to cut.
    static let reduction = 0.3

    static func targetHours(from hoursPerDay: Double) -> Double {
        hoursPerDay * (1 - reduction)
    }

    /// Waking years won back from `age` until 80.
    static func yearsBack(hoursPerDay: Double, age: Int) -> Double {
        LifeMath.wakingYears(hoursPerDay: hoursPerDay, age: age) * reduction
    }

    /// Whole 24-hour days won back over the next year.
    static func daysBackPerYear(hoursPerDay: Double) -> Int {
        Int((hoursPerDay * reduction * 365 / 24).rounded())
    }

    /// How much more of each waking day is spent offline, as a share of the offline time before.
    static func offlineIncrease(hoursPerDay: Double) -> Double {
        let offline = LifeMath.wakingHoursPerDay - hoursPerDay
        guard offline > 0 else { return 0 }
        return hoursPerDay * reduction / offline
    }
}

/// The reminder before a free trial turns into a paid subscription.
enum TrialReminder {
    static let choices = [2, 3]
    static let defaultDaysBefore = 2
    static let hour = 10

    /// The morning `daysBefore` days ahead of `trialEnd`, or nil when that is already past.
    static func date(trialEnd: Date, daysBefore: Int, now: Date, calendar: Calendar) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: trialEnd),
              let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
              date > now else { return nil }
        return date
    }
}

