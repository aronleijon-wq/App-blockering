import SwiftUI

/// The player's profile, like a game's: Pip big on a bright backdrop with the wardrobe and settings at hand, who the
/// player is, friends, the month's event, an overview of the stats, the month badges, the trophies and the journey.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var isWardrobePresented = false
    @State private var isSettingsPresented = false
    @State private var isAddFriendPresented = false
    @State private var isNicknamePresented = false

    private let tiles = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let progress = model.progress
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header(progress)
                    Group {
                        identity(progress)
                        eventBanner
                        overview(progress)
                        monthBadges(progress)
                        TrophyShelf(unlocked: progress.unlocked, current: Season.at(.now, calendar: .current), progress: progress)
                            .card()
                        LevelPath(progress: progress, friends: friendsOnJourney)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 28)
            }
            .ignoresSafeArea(edges: .top)
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isWardrobePresented) { WardrobeView() }
            .sheet(isPresented: $isSettingsPresented) { SettingsView() }
            .sheet(isPresented: $isNicknamePresented) { NicknameSheet() }
            .sheet(isPresented: $isAddFriendPresented) {
                AddFriendSheet {
                    await model.syncLeague(force: true)
                    await model.league.load(.friends, period: .week, progress: model.progress)
                }
            }
        }
    }

    private var friendsOnJourney: [LeaderboardEntry] {
        (model.league.entries[LeagueService.Board(scope: .friends, period: .week)] ?? []).filter { !$0.isMe }
    }

    // MARK: Header

    private func header(_ progress: PlayerProgress) -> some View {
        let colors = MascotView.bodyColors(level: progress.level, outfit: progress.outfit)
        return ZStack(alignment: .top) {
            LinearGradient(colors: colors.map { $0.opacity(0.55) } + [Theme.background], startPoint: .top, endPoint: .bottom)
            // Soft rings behind Pip, like a spotlight.
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 18)
                    .frame(width: CGFloat(180 + ring * 90))
                    .offset(y: 150)
            }
            VStack(spacing: 6) {
                HStack(spacing: 18) {
                    Spacer()
                    Button { isWardrobePresented = true } label: {
                        Image(systemName: "hanger")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    .accessibilityLabel(L("Pips garderob"))
                    Button { isSettingsPresented = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    .accessibilityLabel(L("Inställningar"))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                Button { isWardrobePresented = true } label: {
                    MascotView(mood: model.mood, level: progress.level, size: 170, outfit: progress.outfit)
                        .frame(width: 220, height: 210)
                }
                .buttonStyle(.plain)
                .accessibilityHint(L("Öppnar Pips garderob"))
                PrestigeStars(level: progress.level, size: 16)
            }
            .padding(.top, 62)
        }
        .frame(height: 340)
        .clipped()
    }

    // MARK: Who

    private func identity(_ progress: PlayerProgress) -> some View {
        let name = model.firstName ?? model.league.nickname ?? L("Du")
        let since = progress.firstDay.map { Season.monthName(String($0.prefix(7))) }
        let handle = model.league.nickname.map { "@\($0)" }
        let line = [handle, since.map { L("Med sedan \($0)") }].compactMap { $0 }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                if !line.isEmpty {
                    Text(line.uppercased())
                        .font(.footnote.weight(.heavy))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 0) {
                miniStat(top: Text(Country.flag(model.flagCountry)).font(.title2), bottom: L("Land"))
                miniStat(top: Text("\(progress.level)").font(.title2.weight(.heavy)), bottom: Level.title(for: progress.level))
                miniStat(top: Text("\(model.league.friendIDs.count)").font(.title2.weight(.heavy)), bottom: L("Vänner"))
            }
            Button {
                if model.league.nickname == nil {
                    isNicknamePresented = true
                } else {
                    isAddFriendPresented = true
                }
            } label: {
                Label(L("Lägg till vänner"), systemImage: "person.badge.plus")
            }
            .buttonStyle(ChunkyOutlineButtonStyle())
        }
    }

    private func miniStat(top: some View, bottom: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            top
            Text(bottom)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Event

    /// The month's season as an event: what it gives and how long is left, opening the quests.
    private var eventBanner: some View {
        let season = Season.at(.now, calendar: .current)
        let days = season.daysLeft(from: .now, calendar: .current)
        let items = season.items.compactMap { WardrobeItem.with(id: $0) }
        let colors = QuestsView.colors(for: season)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(items.isEmpty ? L("Klara månadens uppdrag för en trofé!") : L("Tjäna nya saker till Pip med månadens uppdrag!"))
                        .font(.title3.weight(.heavy))
                        .fixedSize(horizontal: false, vertical: true)
                    Label(days == 1 ? L("1 dag") : L("\(days) dagar"), systemImage: "timer")
                        .font(.headline.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Color(red: 1, green: 0.88, blue: 0.35))
                }
                Spacer(minLength: 4)
                if let item = items.first {
                    PipAvatar(outfit: Outfit(wearing: item), level: model.progress.level, size: 64)
                        .frame(width: 90, height: 90)
                } else {
                    Image(systemName: season.symbol)
                        .font(.system(size: 54, weight: .bold))
                        .frame(width: 90, height: 90)
                }
            }
            .foregroundStyle(.white)
            Button(L("Visa uppdragen")) { model.selectedTab = .quests }
                .buttonStyle(ChunkyButtonStyle(fill: .white, edge: Color.white.opacity(0.45), text: colors[1]))
        }
        .padding(20)
        .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    // MARK: Overview

    private func overview(_ progress: PlayerProgress) -> some View {
        let streak = progress.currentStreak(at: .now, calendar: .current)
        return VStack(alignment: .leading, spacing: 14) {
            GameSectionHeader(title: L("Översikt"))
            LazyVGrid(columns: tiles, spacing: 12) {
                tile(symbol: "flame.fill", tint: streak > 0 ? Theme.flame : .secondary, value: streak == 1 ? L("1 dag") : L("\(streak) dagar"),
                     label: L("Streak"))
                tile(symbol: "bolt.fill", tint: Color(red: 1, green: 0.85, blue: 0.25), value: "\(Format.number(progress.xp))", label: "XP")
                tile(symbol: "shield.lefthalf.filled", tint: Theme.orange, value: progress.division.title, label: L("Liga"))
                tile(symbol: "scope", tint: Theme.violet, value: Format.minutes(progress.focusMinutes), label: L("Fokus totalt"))
                tile(symbol: "trophy.fill", tint: Theme.pink, value: "\(progress.bestStreak)", label: L("Bästa streak"))
                tile(symbol: "hand.raised.fill", tint: Theme.mint, value: "\(progress.closes)", label: L("Stängda appar"))
            }
        }
    }

    private func tile(symbol: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.headline.weight(.heavy).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .gameTile()
        .accessibilityElement(children: .combine)
    }

    // MARK: Month badges

    /// The months' badges: those won, this month's filling up as its quests are done, and the next ones still locked.
    private func monthBadges(_ progress: PlayerProgress) -> some View {
        let calendar = Calendar.current
        let current = Season.at(.now, calendar: calendar)
        let won = progress.unlocked.compactMap { Season.containing(trophyID: $0) }.filter { $0.key != current.key }
            .sorted { $0.key < $1.key }
        let upcoming = (1...2).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: .now).map { Season.at($0, calendar: calendar) }
        }
        let month = progress.monthCounts(at: .now, calendar: calendar)
        let done = current.quests.filter { month.completedQuests.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 14) {
            GameSectionHeader(title: L("Månadsmärken"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(won, id: \.key) { season in
                        MonthBadge(season: season, state: .won)
                    }
                    MonthBadge(season: current, state: progress.unlocked.contains(current.trophyID) ? .won : .running(done, current.quests.count))
                    ForEach(upcoming, id: \.key) { season in
                        MonthBadge(season: season, state: .locked)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, -16)
        }
    }
}

