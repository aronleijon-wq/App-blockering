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
        LevelPath(progress: progress)
    }

    private func achievementsCard(_ progress: PlayerProgress) -> some View {
        TrophyShelf(unlocked: progress.unlocked, current: Season.at(.now, calendar: .current), progress: progress)
            .card()
    }
}

/// The trophies: one badge per family, showing its best medal and the next to reach, then the season trophies.
struct TrophyShelf: View {
    let unlocked: Set<String>
    /// The running season, shown locked until it's won.
    var current: Season?
    /// The player's own progress, for the progress bars in the details. Nil on someone else's profile.
    var progress: PlayerProgress?
    @State private var picked: TrophyPick?
    @State private var appeared = false

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
                ForEach(Array(Achievement.shelf.enumerated()), id: \.element.first?.id) { index, group in
                    let shown = Achievement.shown(in: group, unlocked: unlocked)
                    Button {
                        picked = TrophyPick(group: group)
                    } label: {
                        AchievementBadge(achievement: shown.achievement, isUnlocked: shown.isUnlocked, next: shown.next)
                    }
                    .buttonStyle(PressScaleStyle())
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(Double(index) * 0.04), value: appeared)
                }
            }
            if !seasons.isEmpty {
                Text(L("Säsonger"))
                    .font(.headline)
                    .padding(.top, 6)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(seasons, id: \.key) { season in
                        Button {
                            picked = TrophyPick(group: [season.trophy])
                        } label: {
                            AchievementBadge(achievement: season.trophy, isUnlocked: unlocked.contains(season.trophyID))
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
            }
        }
        .onAppear { appeared = true }
        .sheet(item: $picked) { pick in
            TrophyDetailSheet(group: pick.group, unlocked: unlocked, progress: progress)
        }
    }
}

private struct TrophyPick: Identifiable {
    let group: [Achievement]
    var id: String { group.first?.id ?? "" }
}

/// Shrinks a little while pressed, so the badges feel like buttons.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// One trophy, or a family of medals: the best one won, the ladder from bronze to diamond and how close the next is.
private struct TrophyDetailSheet: View {
    let group: [Achievement]
    let unlocked: Set<String>
    let progress: PlayerProgress?
    @State private var appeared = false

    var body: some View {
        let shown = Achievement.shown(in: group, unlocked: unlocked)
        let aim = shown.next ?? (shown.isUnlocked ? nil : shown.achievement)
        VStack(spacing: 16) {
            AchievementBadge(achievement: shown.achievement, isUnlocked: shown.isUnlocked, size: 120, showsText: false)
                .scaleEffect(appeared ? 1 : 0.3)
                .rotationEffect(.degrees(appeared ? 0 : -25))
                .padding(.top, 28)
            Text(shown.achievement.title)
                .font(.title2.bold())
            if group.count > 1 {
                ladder
            }
            if let aim {
                Text(aim.detail)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if let progress, let count = aim.count(in: progress) {
                    VStack(spacing: 6) {
                        GradientBar(fraction: min(1, Double(count.current) / Double(max(1, count.goal))), height: 12)
                        Text("\(Format.number(min(count.current, count.goal))) / \(Format.number(count.goal))")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 30)
                }
            } else {
                Label(L("Alla medaljer tagna!"), systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.mint)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .screenBackground()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) { appeared = true }
        }
        .sensoryFeedback(.success, trigger: appeared)
    }

    /// Bronze to diamond, each lit once won.
    private var ladder: some View {
        HStack(spacing: 14) {
            ForEach(group) { medal in
                let won = unlocked.contains(medal.id)
                let color = medal.tier.map(AchievementBadge.color(for:)) ?? Theme.violet
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(won ? AnyShapeStyle(color) : AnyShapeStyle(Theme.cardRaised))
                        Image(systemName: won ? "checkmark" : "lock.fill")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(won ? Color.black.opacity(0.7) : Color.secondary)
                    }
                    .frame(width: 36, height: 36)
                    Text(medal.tier?.name ?? "")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(won ? color : .secondary)
                }
            }
        }
    }
}

