import ActivityKit
import Foundation

/// Keeps one Live Activity in step with what Paus is doing. iOS only lets the app itself start one,
/// so it is updated whenever the app changes something or comes to the front.
@MainActor
enum LiveActivities {
    static func sync(status: PausStatus, health: Int) {
        let current = Activity<PausActivityAttributes>.activities
        // A step session has no end time; it lasts until the steps are walked.
        let isRunning = status.end.map { $0 > .now } ?? (status.stepGoal != nil)
        guard status.kind != .free, isRunning else {
            for activity in current {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }
        // Stale once it is over, so the lock screen can say so even if the app hasn't run since.
        let content = ActivityContent(state: PausActivityAttributes.ContentState(status: status, health: health), staleDate: status.end)
        if let activity = current.first {
            guard activity.content.state != content.state else { return }
            Task { await activity.update(content) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try? Activity.request(attributes: PausActivityAttributes(), content: content, pushType: nil)
    }
}
