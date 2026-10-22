import DeviceActivity
import ManagedSettings
import SwiftUI

/// Draws the screen time report inside Paus. iOS runs this extension in a sandbox: it can read the
/// Screen Time data, but nothing it computes can leave it, so the numbers are only ever shown.
@main
struct PausReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        ScreenTimeScene(context: .pausToday) { ScreenTimeReportView(summary: $0, style: .compact) }
        ScreenTimeScene(context: .pausWeek) { ScreenTimeReportView(summary: $0, style: .full) }
    }
}

struct ScreenTimeScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context
    let content: (ScreenTimeSummary) -> ScreenTimeReportView

    /// How many apps the report lists.
    private static let topAppCount = 5

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ScreenTimeSummary {
        let calendar = Calendar.current
        let now = Date.now
        let today = calendar.startOfDay(for: now)
        var totals: [Date: TimeInterval] = [:]
        var apps: [String: ScreenTimeSummary.AppUsage] = [:]
        var pickups = 0
        var firstPickup: Date?

        for await device in data {
            for await segment in device.activitySegments {
                let day = calendar.startOfDay(for: segment.dateInterval.start)
                totals[day, default: 0] += segment.totalActivityDuration
                guard day == today else { continue }

                pickups += segment.totalPickupsWithoutApplicationActivity
                if let first = segment.firstPickup {
                    firstPickup = min(firstPickup ?? first, first)
                }
                for await category in segment.categories {
                    for await activity in category.applications {
                        let application = activity.application
                        pickups += activity.numberOfPickups
                        let name = application.localizedDisplayName ?? application.bundleIdentifier ?? L("Okänd app")
                        let key = application.bundleIdentifier ?? name
                        let earlier = apps[key]
                        apps[key] = ScreenTimeSummary.AppUsage(
                            id: key,
                            name: name,
                            token: application.token ?? earlier?.token,
                            duration: (earlier?.duration ?? 0) + activity.totalActivityDuration,
                            pickups: (earlier?.pickups ?? 0) + activity.numberOfPickups
                        )
                    }
                }
            }
        }

        let days = ScreenTimeSummary.emptyDays(endingAt: now, calendar: calendar).map {
            ScreenTimeSummary.Day(start: $0, duration: totals[$0] ?? 0)
        }
        let topApps = apps.values
            .filter { $0.duration >= 60 }
            .sorted { $0.duration > $1.duration }
            .prefix(Self.topAppCount)
        return ScreenTimeSummary(days: days, topApps: Array(topApps), pickupsToday: pickups, firstPickupToday: firstPickup)
    }
}
