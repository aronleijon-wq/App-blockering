import SwiftUI

struct TrophiesView: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let progress = model.progress
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        statsCard(progress)
                        levelsCard(progress)
                        achievementsCard(progress)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .task {
                    // Start at the player's place on the journey, like opening a board game where you left off.
                    try? await Task.sleep(for: .seconds(0.3))
                    withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo("journey-current", anchor: .center) }
                }
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
        let friends = model.league.entries[LeagueService.Board(scope: .friends, period: .week)] ?? []
        return LevelPath(progress: progress, friends: friends.filter { !$0.isMe })
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

/// Paus's levels as a journey, like a board game: four lands with a banner each, the levels as round buttons along a
/// winding path, a chest after every level, Pip standing at the player's level (and walking there after a level-up),
/// friends standing at theirs, and "You are here" above the current level. Tapping a level tells what it takes.
private struct LevelPath: View {
    @Environment(AppModel.self) private var model
    let progress: PlayerProgress
    /// League friends, shown at their levels.
    var friends: [LeaderboardEntry] = []
    @State private var picked: LevelPick?
    @State private var bounce = false
    /// Where Pip stands. Starts at the level last seen, then walks to the current one.
    @State private var pipLevel: Int?
    @State private var opened: (level: Int, seeds: Int)?
    @AppStorage("journey.seenLevel") private var seenLevel = 0
    @Namespace private var path

