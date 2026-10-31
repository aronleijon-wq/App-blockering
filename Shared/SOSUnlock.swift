// Screen Time code, which the widgets leave out since they have no Family Controls entitlement.
#if !WIDGET_EXTENSION
import Foundation

/// Unblocks everything at once, from the app or straight from the shield.
enum SOSUnlock {
    /// Ends a running focus or step session, lifts schedules and the daily limit for `SOS.minutes`,
    /// records what it cost and lowers the shield. Returns what it cost.
    @discardableResult
    static func activate(at date: Date = .now) -> [Reward] {
        let runtime = SharedStore.runtime
        if let end = runtime.focusEndsAt, end > date {
            // Clear the session before stopping its monitoring, so the monitor finds nothing to award.
            SharedStore.updateRuntime {
                $0.focusStartedAt = nil
                $0.focusEndsAt = nil
                $0.focusStepGoal = nil
                $0.focusStepsWalked = nil
                $0.focusStepsCheckedAt = nil
            }
            ActivityScheduler.stopFocus()
            ActivityScheduler.stopStepChecks()
            Notifier.cancel([Notifier.ID.focusDone])
        }
        let end = date.addingTimeInterval(TimeInterval(SOS.minutes * 60))
        let engine = BlockEngine(rules: SharedStore.effectiveRules, runtime: SharedStore.runtime)
        // Schedules or the daily limit still block: book the moment they come back. If booking fails,
        // the SOS still lifts them, and the next refresh after the end puts the shield back.
        if engine.reason(at: date) != nil {
            try? ActivityScheduler.startSOS(until: end)
            SharedStore.updateRuntime { $0.sosUntil = end }
        }
        let rewards = ProgressRecorder.record(.usedSOS, at: date)
        ShieldController.refresh(at: date)
        return rewards
    }

    /// Puts the blocks back before the SOS is over.
    static func end() {
        ActivityScheduler.stopSOS()
        SharedStore.updateRuntime { $0.sosUntil = nil }
        ShieldController.refresh()
    }
}
#endif
