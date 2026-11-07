import SwiftUI

/// The quests, like a game's quest board: the month's quests under a bright banner with Pip and a bar of milestones,
/// the week's quests over a little scene, and today's quests, each with a chest that opens once it's done.
struct QuestsView: View {
    @Environment(AppModel.self) private var model

    private var calendar: Calendar { .current }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                ScrollView {
                    VStack(spacing: 26) {
                        monthBanner(at: context.date)
                        Group {
                            weekSection(at: context.date)
                            daySection(at: context.date)
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 28)
                }
                .ignoresSafeArea(edges: .top)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    /// Why screen time isn't measured right now, so the quests about it can't be done.
    private func untracked(at date: Date) -> String? {
        !model.hasSelection ? L("Välj appar att skydda först")
            : model.rules.isOnVacation(at: date) ? L("Räknas inte under semesterläget") : nil
    }

    // MARK: Month

    static func colors(for season: Season) -> [Color] {
        let month = Int(season.key.suffix(2)) ?? 1
        switch month {
        case 11: return [Color(red: 0.86, green: 0.3, blue: 0.62), Theme.violet]
        case 12: return [Color(red: 0.25, green: 0.6, blue: 1), Color(red: 0.35, green: 0.3, blue: 0.9)]
        case 1: return [Theme.orange, Theme.pink]
        case 2, 5, 8: return [Color(red: 0.95, green: 0.35, blue: 0.45), Color(red: 0.6, green: 0.2, blue: 0.8)]
        case 3, 6, 9: return [Color(red: 0.2, green: 0.75, blue: 0.5), Color(red: 0.1, green: 0.45, blue: 0.7)]
        default: return [Color(red: 1, green: 0.55, blue: 0.25), Color(red: 0.85, green: 0.25, blue: 0.4)]
        }
    }

    private func monthBanner(at date: Date) -> some View {
        let season = Season.at(date, calendar: calendar)
        let month = model.progress.monthCounts(at: date, calendar: calendar)
        let counts = model.progress.counts(at: date, calendar: calendar)
        let done = season.quests.filter { month.completedQuests.contains($0.id) }.count
        let daysLeft = season.daysLeft(from: date, calendar: calendar)
        let untracked = untracked(at: date)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Månadens uppdrag"))
                        .font(.subheadline.weight(.heavy))
                        .textCase(.uppercase)
                        .opacity(0.85)
                    Text(season.name)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Label(daysLeft == 1 ? L("1 dag") : L("\(daysLeft) dagar"), systemImage: "timer")
                        .font(.headline.weight(.heavy))
                        .textCase(.uppercase)
                        .opacity(0.9)
                }
                Spacer(minLength: 8)
                MascotView(mood: done == season.quests.count ? .proud : .happy, level: model.progress.level, size: 96,
                           outfit: model.progress.outfit)
                    .frame(width: 110, height: 110)
                    .offset(y: 6)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.top, 70)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(L("Klara månadens tre uppdrag"))
                        .font(.headline.weight(.heavy))
                    Spacer()
                    Text("\(done) / \(season.quests.count)")
                        .font(.headline.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Self.colors(for: season)[0])
                }
                MilestoneBar(done: done, rewards: milestoneRewards(season), tint: Self.colors(for: season))
                if let tagline = season.tagline {
                    Text(tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(season.quests.enumerated()), id: \.element.id) { index, quest in
                    let item = index < season.items.count ? WardrobeItem.with(id: season.items[index]) : nil
                    GameQuestRow(quest: quest, progress: quest.progress(today: counts, week: month),
                                 isDone: month.completedQuests.contains(quest.id), untracked: untracked, reward: item)
                }
                Label(L("Klara alla tre för månadens trofé. Sakerna finns bara den här månaden."), systemImage: "trophy.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .background(alignment: .top) {
            LinearGradient(colors: Self.colors(for: season), startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 300)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: season.symbol)
                        .font(.system(size: 150, weight: .black))
                        .foregroundStyle(.white.opacity(0.08))
                        .rotationEffect(.degrees(-12))
                        .offset(x: 30, y: 30)
                }
                .clipped()
        }
    }

    /// What each milestone gives: the season's items, then its trophy.
    private func milestoneRewards(_ season: Season) -> [String] {
        (0..<season.quests.count).map { index in
            if index == season.quests.count - 1 { return "trophy.fill" }
            return index < season.items.count ? "tshirt.fill" : "star.fill"
        }
    }

    // MARK: Week

    private func weekSection(at date: Date) -> some View {
        let progress = model.progress
        let counts = progress.counts(at: date, calendar: calendar)
        let week = progress.weekCounts(at: date, calendar: calendar)
        let weekKey = League.weekKey(for: date, calendar: calendar)
        let quests = Quest.weekly(for: weekKey, includesPro: model.isPro, level: progress.level)
        let end = calendar.dateInterval(of: .weekOfYear, for: date)?.end ?? date
        let days = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: end).day ?? 1)
        let untracked = untracked(at: date)
        return VStack(alignment: .leading, spacing: 14) {
            GameSectionHeader(title: L("Veckans uppdrag"), timer: L("\(days) d"), tint: Theme.orange)
            WeekScene(level: progress.level, outfit: progress.outfit, done: quests.filter { week.completedQuests.contains($0.id) }.count,
                      total: quests.count)
            ForEach(quests) { quest in
                GameQuestRow(quest: quest, progress: quest.progress(today: counts, week: week), isDone: week.completedQuests.contains(quest.id),
                             untracked: untracked, chestTint: [Theme.pink, Theme.violet])
            }
        }
    }

    // MARK: Today

    private func daySection(at date: Date) -> some View {
        let progress = model.progress
        let counts = progress.counts(at: date, calendar: calendar)
        let week = progress.weekCounts(at: date, calendar: calendar)
        let day = DayKey.string(for: date, calendar: calendar)
        let daily = Quest.daily(for: day, includesPro: model.isPro, level: progress.level)
        let doneDaily = daily.filter { counts.completedQuests.contains($0.id) }.count
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let hours = max(1, Int((midnight.timeIntervalSince(date) / 3600).rounded(.up)))
        let untracked = untracked(at: date)
        return VStack(alignment: .leading, spacing: 14) {
            GameSectionHeader(title: L("Dagens uppdrag"), timer: L("\(hours) h"))
            ForEach(daily) { quest in
                GameQuestRow(quest: quest, progress: quest.progress(today: counts, week: week), isDone: counts.completedQuests.contains(quest.id),
                             holds: quest.isHolding(today: counts), untracked: untracked)
            }
            if let bonus = Quest.bonus(for: day, includesPro: model.isPro, level: progress.level) {
                if doneDaily == daily.count {
                    GameQuestRow(quest: bonus, progress: bonus.progress(today: counts, week: week), isDone: counts.completedQuests.contains(bonus.id),
                                 holds: bonus.isHolding(today: counts), untracked: untracked, label: L("Bonus"),
                                 chestTint: [Color(red: 1, green: 0.95, blue: 0.55), Color(red: 1, green: 0.65, blue: 0.1)])
                } else {
                    HStack(spacing: 14) {
                        Image(systemName: "lock.fill")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(width: 46, height: 46)
                            .background(Theme.cardRaised, in: Circle())
                        Text(L("Klara alla tre för att låsa upp bonusuppdraget"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .gameTile()
                }
            }
        }
    }
}

/// One quest as a tile: its title and XP, a fat bar with the count, and a chest, or what it gives, on the right.
struct GameQuestRow: View {
    let quest: Quest
    let progress: Int
    let isDone: Bool
    /// For a quest about the whole day: whether it still holds so far today.
    var holds = true
    /// Why screen time isn't measured right now, if it isn't.
    var untracked: String?
    var label: String?
    /// Something for Pip the quest gives, shown instead of a chest.
    var reward: WardrobeItem?
    var chestTint: [Color] = [Color(red: 1, green: 0.88, blue: 0.35), Theme.orange]

    /// What a quest about the whole day shows instead of the count until it is decided.
    private var status: String? {
        guard !isDone, quest.needsTracking else { return nil }
        if let untracked { return untracked }
        guard quest.isEvening else { return nil }
        return holds ? L("Håller hittills · avgörs kl. \(Quest.eveningHour)") : L("Inte i dag")
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    if let label {
                        Text(label.uppercased())
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.brand, in: Capsule())
                    }
                    Text(quest.title)
                        .font(.headline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                QuestBar(value: isDone ? quest.target : progress, target: quest.target, label: isDone ? L("Klart!") : status)
                Text("+\(quest.xp) XP")
                    .font(.caption.weight(.heavy).monospacedDigit())
                    .foregroundStyle(isDone ? Theme.mint : .secondary)
            }
            if let reward {
                PipAvatar(outfit: Outfit(wearing: reward), level: 1, size: 34)
                    .frame(width: 52, height: 52)
                    .background(Theme.cardRaised, in: Circle())
                    .overlay(alignment: .bottomTrailing) {
                        if isDone {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white, Theme.mint)
                        }
                    }
            } else {
                QuestChest(isDone: isDone, tint: chestTint)
            }
        }
        .gameTile(rim: isDone ? Theme.mint.opacity(0.45) : Color.white.opacity(0.12))
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? L("Klart") : status ?? L("\(min(progress, quest.target)) av \(quest.target)"))
    }
}

