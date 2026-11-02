import SwiftUI

/// A player's Pip in their outfit, with their level, division and points this week. Opened from the leaderboard.
struct PlayerProfileSheet: View {
    let entry: LeaderboardEntry

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    /// Every trophy, the unlocked ones first, so the player's collection reads at a glance.
    private var achievements: [Achievement] {
        let all = Achievement.all
        return all.filter { entry.trophies.contains($0.id) } + all.filter { !entry.trophies.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MascotView(mood: .happy, level: entry.level, size: 160, outfit: entry.outfit)
                    .frame(height: 220)
                    .padding(.top, 30)
                Text(entry.isMe ? L("\(entry.nickname) (du)") : entry.nickname)
                    .font(.title2.bold())
                    .lineLimit(1)
                HStack(spacing: 10) {
                    stat(L("Nivå"), "\(entry.level)")
                    stat(L("Division"), entry.division.title)
                    stat(L("Poäng i veckan"), "\(entry.points)")
                }
                trophies
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .screenBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var trophies: some View {
        let unlocked = Achievement.all.filter { entry.trophies.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("Troféer"))
                    .font(.title3.bold())
                Spacer()
                Text("\(unlocked)/\(Achievement.all.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.brand)
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(achievements) { achievement in
                    AchievementBadge(achievement: achievement, isUnlocked: entry.trophies.contains(achievement.id))
                }
            }
        }
        .padding(.top, 8)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
