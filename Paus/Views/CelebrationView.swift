import SwiftUI

/// Full-screen celebration for XP, finished quests, new levels and achievements.
struct CelebrationView: View {
    @Environment(AppModel.self) private var model
    let rewards: [Reward]

    private var totalXP: Int {
        rewards.reduce(0) { total, reward in
            switch reward {
            case .xp(let amount): return total + amount
            case .quest(let id): return total + (Quest.with(id: id)?.xp ?? 0)
            default: return total
            }
        }
    }

    private var newLevel: Int? {
        rewards.compactMap { reward -> Int? in
            if case .levelUp(let level) = reward { return level }
            return nil
        }.max()
    }

    var body: some View {
        ZStack {
            Theme.backdrop.ignoresSafeArea()
            ConfettiView().ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                MascotView(mood: .proud, level: newLevel ?? model.progress.level, size: 180)

                if let newLevel {
                    Text("Nivå \(newLevel)!")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.brand)
                    Text("Du är nu \(Level.title(for: newLevel)).")
                        .font(.title3.weight(.semibold))
                } else if totalXP > 0 {
                    Text("+\(totalXP) XP")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.brand)
                        .contentTransition(.numericText())
                } else {
                    Text("Snyggt!")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.brand)
                }

                VStack(spacing: 10) {
                    ForEach(Array(rewards.enumerated()), id: \.offset) { _, reward in
                        if let row = row(for: reward) {
                            HStack(spacing: 12) {
                                Image(systemName: row.symbol)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Theme.glow, in: Circle())
                                Text(row.text)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }
                            .padding(12)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
                Button("Grymt!") { model.dismissCelebration() }
                    .buttonStyle(GlowButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
        }
        .sensoryFeedback(.success, trigger: rewards)
    }

    private func row(for reward: Reward) -> (symbol: String, text: String)? {
        switch reward {
        case .xp:
            return nil
        case .levelUp(let level):
            return ("arrow.up.circle.fill", "Ny nivå: \(Level.title(for: level))")
        case .achievement(let id):
            guard let achievement = Achievement.with(id: id) else { return nil }
            return (achievement.symbol, "Trofé: \(achievement.title)")
        case .quest(let id):
            guard let quest = Quest.with(id: id) else { return nil }
            return ("checkmark", "Uppdrag klart: \(quest.title) (+\(quest.xp) XP)")
        }
    }
}
