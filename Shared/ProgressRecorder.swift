import Foundation

/// Records progress events from the app or an extension, always against the latest stored state.
enum ProgressRecorder {
    @discardableResult
    static func record(_ event: ProgressEvent, at date: Date = .now) -> [Reward] {
        SharedStore.updateProgress { $0.record(event, at: date, calendar: .current) }
    }

    /// DeviceActivity can report the end of an interval a little early.
    static let focusEndTolerance: TimeInterval = 30

    /// Awards a finished focus session and clears it. Clearing first makes a second call a no-op,
    /// so the app and the monitor extension can both call it.
    @discardableResult
    static func completeFocus(at date: Date = .now) -> [Reward] {
        var minutes = 0
        SharedStore.updateRuntime { runtime in
            guard let end = runtime.focusEndsAt else { return }
            // Stopping a session early also ends its monitoring, which calls this from the monitor.
            // Only a session that ran its course earns XP.
            guard date >= end.addingTimeInterval(-focusEndTolerance) else { return }
            let start = runtime.focusStartedAt ?? end
            minutes = max(0, Int((end.timeIntervalSince(start) / 60).rounded()))
            runtime.focusEndsAt = nil
            runtime.focusStartedAt = nil
        }
        guard minutes > 0 else { return [] }
        return record(.focusCompleted(minutes: minutes), at: date)
    }
}
