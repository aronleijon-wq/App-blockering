import SwiftUI

/// A player's Pip in their outfit, with their level, division and points this week. Opened from the leaderboard.
struct PlayerProfileSheet: View {
    let entry: LeaderboardEntry

    var body: some View {
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
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .screenBackground()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
