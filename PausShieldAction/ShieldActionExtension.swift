import Foundation
import ManagedSettings
import UserNotifications

/// Handles the shield's buttons. "Stäng" closes the blocked app; "Ta en paus" can't open Paus directly,
/// so it posts a notification that does, and Paus shows the pause screen when it opens.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let now = Date.now
        let rules = SharedStore.effectiveRules
        let engine = BlockEngine(rules: rules, runtime: SharedStore.runtime)
        if action == .secondaryButtonPressed, engine.canOpenApp(at: now) {
            open(application, minutes: rules.openMinutes, at: now)
            // Deferring redraws the shield, which this app no longer has, so it opens.
            completionHandler(.defer)
            return
        }
        handle(action, completionHandler: completionHandler)
    }

    /// Lets one app through under the open limit, and books the moment it's blocked again.
    private func open(_ application: ApplicationToken, minutes: Int, at now: Date) {
        let end = now.addingTimeInterval(TimeInterval(minutes * 60))
        SharedStore.openApps = [application]
        SharedStore.updateRuntime { $0.recordOpen(at: now, until: end, calendar: .current) }
        try? ActivityScheduler.startOpenWindow(until: end)
        ShieldController.refresh(at: now)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, completionHandler: completionHandler)
    }

    private func handle(_ action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // An if chain rather than a switch, since newer SDKs import ShieldAction as a non-frozen type.
        if action == .primaryButtonPressed {
            SharedStore.updateRuntime { $0.recordClose(at: .now, calendar: .current) }
            ProgressRecorder.record(.closedBlockedApp)
            completionHandler(.close)
        } else if action == .secondaryButtonPressed {
            SharedStore.updateRuntime { $0.pauseRequestedAt = .now }
            postPauseNotification { completionHandler(.close) }
        } else {
            completionHandler(.close)
        }
    }

    private func postPauseNotification(completion: @escaping () -> Void) {
        let content = UNMutableNotificationContent()
        content.title = L("Pip väntar på dig")
        content.body = L("Tryck här för att andas en stund och ta en kort paus.")
        let request = UNNotificationRequest(identifier: "paus.pause-request", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in completion() }
    }
}
