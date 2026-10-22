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
            ProgressRecorder.completeFocus()
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
        if let minutes = event.scrolledMinutes {
            recordHealth(.scrolled(minutes: minutes), scrolledMinutes: minutes)
            return
        }
        guard event == .dailyLimit else { return }
        let today = DayKey.string(for: .now, calendar: .current)
        var isFirstTimeToday = false
        SharedStore.updateRuntime { runtime in
            isFirstTimeToday = runtime.limitReachedDay != today
            runtime.limitReachedDay = today
        }
        if isFirstTimeToday {
            recordHealth(.reachedDailyLimit, scrolledMinutes: nil)
        }
        ShieldController.refresh()
    }

    /// Records something that hurts Pip and lets the user know when Pip feels worse because of it.
    private func recordHealth(_ event: ProgressEvent, scrolledMinutes: Int?) {
        let before = SharedStore.progress.healthStage
        ProgressRecorder.record(event)
        let progress = SharedStore.progress
        guard progress.healthStage < before else { return }
        PipNotifier.healthDropped(to: progress.healthStage, health: progress.health, scrolledMinutes: scrolledMinutes)
    }
}