/// A month's badge: lit once its quests are all done, ringed by how far along it is while it runs, locked ahead.
private struct MonthBadge: View {
    enum Stage {
        case won, locked
        case running(Int, Int)
    }

    let season: Season
    let state: Stage

    private var fraction: Double {
        if case .running(let done, let total) = state { return Double(done) / Double(max(1, total)) }
        if case .won = state { return 1 }
        return 0
    }

    private var isWon: Bool {
        if case .won = state { return true }
        return false
    }

    private var isLocked: Bool {
        if case .locked = state { return true }
        return false
    }

    var body: some View {
        let colors = QuestsView.colors(for: season)
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isWon ? AnyShapeStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Theme.cardRaised))
                Circle()
                    .strokeBorder(isWon ? Color(red: 1, green: 0.85, blue: 0.35) : Color.white.opacity(0.1), lineWidth: 4)
                if !isWon && !isLocked {
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(2)
                }
                Image(systemName: isLocked ? "lock.fill" : season.symbol)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(isWon ? Color.white : isLocked ? Color.secondary : colors[0])
            }
            .frame(width: 80, height: 80)
            .shadow(color: isWon ? colors[0].opacity(0.6) : .clear, radius: 10)
            Text(season.name)
                .font(.caption.weight(.bold))
                .foregroundStyle(isLocked ? .secondary : .primary)
                .lineLimit(1)
                .frame(width: 84)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isWon ? L("Upplåst") : L("Låst"))
    }
}
