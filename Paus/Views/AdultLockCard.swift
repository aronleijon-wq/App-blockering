import SwiftUI

/// The November challenge on the home screen: an invitation to lock the adult filter for the rest of November,
/// and, while any lock runs, how far along it is.
struct AdultLockCard: View {
    @Environment(AppModel.self) private var model
    let date: Date
    /// The month the invitation was waved away in, so it stays away for the rest of that month.
    @AppStorage("adultLock.dismissedMonth") private var dismissedMonth = ""
    @State private var isConfirming = false

    private var calendar: Calendar { .current }

    private var monthKey: String {
        "\(calendar.component(.year, from: date))-\(calendar.component(.month, from: date))"
    }

    var body: some View {
        if let end = model.rules.adultFilterLockedUntil, end > date {
            progressCard(until: end)
        } else if AdultLock.offersChallenge(at: date, calendar: calendar) && AdultLock.offersChallenge(to: model.introAnswers?.ageGroup)
                    && dismissedMonth != monthKey {
            invitation
        }
    }

    // MARK: Running

    private func progressCard(until end: Date) -> some View {
        let left = AdultLock.daysLeft(until: end, from: date, calendar: calendar)
        let start: Date? = model.rules.adultFilterLockedAt
        let total: Int = start.map { AdultLock.daysLeft(until: end, from: $0, calendar: calendar) } ?? left
        let day: Int = min(max(1, total - left + 1), max(1, total))
        let isChallenge: Bool = start.map { AdultLock.isChallenge(from: $0, to: end, calendar: calendar) } ?? false
        let fraction = Double(day) / Double(max(1, total))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: isChallenge ? "trophy.fill" : "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.brand)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isChallenge ? L("NNN-utmaningen") : L("Vuxenfiltret är låst"))
                        .font(.headline)
                    Text(L("Dag \(day) av \(total)"))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("\(left)")
                        .font(.title.bold().monospacedDigit())
                    Text(left == 1 ? L("dag kvar") : L("dagar kvar"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            GradientBar(fraction: fraction, height: 8)
            Text(cheer(day: day, total: total, left: left))
                .font(.subheadline)
            if total >= AdultLock.minRewardDays {
                Label(rewardText(days: total, trophy: isChallenge), systemImage: "gift.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.mint)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private func cheer(day: Int, total: Int, left: Int) -> String {
        if left <= 1 { return L("Sista dagen. Du är nästan i mål!") }
        if left <= 7 { return L("Sista veckan. Du fixar det här.") }
        if day * 2 >= total && (day - 1) * 2 < total { return L("Halvvägs! Pip är så stolt över dig.") }
        let lines = [
            L("En dag i taget. Pip tror på dig."),
            L("Suget går över. Stoltheten stannar."),
            L("Du är starkare än en impuls."),
            L("Varje dag du klarar gör nästa lättare."),
        ]
        return lines[day % lines.count]
    }

    private func rewardText(days: Int, trophy: Bool) -> String {
        let xp = AdultLock.rewardXP(days: days)
        let seeds = AdultLock.rewardSeeds(days: days)
        return trophy
            ? L("Klarar du hela vägen: en trofé, +\(xp) XP och \(seeds) frön")
            : L("Klarar du hela vägen: +\(xp) XP och \(seeds) frön")
    }

    // MARK: Invitation

    private var invitation: some View {
        let end = AdultLock.endOfMonth(after: date, calendar: calendar)
        let days = AdultLock.daysLeft(until: end, from: date, calendar: calendar)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                PipAvatar(outfit: model.progress.outfit, level: model.progress.level, size: 44)
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("NNN-utmaningen"))
                        .font(.title3.bold())
                    Text(L("Lås vuxenfiltret resten av november. \(days) dagar, inga undantag. Klarar du det?"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Label(rewardText(days: days, trophy: true), systemImage: "trophy.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.mint)
            Button(L("Anta utmaningen")) { isConfirming = true }
                .buttonStyle(GlowButtonStyle())
            Button(L("Inte nu")) { dismissedMonth = monthKey }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .card(highlighted: true)
        .confirmationDialog(L("Lås vuxenfiltret resten av november?"), isPresented: $isConfirming, titleVisibility: .visible) {
            Button(L("Lås")) { model.lockAdultFilter(until: end) }
            Button(L("Avbryt"), role: .cancel) {}
        } message: {
            Text(L("Fram till dess går vuxenfiltret inte att stänga av, inte ens för dig."))
        }
    }
}
