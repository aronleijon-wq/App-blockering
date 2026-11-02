import SwiftUI

struct TrophiesView: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let progress = model.progress
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statsCard(progress)
                    levelsCard(progress)
                    achievementsCard(progress)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle(L("Troféer"))
        }
    }

    private func statsCard(_ progress: PlayerProgress) -> some View {
        HStack(spacing: 0) {
            Stat(value: "\(progress.bestStreak)", label: L("Bästa streak"), symbol: "flame.fill", tint: Theme.flame)
            Stat(value: Format.minutes(progress.focusMinutes), label: L("Fokus totalt"), symbol: "scope", tint: Theme.violet)
            Stat(value: "\(progress.closes)", label: L("Stängda appar"), symbol: "hand.raised.fill", tint: Theme.pink)
        }
        .card()
    }

    private func levelsCard(_ progress: PlayerProgress) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("Nivåer"))
                .font(.title3.bold())
            Text(L("Pip får nya prylar på nivå 3, 6 och 8."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(1...Level.titles.count, id: \.self) { level in
                let reached = progress.level >= level
                HStack(spacing: 14) {
                    Text("\(level)")
                        .font(.headline.monospacedDigit())
                        .frame(width: 36, height: 36)
                        .background(reached ? AnyShapeStyle(Theme.glow) : AnyShapeStyle(Theme.cardRaised), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Level.title(for: level))
                            .font(.subheadline.weight(.semibold))
                        Text("\(Level.xpRequired(for: level)) XP")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if level == progress.level {
                        Text(L("DU"))
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.mint.opacity(0.2), in: Capsule())
                            .foregroundStyle(Theme.mint)
                    } else if !reached {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(L("Låst"))
                    }
                }
                .opacity(reached ? 1 : 0.55)
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: 14) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Theme.orange)
                    .frame(width: 36, height: 36)
                    .background(Theme.cardRaised, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(progress.level >= Level.titles.count
                         ? L("Nästa: \(Level.title(for: progress.level + 1)) vid \(Level.xpRequired(for: progress.level + 1)) XP")
                         : L("Efter Legend: Legend II, III, IV …"))
                        .font(.subheadline.weight(.semibold))
                    Text(L("Varje varv efter Legend ger Pip en stjärna i ligan."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }

    private func achievementsCard(_ progress: PlayerProgress) -> some View {
        TrophyShelf(unlocked: progress.unlocked, current: Season.at(.now, calendar: .current))
            .card()
    }
}

/// The trophies: one badge per family, showing its best medal and the next to reach, then the season trophies.
struct TrophyShelf: View {
    let unlocked: Set<String>
    /// The running season, shown locked until it's won.
    var current: Season?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var seasons: [Season] {
        var keys = unlocked.compactMap { Season.containing(trophyID: $0)?.key }
        if let current, !keys.contains(current.key) { keys.append(current.key) }
        return keys.sorted(by: >).map(Season.with(key:))
    }

    var body: some View {
        let total = Achievement.all.count
        let earned = Achievement.all.filter { unlocked.contains($0.id) }.count
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("Troféer"))
                    .font(.title3.bold())
                Spacer()
                Text("\(earned)/\(total)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.brand)
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Achievement.shelf, id: \.first?.id) { group in
                    let shown = Achievement.shown(in: group, unlocked: unlocked)
                    AchievementBadge(achievement: shown.achievement, isUnlocked: shown.isUnlocked, next: shown.next)
                }
            }
            if !seasons.isEmpty {
                Text(L("Säsonger"))
                    .font(.headline)
                    .padding(.top, 6)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(seasons, id: \.key) { season in
                        AchievementBadge(achievement: season.trophy, isUnlocked: unlocked.contains(season.trophyID))
                    }
                }
            }
        }
    }
}

private struct Stat: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.headline.monospacedDigit())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct AchievementBadge: View {
    let achievement: Achievement
    let isUnlocked: Bool
    /// The next medal in the family, if there is one.
    var next: Achievement?

    static func color(for tier: Achievement.Tier) -> Color {
        switch tier {
        case .bronze: return Color(red: 0.85, green: 0.55, blue: 0.3)
        case .silver: return Color(red: 0.82, green: 0.84, blue: 0.9)
        case .gold: return Color(red: 1, green: 0.82, blue: 0.3)
        case .diamond: return Color(red: 0.55, green: 0.9, blue: 1)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Theme.cardRaised))
                    .shadow(color: isUnlocked ? Theme.pink.opacity(0.4) : .clear, radius: 10)
                Image(systemName: isUnlocked ? achievement.symbol : "lock.fill")
                    .font(.title2)
                    .foregroundStyle(isUnlocked ? Color.white : Color.secondary)
            }
            .frame(width: 64, height: 64)
            .overlay {
                if isUnlocked, let tier = achievement.tier {
                    Circle()
                        .strokeBorder(Self.color(for: tier), lineWidth: 4)
                }
            }
            .overlay(alignment: .bottom) {
                if isUnlocked, let tier = achievement.tier {
                    Text(tier.name.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Self.color(for: tier), in: Capsule())
                        .foregroundStyle(Color.black.opacity(0.75))
                        .offset(y: 6)
                }
            }
            Text(achievement.title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(next.map { L("Nästa: \($0.detail.lowercased())") } ?? achievement.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isUnlocked ? L("Upplåst") : L("Låst"))
    }
}
