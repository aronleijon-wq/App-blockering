import DeviceActivity
import FamilyControls
import Foundation

extension DeviceActivityName {
    static let focus = Self("paus.focus")
    static let pause = Self("paus.pause")
    static let dailyLimit = Self("paus.limit")

    private static let schedulePrefix = "paus.schedule."

    static func schedule(_ id: UUID) -> Self {
        Self(schedulePrefix + id.uuidString)
    }

    /// The schedule this activity monitors, if it is a schedule activity.
    var scheduleID: UUID? {
        guard rawValue.hasPrefix(Self.schedulePrefix) else { return nil }
        return UUID(uuidString: String(rawValue.dropFirst(Self.schedulePrefix.count)))
    }
}

extension DeviceActivityEvent.Name {
    static let dailyLimit = Self("paus.limit.reached")
}

/// Registers DeviceActivity monitoring so the monitor extension wakes up when blocks should start or end,
/// even while the app isn't running.
enum ActivityScheduler {
    private static let center = DeviceActivityCenter()
    /// DeviceActivity rejects intervals shorter than 15 minutes.
    private static let minimumInterval: TimeInterval = 15 * 60

    /// Whether the registered schedule and limit activities match the saved rules.
    static func isInSync(rules: PausRules, selection: FamilyActivitySelection) -> Bool {
        let registered = Set(center.activities.filter { $0.scheduleID != nil || $0 == .dailyLimit })
        return registered == expectedActivities(rules: rules, selection: selection)
    }

    /// Re-registers schedule and daily-limit monitoring from the enforced rules. Focus and pause are left running.
    static func sync() throws {
        let rules = SharedStore.effectiveRules
        let selection = SharedStore.selection
        let stale = center.activities.filter { $0.scheduleID != nil || $0 == .dailyLimit }
        // An empty list would stop every activity, focus and pause included.
        if !stale.isEmpty {
            center.stopMonitoring(stale)
        }

        var firstError: Error?
        for schedule in rules.schedules where isMonitorable(schedule) {
            // Schedules repeat daily; the monitor extension checks the weekday when an interval starts.
            let interval = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: schedule.startMinute / 60, minute: schedule.startMinute % 60),
                intervalEnd: DateComponents(hour: schedule.endMinute / 60, minute: schedule.endMinute % 60),
                repeats: true
            )
            do {
                try center.startMonitoring(.schedule(schedule.id), during: interval)
            } catch {
                firstError = firstError ?? error
            }
        }

        if let limit = rules.dailyLimitMinutes, !selection.isEmpty {
            let day = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0),
                intervalEnd: DateComponents(hour: 23, minute: 59),
                repeats: true
            )
            do {
                try center.startMonitoring(.dailyLimit, during: day, events: [.dailyLimit: limitEvent(minutes: limit, selection: selection)])
            } catch {
                firstError = firstError ?? error
            }
        }

        if let firstError { throw firstError }
    }

    static func startFocus(until end: Date) throws {
        try startOneShot(.focus, until: end)
    }

    static func stopFocus() {
        center.stopMonitoring([.focus])
    }

    static func startPause(until end: Date) throws {
        try startOneShot(.pause, until: end)
    }

    static func stopPause() {
        center.stopMonitoring([.pause])
    }

    private static func expectedActivities(rules: PausRules, selection: FamilyActivitySelection) -> Set<DeviceActivityName> {
        var names = Set(rules.schedules.filter(isMonitorable).map { DeviceActivityName.schedule($0.id) })
        if rules.dailyLimitMinutes != nil, !selection.isEmpty {
            names.insert(.dailyLimit)
        }
        return names
    }

    private static func isMonitorable(_ schedule: BlockSchedule) -> Bool {
        schedule.isEnabled && !schedule.weekdays.isEmpty && schedule.durationMinutes >= 15 && schedule.durationMinutes < 1440
    }

    private static func limitEvent(minutes: Int, selection: FamilyActivitySelection) -> DeviceActivityEvent {
        let threshold = DateComponents(minute: minutes)
        if #available(iOS 17.4, *) {
            // Count usage from midnight, so re-registering during the day doesn't reset the limit.
            return DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: threshold,
                includesPastActivity: true
            )
        }
        return DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: threshold
        )
    }

    /// Monitors one interval ending at `end`, backdating its start when needed to meet the minimum length.
    private static func startOneShot(_ name: DeviceActivityName, until end: Date) throws {
        let calendar = Calendar.current
        let start = min(Date.now, end.addingTimeInterval(-minimumInterval))
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: start),
            intervalEnd: calendar.dateComponents(components, from: end),
            repeats: false
        )
        center.stopMonitoring([name])
        try center.startMonitoring(name, during: schedule)
    }
}