    private var lastLevel: Int {
        max(Level.titles.count, progress.level + 2, friends.map(\.level).max() ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Din resa"))
                .font(.title3.bold())
            Text(L("Tryck på en nivå för att se vad som väntar. Öppna kistorna på vägen."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(Journey.lands, id: \.index) { land in
                if land.firstLevel <= lastLevel {
                    landSection(land)
                }
            }
        }
        .card()
        .onAppear(perform: walk)
        .sheet(item: $picked) { pick in
            LevelDetailSheet(level: pick.level, progress: progress)
        }
        .sensoryFeedback(.success, trigger: pipLevel)
    }

    /// After a level-up, Pip walks from the level last seen to the new one.
    private func walk() {
        bounce = true
        let current = progress.level
        guard seenLevel > 0, seenLevel < current else {
            pipLevel = current
            seenLevel = current
            return
        }
        pipLevel = seenLevel
        seenLevel = current
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            withAnimation(.spring(response: 0.9, dampingFraction: 0.7)) { pipLevel = current }
        }
    }

    static func colors(for land: Journey.Land) -> [Color] {
        switch land.index {
        case 1: return [Color(red: 0.2, green: 0.7, blue: 0.4), Color(red: 0.08, green: 0.45, blue: 0.3)]
        case 2: return [Color(red: 0.2, green: 0.55, blue: 1), Color(red: 0.1, green: 0.3, blue: 0.75)]
        case 3: return [Color(red: 0.55, green: 0.45, blue: 0.85), Color(red: 0.3, green: 0.22, blue: 0.55)]
        default: return [Color(red: 1, green: 0.75, blue: 0.3), Theme.pink]
        }
    }

    private func landSection(_ land: Journey.Land) -> some View {
        let last = min(land.lastLevel ?? lastLevel, lastLevel)
        let levels = Array(land.firstLevel...max(land.firstLevel, last))
        let colors = Self.colors(for: land)
        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: land.symbol)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.2), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("DEL \(land.index)"))
                        .font(.caption.weight(.heavy))
                        .opacity(0.8)
                    Text(land.name)
                        .font(.title3.bold())
                    Text(land.tagline)
                        .font(.subheadline)
                        .opacity(0.9)
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            ForEach(levels, id: \.self) { level in
                node(level, tint: colors[0])
                    .offset(x: Self.offset(level))
                    .id(level == progress.level ? "journey-current" : "journey-\(level)")
                dots(from: level)
                chest(after: level)
                    .offset(x: (Self.offset(level) + Self.offset(level + 1)) / 2)
                dots(from: level)
            }
        }
        .padding(.top, 6)
    }

    static func offset(_ level: Int) -> CGFloat {
        CGFloat(sin(Double(level) * 0.95)) * 72
    }

    /// Three dots leading on along the path.
    private func dots(from level: Int) -> some View {
        let reached = progress.level > level
        return VStack(spacing: 5) {
            ForEach(0..<2, id: \.self) { _ in
                Circle()
                    .fill(reached ? Theme.mint.opacity(0.7) : Color.white.opacity(0.15))
                    .frame(width: 7, height: 7)
            }
        }
        .offset(x: (Self.offset(level) * 3 + Self.offset(level + 1)) / 4)
    }

    private func node(_ level: Int, tint: Color) -> some View {
        let reached = progress.level >= level
        let current = progress.level == level
        let size: CGFloat = current ? 82 : 66
        let symbol = current ? "star.fill" : reached ? "checkmark" : level > Level.titles.count ? "crown.fill" : "lock.fill"
        let here = friends.filter { $0.level == level }
        return Button {
            picked = LevelPick(level: level)
        } label: {
            VStack(spacing: 6) {
                if current {
                    Text(L("DU ÄR HÄR"))
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white, in: Capsule())
                        .foregroundStyle(tint)
                        .offset(y: bounce ? -4 : 0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: bounce)
                }
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .offset(y: 6)
                    Circle()
                        .fill(reached ? AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                                      : AnyShapeStyle(Theme.cardRaised))
                    if current {
                        Circle()
                            .stroke(.white.opacity(0.8), lineWidth: 4)
                            .padding(-6)
                    }
                    Image(systemName: symbol)
                        .font(.system(size: current ? 30 : 22, weight: .heavy))
                        .foregroundStyle(reached ? Color.white : Color.secondary)
                }
                .frame(width: size, height: size)
                .scaleEffect(current && bounce ? 1.08 : 1)
                .animation(current ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : nil, value: bounce)
                Text(Level.title(for: level))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(reached ? Color.white : Color.secondary)
            }
        }
        .buttonStyle(PressScaleStyle())
        .overlay(alignment: Self.offset(level) > 0 ? .leading : .trailing) {
            HStack(spacing: -10) {
                if pipLevel == level {
                    PipAvatar(outfit: progress.outfit, level: progress.level, size: 46)
                        .frame(width: 52, height: 52)
                        .matchedGeometryEffect(id: "pip", in: path)
                }
                ForEach(here.prefix(2)) { friend in
                    VStack(spacing: 0) {
                        PipAvatar(outfit: friend.outfit, level: friend.level, size: 30)
                            .frame(width: 36, height: 36)
                        Text(friend.nickname)
                            .font(.system(size: 9, weight: .bold))
                            .lineLimit(1)
                            .frame(maxWidth: 52)
                    }
                }
            }
            .offset(x: Self.offset(level) > 0 ? -70 : 70, y: -8)
        }
    }

    /// A chest after `level`: locked until the next level, then shaking to be opened, then open.
    private func chest(after level: Int) -> some View {
        let canOpen = progress.canOpenChest(after: level)
        let isOpen = progress.openedChests.contains(level)
        let justOpened = opened?.level == level
        return Button {
            guard canOpen, let found = model.openChest(after: level) else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { opened = (level, found) }
        } label: {
            ZStack {
                Image(systemName: isOpen ? "gift" : "gift.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(canOpen ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.35), Theme.orange],
                                                                            startPoint: .top, endPoint: .bottom))
                                     : AnyShapeStyle(isOpen ? Color.secondary.opacity(0.6) : Color.secondary.opacity(0.35)))
                    .frame(width: 54, height: 54)
                    .background(canOpen ? Theme.orange.opacity(0.18) : Color.clear, in: Circle())
                    .rotationEffect(.degrees(canOpen && bounce ? 8 : 0))
                    .animation(canOpen ? .easeInOut(duration: 0.18).repeatForever(autoreverses: true) : nil, value: bounce)
                    .scaleEffect(justOpened ? 1.25 : 1)
                if justOpened, let seeds = opened?.seeds {
                    Label("+\(seeds)", systemImage: "leaf.fill")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Theme.mint)
                        .offset(y: -44)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!canOpen)
        .sensoryFeedback(.success, trigger: justOpened)
        .accessibilityLabel(canOpen ? L("Öppna kistan") : isOpen ? L("Öppnad kista") : L("Låst kista"))
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
