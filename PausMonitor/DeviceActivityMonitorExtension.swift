import DeviceActivity
import Foundation

/// Woken by the system when a monitored interval starts or ends, or the daily limit is reached.
/// Each callback updates the shared state and lets `ShieldController` decide what to shield.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if let id = activity.scheduleID {
            ShieldController.refresh(scheduleOverrides: [id: true])
        } else {
            ShieldController.refresh()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        switch activity {
        case .focus:
            SharedStore.updateRuntime { $0.focusEndsAt = nil }
            ShieldController.refresh()
        case .pause:
            SharedStore.updateRuntime { $0.pausedUntil = nil }
            ShieldController.refresh()
        default:
            if let id = activity.scheduleID {
                ShieldController.refresh(scheduleOverrides: [id: false])
            } else {
                ShieldController.refresh()
            }
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard event == .dailyLimit else { return }
        SharedStore.updateRuntime { $0.limitReachedDay = DayKey.string(for: .now, calendar: .current) }
        ShieldController.refresh()
    }
}