/// Paus's levels as a winding path, like a board game: done levels lit, the current one bouncing with Pip beside it,
/// the next ones locked. Tapping a level tells what it takes and what it gives.
private struct LevelPath: View {
    let progress: PlayerProgress
    @State private var picked: LevelPick?
    @State private var bounce = false

    private var levels: [Int] { Array(1...max(Level.titles.count, progress.level + 2)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Din resa"))
                .font(.title3.bold())
            Text(L("Tryck på en nivå för att se vad som väntar."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(spacing: 22) {
                ForEach(levels, id: \.self) { level in
                    node(level)
                        .offset(x: Self.offset(level))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .card()
        .onAppear { bounce = true }
        .sheet(item: $picked) { pick in
            LevelDetailSheet(level: pick.level, progress: progress)
        }
    }

    static func offset(_ level: Int) -> CGFloat {
        CGFloat(sin(Double(level) * 0.95)) * 72
    }

    private func node(_ level: Int) -> some View {
        let reached = progress.level >= level
        let current = progress.level == level
        let size: CGFloat = current ? 80 : 64
        let symbol = current ? "star.fill" : reached ? "checkmark" : level > Level.titles.count ? "crown.fill" : "lock.fill"
        return Button {
            picked = LevelPick(level: level)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .offset(y: 6)
                    Circle()
                        .fill(reached ? AnyShapeStyle(Theme.glow) : AnyShapeStyle(Theme.cardRaised))
                    Image(systemName: symbol)
                        .font(.system(size: current ? 30 : 22, weight: .heavy))
                        .foregroundStyle(reached ? Color.white : Color.secondary)
                }
                .frame(width: size, height: size)
                .scaleEffect(current && bounce ? 1.1 : 1)
                .animation(current ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : nil, value: bounce)
                Text(Level.title(for: level))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(reached ? Color.white : Color.secondary)
            }
        }
        .buttonStyle(PressScaleStyle())
        .overlay(alignment: Self.offset(level) > 0 ? .leading : .trailing) {
            if current {
                PipAvatar(outfit: progress.outfit, level: progress.level, size: 46)
                    .frame(width: 52, height: 52)
                    .offset(x: Self.offset(level) > 0 ? -64 : 64, y: -12)
            }
        }
    }
}

private struct LevelPick: Identifiable {
    let level: Int
    var id: Int { level }
}

/// One level: its title, the XP it takes, how far away it is and what it gives.
private struct LevelDetailSheet: View {
    let level: Int
    let progress: PlayerProgress

    var body: some View {
        let start = Level.xpRequired(for: level)
        let left = max(0, start - progress.xp)
        VStack(spacing: 14) {
            Text("\(level)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .frame(width: 96, height: 96)
                .background(progress.level >= level ? AnyShapeStyle(Theme.glow) : AnyShapeStyle(Theme.cardRaised), in: Circle())
                .padding(.top, 28)
            Text(Level.title(for: level))
                .font(.title2.bold())
            Text("\(Format.number(start)) XP")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
            if progress.level == level {
                VStack(spacing: 6) {
                    GradientBar(fraction: Level.fraction(forXP: progress.xp), height: 12)
                    Text(L("\(Format.number(Level.xpRequired(for: level + 1) - progress.xp)) XP till nästa nivå"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 30)
            } else if progress.level > level {
                Label(L("Klar"), systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.mint)
            } else {
                Text(L("\(Format.number(left)) XP kvar dit"))
                    .font(.headline)
            }
            if level > Level.titles.count {
                Label(L("Ger Pip en stjärna i ligan"), systemImage: "star.fill")
                    .foregroundStyle(Theme.orange)
            } else if [3, 5, 8].contains(level) {
                Label(L("Pip får nya färger på den här nivån"), systemImage: "sparkles")
                    .foregroundStyle(Theme.orange)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .screenBackground()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
    var size: CGFloat = 64
    var showsText = true

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
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(isUnlocked ? Color.white : Color.secondary)
            }
            .frame(width: size, height: size)
            .overlay {
                if isUnlocked, let tier = achievement.tier {
                    Circle()
                        .strokeBorder(Self.color(for: tier), lineWidth: size * 0.065)
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
            if showsText {
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
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isUnlocked ? L("Upplåst") : L("Låst"))
    }
}