/// A bar of milestones: a marker for each, with what it gives, lit once reached.
private struct MilestoneBar: View {
    let done: Int
    /// The symbol of what each milestone gives.
    let rewards: [String]
    let tint: [Color]

    var body: some View {
        GeometryReader { proxy in
            let count = max(1, rewards.count)
            let width = proxy.size.width - 40
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 16)
                    .padding(.trailing, 20)
                Capsule()
                    .fill(LinearGradient(colors: tint, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(16, width * CGFloat(min(done, count)) / CGFloat(count) + 20), height: 16)
                    .opacity(done > 0 ? 1 : 0)
                ForEach(0..<count, id: \.self) { index in
                    marker(index: index)
                        .position(x: 20 + width * CGFloat(index + 1) / CGFloat(count), y: proxy.size.height / 2)
                }
            }
        }
        .frame(height: 44)
        .animation(.spring(duration: 0.6), value: done)
    }

    private func marker(index: Int) -> some View {
        let reached = index < done
        return ZStack {
            Circle()
                .fill(reached ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.35), Theme.orange],
                                                             startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Theme.cardRaised))
            Circle()
                .strokeBorder(Color.white.opacity(reached ? 0.8 : 0.15), lineWidth: 2)
            Image(systemName: reached ? "checkmark" : rewards[index])
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(reached ? Color.white : Color.secondary)
        }
        .frame(width: 40, height: 40)
        .shadow(color: reached ? Theme.orange.opacity(0.6) : .clear, radius: 8)
    }
}

/// A little scene for the week: Pip on a hill in the land of the player's level, next to the week's chest.
private struct WeekScene: View {
    let level: Int
    let outfit: Outfit
    let done: Int
    let total: Int

    var body: some View {
        let land = Journey.land(for: level)
        let colors = LevelPath.colors(for: land)
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [colors[0].opacity(0.85), colors[1]], startPoint: .top, endPoint: .bottom)
            Image(systemName: land.symbol)
                .font(.system(size: 90, weight: .bold))
                .foregroundStyle(.white.opacity(0.1))
                .offset(x: -110, y: -40)
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 420, height: 120)
                .offset(y: 70)
            HStack(alignment: .bottom, spacing: 26) {
                MascotView(mood: done == total ? .proud : .happy, level: level, size: 92, outfit: outfit)
                    .frame(width: 110, height: 110)
                VStack(spacing: 4) {
                    QuestChest(isDone: done == total && total > 0, tint: [Theme.pink, Theme.violet], size: 64)
                    Text("\(done) / \(total)")
                        .font(.headline.weight(.heavy).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 10)
            }
            .padding(.bottom, 4)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Veckans uppdrag: \(done) av \(total) klara"))
    }
}
