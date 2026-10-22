import DeviceActivity
import Foundation

/// Woken by the system when a monitored interval starts or ends, or the daily limit is reached.
/// Each callback updates the shared state and lets `ShieldController` decide what to shield.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if let id = activity.scheduleID {
            ShieldController.refresh(scheduleOverrides: [id: true])
            announceSchedule(id)
        } else {
            ShieldController.refresh()
        }
    }

    /// Tells the user a schedule just started blocking, unless it doesn't run today or they're on vacation.
    private func announceSchedule(_ id: UUID) {
        let engine = BlockEngine(rules: SharedStore.effectiveRules, runtime: SharedStore.runtime)
        if case .schedule(let name, let until) = engine.reason(at: .now, scheduleOverrides: [id: true]),
           SharedStore.effectiveRules.schedules.contains(where: { $0.id == id && $0.name == name }) {
            Notifier.scheduleStarted(name: name, until: until)
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
            // Pip doesn't mind scrolling on vacation.
            guard !SharedStore.rules.isOnVacation(at: .now) else { return }
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
            if let minutes = SharedStore.effectiveRules.dailyLimitMinutes {
                Notifier.limitReached(minutes: minutes)
            }
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
        Notifier.healthDropped(to: progress.healthStage, health: progress.health, scrolledMinutes: scrolledMinutes)
    }
}
