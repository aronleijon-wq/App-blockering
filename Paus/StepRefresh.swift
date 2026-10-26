import BackgroundTasks

/// Asks iOS to wake Paus now and then during a step session, so the step count on the lock screen moves
/// and the apps unlock once the goal is walked. iOS decides when; the monitor extension checks every
/// quarter hour as well.
enum StepRefresh {
    /// Listed under `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    static let identifier = "paus.step-refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date.now.addingTimeInterval(15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
