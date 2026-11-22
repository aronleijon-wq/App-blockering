import Foundation
import StoreKit
import UserNotifications

/// A daily nudge to come back for the reward and keep the streak alive.
enum Reminders {
    static let identifier = "paus.daily-reward"
    private static let hour = 18
    private static let minute = 30

    /// Schedules the next reminder: today if the reward is still waiting, otherwise tomorrow.
    static func scheduleNext(rewardClaimedToday: Bool, streak: Int, now: Date = .now) {
        let calendar = Calendar.current
        let center = UNUserNotificationCenter.current()
        guard
            let todayAtTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now),
            let tomorrowAtTime = calendar.date(byAdding: .day, value: 1, to: todayAtTime)
        else { return }
        let fireDate = !rewardClaimedToday && todayAtTime > now ? todayAtTime : tomorrowAtTime

        let content = UNMutableNotificationContent()
        content.title = L("Pip väntar på dig")
        content.body = streak > 1
            ? L("Hämta dagens belöning och håll din streak på \(streak) dagar vid liv.")
            : L("Dagens belöning är redo. Starta en ny streak idag!")
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static let streakRiskIdentifier = "paus.streak-risk"
    static let weeklyLetterIdentifier = "paus.weekly-letter"

    /// Pip's letter about the week, on Sunday evening, with the week so far. Rescheduled every time Paus opens, so
    /// it's as fresh as the last visit.
    static func scheduleWeeklyLetter(_ letter: WeeklyLetter, now: Date = .now) {
        let calendar = Calendar.current
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyLetterIdentifier])
        var sunday = DateComponents()
        sunday.weekday = 1
        sunday.hour = 19
        guard let fireDate = calendar.nextDate(after: now, matching: sunday, matchingPolicy: .nextTime) else { return }
        let content = UNMutableNotificationContent()
        content.title = letter.title
        content.body = letter.body
        content.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: weeklyLetterIdentifier, content: content, trigger: trigger))
    }

    /// Late in the evening, a last call for a streak of two days or more that nothing has kept alive today.
    static func scheduleStreakRisk(activeToday: Bool, streak: Int, freezes: Int, now: Date = .now) {
        let calendar = Calendar.current
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [streakRiskIdentifier])
        guard !activeToday, streak >= 2,
              let fireDate = calendar.date(bySettingHour: 21, minute: 30, second: 0, of: now), fireDate > now else { return }
        let content = UNMutableNotificationContent()
        content.title = L("Din streak dör vid midnatt 🔥")
        content.body = freezes > 0
            ? L("\(streak) dagar i rad. En streakfrys räddar den, men den räcker inte för alltid. Öppna Paus nu.")
            : L("\(streak) dagar i rad står på spel. Hämta dagens belöning, det tar fem sekunder.")
        content.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: streakRiskIdentifier, content: content, trigger: trigger))
    }

    /// Days after the last visit that Pip writes again. The daily reminder covers the first day,
    /// and the series ends after a month so it never turns into spam.
    static let winBackDays = [2, 3, 7, 14, 30]
    static var winBackIdentifiers: [String] { winBackDays.map { "paus.win-back-\($0)" } }

    /// Pip missing the user, sadder the longer they stay away. Rescheduled from scratch every time Paus
    /// opens, so a visit puts the series back to the start.
    static func scheduleWinBack(streak: Int, now: Date = .now) {
        let calendar = Calendar.current
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: winBackIdentifiers)
        let today = calendar.startOfDay(for: now)
        for day in winBackDays {
            guard
                let date = calendar.date(byAdding: .day, value: day, to: today),
                let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)
            else { continue }
            let (title, body) = winBackMessage(day: day, streak: streak)
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: "paus.win-back-\(day)", content: content, trigger: trigger))
        }
    }

    private static func winBackMessage(day: Int, streak: Int) -> (String, String) {
        switch day {
        case 2:
            return streak > 1
                ? (L("Din streak hänger på en tråd 🔥"), L("\(streak) dagar i rad står på spel. Öppna Paus i dag, så håller Pip den vid liv."))
                : (L("Pip undrar var du är 👀"), L("Ett kort fokuspass, så blir Pip glad igen."))
        case 3:
            return (L("Pip saknar dig 🥺"), L("Det har gått tre dagar. Kom tillbaka, det väntar en välkomstpresent på dig."))
        case 7:
            return (L("Det har gått en vecka…"), L("Pip har börjat prata med väggarna. Öppna Paus för din välkomstpresent."))
        case 14:
            return (L("Pip har inte gett upp på dig 💜"), L("Två veckor utan dig. En välkomstpresent väntar när du kommer tillbaka."))
        default:
            return (L("Sista gången Pip hör av sig"), L("Pip väntar här om du vill ta tillbaka din tid. Annars lämnar Pip dig i fred."))
        }
    }

    /// Reminds the user before a free trial turns into a paid subscription, so it never comes as a surprise.
    static func scheduleTrialEnd(for transaction: Transaction, daysBefore: Int, now: Date = .now) {
        let calendar = Calendar.current
        guard isFreeTrial(transaction),
              let trialEnd = transaction.expirationDate,
              let fireDate = TrialReminder.date(trialEnd: trialEnd, daysBefore: daysBefore, now: now, calendar: calendar)
        else { return }

        let content = UNMutableNotificationContent()
        content.title = L("\(daysBefore) dagar kvar av din gratisvecka ⏳")
        content.body = L("Paus Pro börjar kosta pengar \(trialEnd.formatted(.dateTime.day().month(.wide).locale(Language.current.locale))). Vill du sluta, säg upp före dess under Inställningar > [ditt namn] > Prenumerationer.")
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "paus.trial-end", content: content, trigger: trigger))
    }

    private static func isFreeTrial(_ transaction: Transaction) -> Bool {
        if #available(iOS 17.2, *) {
            return transaction.offer?.type == .introductory
        }
        return transaction.offerType == .introductory
    }
}
