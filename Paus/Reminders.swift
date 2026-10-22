import Foundation
import StoreKit
import UserNotifications

/// A daily nudge to come back for the reward and keep the streak alive.
enum Reminders {
    private static let identifier = "paus.daily-reward"
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
        content.title = "Pip väntar på dig"
        content.body = streak > 1
            ? "Hämta dagens belöning och håll din streak på \(streak) dagar vid liv."
            : "Dagens belöning är redo. Starta en ny streak idag!"
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    /// Reminds the user before a free trial turns into a paid subscription, so it never comes as a surprise.
    static func scheduleTrialEnd(for transaction: Transaction, daysBefore: Int, now: Date = .now) {
        let calendar = Calendar.current
        guard isFreeTrial(transaction),
              let trialEnd = transaction.expirationDate,
              let fireDate = TrialReminder.date(trialEnd: trialEnd, daysBefore: daysBefore, now: now, calendar: calendar)
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(daysBefore) dagar kvar av din gratisvecka ⏳"
        content.body = "Paus Pro börjar kosta pengar \(trialEnd.formatted(.dateTime.day().month(.wide))). Vill du sluta, säg upp före dess under Inställningar > [ditt namn] > Prenumerationer."
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
