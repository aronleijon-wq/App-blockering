import Foundation
import UserNotifications

/// Which notifications the user wants. Stored in the App Group, since the monitor extension sends some of them.
struct NotificationSettings: Codable, Equatable {
    /// The evening nudge to claim the daily reward and keep the streak.
    var dailyReminder = true
    /// Focus finished, a pause about to end, the daily limit used up.
    var focusAndPauses = true
    /// A schedule starting.
    var schedules = true
    /// Pip feeling worse after scrolling.
    var pipHealth = true
}

/// Every notification Paus sends, so wording and settings live in one place.
enum Notifier {
    enum ID {
        static let focusDone = "paus.focus-done"
        static let pauseEnding = "paus.pause-ending"
        static let pauseOver = "paus.pause-over"
        static let limitReached = "paus.limit"
        static let scheduleStarted = "paus.schedule-started"
        static let health = "paus.health"
        static let vacationOver = "paus.vacation-over"
        static let stepsDone = "paus.steps-done"
    }

    static var settings: NotificationSettings {
        get { SharedStore.notificationSettings }
        set { SharedStore.notificationSettings = newValue }
    }

    // MARK: Focus and pauses

    static func scheduleFocusDone(at end: Date, xp: Int) {
        guard settings.focusAndPauses else { return }
        schedule(ID.focusDone, at: end, title: L("Fokuspasset är klart! 🎉"), body: L("Snyggt jobbat. Öppna Paus och hämta dina \(xp) XP."))
    }

    static func schedulePauseEnd(at end: Date) {
        guard settings.focusAndPauses else { return }
        schedule(ID.pauseEnding, at: end.addingTimeInterval(-60), title: L("1 minut kvar av pausen ⏳"), body: L("Avsluta det du gör. Snart blockerar Pip apparna igen."))
        schedule(ID.pauseOver, at: end, title: L("Pausen är slut"), body: L("Apparna är blockerade igen. Bra att du höll tiden!"))
    }

    static func stepGoalReached(steps: Int) {
        post(ID.stepsDone, title: L("Du har gått \(Format.number(steps)) steg! 🎉"), body: L("Stegpasset är klart och apparna är upplåsta. Öppna Paus och hämta din XP."))
    }

    static func limitReached(minutes: Int) {
        guard settings.focusAndPauses else { return }
        post(ID.limitReached, title: L("Dagens tid är slut ⏰"), body: L("Du har använt dina \(Format.minutes(minutes)). Pip har låst apparna till midnatt."))
    }

    static func scheduleStarted(name: String, until end: Date) {
        guard settings.schedules else { return }
        post(ID.scheduleStarted, title: L("\(name) har börjat 🔒"), body: L("Pip blockerar apparna till \(Format.time(end))."))
    }

    static func scheduleVacationOver(at end: Date) {
        schedule(ID.vacationOver, at: end, title: L("Välkommen tillbaka! 👋"), body: L("Semesterläget är slut och dina regler gäller igen."))
    }

    // MARK: Pip

    static func healthDropped(to stage: PipHealth.Stage, health: Int, scrolledMinutes: Int?) {
        guard settings.pipHealth else { return }
        let title: String
        switch stage {
        case .wrecked: title = L("Pip är scrollsjuk 🤢")
        case .sick: title = L("Pip mår dåligt 😢")
        case .down: title = L("Pip blev lite ledsen 😕")
        case .okay, .great: return
        }
        let cause = scrolledMinutes.map { L("Du har scrollat \(Format.minutes($0)) i dag.") } ?? L("Du har slut på dagens tid.")
        post(ID.health, title: title, body: L("\(cause) Pips hälsa är nere på \(health) %. Ett fokuspass piggar upp Pip."))
    }

    // MARK: Plumbing

    static func cancel(_ ids: [String]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    static func post(_ id: String, title: String, body: String) {
        add(id, title: title, body: body, trigger: nil)
    }

    static func schedule(_ id: String, at date: Date, title: String, body: String) {
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }
        add(id, title: title, body: body, trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
    }

    private static func add(_ id: String, title: String, body: String, trigger: UNNotificationTrigger?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
