import DeviceActivity
import Foundation
import ManagedSettings
import SwiftUI

extension DeviceActivityReport.Context {
    /// Today's screen time and the week at a glance, for the home screen.
    static let pausToday = Self("paus.today")
    /// The whole week with the most used apps.
    static let pausWeek = Self("paus.week")
}

/// Screen time worked out by the report extension. iOS keeps it inside the extension;
/// the app only shows the extension's view, so none of it reaches Paus or the league.
struct ScreenTimeSummary {
    struct Day: Identifiable {
        let start: Date
        let duration: TimeInterval
        var id: Date { start }
    }

    struct AppUsage: Identifiable {
        let id: String
        let name: String
        let token: ApplicationToken?
        let duration: TimeInterval
        let pickups: Int
    }

    /// Today, the seven days before it and the seven before those.
    static let dayCount = 15

    /// Oldest first; the last day is today.
    var days: [Day]
    /// Today's most used apps, most used first.
    var topApps: [AppUsage]
    var pickupsToday: Int
    var firstPickupToday: Date?
    /// The phone the numbers come from, as named in its settings, so it's clear whose screen time this is.
    var deviceName: String? = nil

    var today: TimeInterval { days.last?.duration ?? 0 }

    /// The last seven days, today included, for the chart.
    var chartDays: [Day] { Array(days.suffix(7)) }

    /// Average per day over the last seven whole days, or nil without any screen time in them.
    var weekAverage: TimeInterval? { Self.average(days.dropLast().suffix(7)) }

    /// The same average for the week before.
    var previousWeekAverage: TimeInterval? { Self.average(days.dropLast(8).suffix(7)) }

    /// Whole days per year at the current pace.
    var daysPerYear: Int? {
        weekAverage.map { Int(($0 * 365 / 86_400).rounded()) }
    }

    private static func average(_ days: ArraySlice<Day>) -> TimeInterval? {
        let total = days.reduce(0) { $0 + $1.duration }
        guard total > 0, !days.isEmpty else { return nil }
        return total / Double(days.count)
    }

    /// Fifteen empty days ending today.
    static func emptyDays(endingAt date: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: date)
        return (0..<dayCount).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    /// The interval the report covers, for `DeviceActivityFilter`.
    static func interval(endingAt date: Date, calendar: Calendar) -> DateInterval {
        let today = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? date
        return DateInterval(start: start, end: end)
    }

    /// Made-up numbers for the Simulator, where Screen Time has no data.
    static var sample: ScreenTimeSummary {
        let calendar = Calendar.current
        let hours: [Double] = [5.8, 6.4, 5.1, 6.9, 7.2, 4.8, 6.1, 5.5, 4.9, 5.2, 4.1, 3.8, 4.4, 3.2, 2.1]
        let days = zip(emptyDays(endingAt: .now, calendar: calendar), hours).map { Day(start: $0, duration: $1 * 3600) }
        return ScreenTimeSummary(
            days: days,
            topApps: [
                AppUsage(id: "tiktok", name: "TikTok", token: nil, duration: 52 * 60, pickups: 14),
                AppUsage(id: "instagram", name: "Instagram", token: nil, duration: 31 * 60, pickups: 11),
                AppUsage(id: "youtube", name: "YouTube", token: nil, duration: 24 * 60, pickups: 4),
                AppUsage(id: "snapchat", name: "Snapchat", token: nil, duration: 13 * 60, pickups: 9),
                AppUsage(id: "safari", name: "Safari", token: nil, duration: 6 * 60, pickups: 3),
            ],
            pickupsToday: 47,
            firstPickupToday: calendar.date(bySettingHour: 7, minute: 12, second: 0, of: .now)
        )
    }
}

/// Swedish formatting for the report.
enum ReportFormat {
    /// "2 h 14 min", "45 min" or "0 min".
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        return minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
    }

    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: Language.current.locale))
    }
}

/// The app's colors, repeated here because the report extension doesn't include the app's design files.
enum ReportPalette {
    static let background = Color(red: 0.055, green: 0.043, blue: 0.122)
    static let card = Color(red: 0.106, green: 0.086, blue: 0.212)
    static let cardRaised = Color(red: 0.149, green: 0.122, blue: 0.282)
    static let violet = Color(red: 0.545, green: 0.361, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.31, blue: 0.64)
    static let orange = Color(red: 1.0, green: 0.71, blue: 0.28)
    static let mint = Color(red: 0.235, green: 0.94, blue: 0.69)
    static let glow = LinearGradient(colors: [violet, pink], startPoint: .leading, endPoint: .trailing)
}
