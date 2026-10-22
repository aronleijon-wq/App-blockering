import Foundation

/// The age question in the intro, with an age that stands for the whole group in the life math.
enum AgeGroup: String, Codable, CaseIterable, Identifiable {
    case under18, from18, from25, from35, from45, from55

    var id: Self { self }

    var label: String {
        switch self {
        case .under18: return "Under 18"
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
