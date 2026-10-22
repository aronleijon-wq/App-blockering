import Foundation
import UserNotifications

/// Tells the user when Pip starts feeling worse, so the scrolling has a face even outside the app.
enum PipNotifier {
    static func healthDropped(to stage: PipHealth.Stage, health: Int, scrolledMinutes: Int?) {
        let content = UNMutableNotificationContent()
        switch stage {
        case .wrecked:
            content.title = "Pip är scrollsjuk 🤢"
        case .sick:
            content.title = "Pip mår dåligt 😢"
        case .down:
            content.title = "Pip blev lite ledsen 😕"
        case .okay, .great:
            return
        }
        let cause = scrolledMinutes.map { "Du har scrollat \(Format.minutes($0)) i dag." } ?? "Du har slut på dagens tid."
        content.body = "\(cause) Pips hälsa är nere på \(health) %. Ett fokuspass piggar upp Pip."
        let request = UNNotificationRequest(identifier: "paus.health", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
