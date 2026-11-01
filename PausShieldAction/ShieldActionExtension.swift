import Foundation
import ManagedSettings
import UserNotifications

/// Handles the shield's buttons. "Stäng" closes the blocked app; "Ta en paus" can't open Paus directly,
/// so it posts a notification that does, and Paus shows the pause screen when it opens.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, completionHandler: completionHandler)
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
