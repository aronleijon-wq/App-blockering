// The widgets show steps from the shared store and never count them themselves.
#if !WIDGET_EXTENSION
import CoreMotion
import Foundation

/// The phone's own step count from its motion chip. Unlike Health it can be read while the phone is locked
/// and from the monitor extension, so a step session can finish while Paus isn't running.
enum Pedometer {
    private static let pedometer = CMPedometer()

    static var isAvailable: Bool { CMPedometer.isStepCountingAvailable() }

    /// Steps from `start` until now, or nil when they can't be read. The first call asks for Motion & Fitness access.
    static func steps(since start: Date) async -> Int? {
        guard isAvailable else { return nil }
        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: .now) { data, error in
                continuation.resume(returning: error == nil ? data?.numberOfSteps.intValue : nil)
            }
        }
    }

    /// The same, for the monitor extension, whose callbacks have to finish their work before they return.
    static func stepsWaiting(since start: Date, timeout: TimeInterval = 5) -> Int? {
        guard isAvailable else { return nil }
        let semaphore = DispatchSemaphore(value: 0)
        var result: Int?
        pedometer.queryPedometerData(from: start, to: .now) { data, error in
            if error == nil { result = data?.numberOfSteps.intValue }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + timeout)
        return result
    }
}

/// Keeps a running step session up to date, from the app or from the monitor extension every quarter hour,
/// and ends it as soon as the goal is walked so the apps unlock even while Paus isn't running.
enum StepChecker {
    /// Saves `walked` for the lock screen and ends the session once the goal is reached. Returns whether it ended.
    @discardableResult
    static func record(_ walked: Int, notify: Bool, at date: Date = .now) -> Bool {
        var goal: Int?
        SharedStore.updateRuntime { runtime in
            guard let stepGoal = runtime.focusStepGoal else { return }
            goal = stepGoal
            // Health and the motion chip can disagree a little; never show fewer steps than before.
            runtime.focusStepsWalked = max(walked, runtime.focusStepsWalked ?? 0)
            runtime.focusStepsCheckedAt = date
        }
        guard let goal else { return false }
        guard walked >= goal else {
            WidgetRefresher.reload()
            return false
        }
        // Clear the session before stopping its monitoring, which reports the stop to the monitor too.
        ProgressRecorder.completeStepFocus(at: date)
        ActivityScheduler.stopFocus()
        ActivityScheduler.stopStepChecks()
        ShieldController.refresh()
        if notify {
            Notifier.stepGoalReached(steps: goal)
        }
        return true
    }

    /// Called by the monitor extension when a check comes due: counts, and books the next check unless it is done.
    static func checkFromMonitor() {
        let runtime = SharedStore.runtime
        guard runtime.focusStepGoal != nil, let start = runtime.focusStartedAt else { return }
        if let walked = Pedometer.stepsWaiting(since: start), record(walked, notify: true) { return }
        try? ActivityScheduler.scheduleStepCheck()
    }
}
#endif
