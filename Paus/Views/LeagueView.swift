import SwiftUI

struct LeagueView: View {
    @Environment(AppModel.self) private var model
    @State private var scope: LeagueService.Scope = .group
    @State private var isNicknamePresented = false
    @State private var reporting: LeaderboardEntry?

    private var league: LeagueService { model.league }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if league.accountState == .unavailable {
                        notice(
                            symbol: "icloud.slash",
                            title: "Logga in på iCloud",
                            text: "Ligan använder iCloud. Logga in under Inställningar > [ditt namn] för att tävla."
                        )
                    } else if league.nickname == nil {
                        joinCard
                    } else {
                        leaderboard
                    }
                    pointsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("Liga")
            .toolbar {
                if league.nickname != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isNicknamePresented = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                        .accessibilityLabel("Ändra smeknamn")
                    }
                }
            }
            .refreshable {
                await model.syncLeague(force: true)
                await league.load(scope, progress: model.progress)
            }
            // Runs again after a new nickname, so the list never shows the old one.
            .task(id: "\(scope.rawValue)|\(league.nickname ?? "")") {
                await model.syncLeague(force: false)
                await league.load(scope, progress: model.progress)
            }
            .sheet(isPresented: $isNicknamePresented) {
                NicknameSheet()
            }
            .confirmationDialog(
                "Anmäl \(reporting?.nickname ?? "")?",
                isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }),
                titleVisibility: .visible
            ) {
                Button("Anmäl olämpligt namn", role: .destructive) {
                    if let entry = reporting {
                        Task { await league.report(entry) }
                    }
                }
                Button("Avbryt", role: .cancel) {}
            } message: {
                Text("Spelaren döljs för dig och namnet granskas.")
            }
        }
    }

    // MARK: Header

    private var header: some View {
        let progress = model.progress
        let now = Date.now
        return VStack(spacing: 14) {
            DivisionBadge(division: progress.division, size: 84)
            Text("\(progress.division.title)-ligan")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.brand)
            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(progress.pointsThisWeek(at: now, calendar: .current))")
                        .font(.title2.bold().monospacedDigit())
                    Text("poäng den här veckan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text(timeLeft(now: now))
                        .font(.title2.bold().monospacedDigit())
                    Text("kvar av veckan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(rulesText(for: progress.division))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(highlighted: true)
    }

    private func timeLeft(now: Date) -> String {
        let seconds = Int(League.weekEnd(for: now, calendar: .current).timeIntervalSince(now))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3600
        return days > 0 ? "\(days) d \(hours) h" : "\(hours) h \((seconds % 3600) / 60) min"
    }

    private func rulesText(for division: Division) -> String {
        switch division {
        case .brons:
            return "De bästa i din grupp går upp till \(division.higher.title) på söndag kväll."
        case .legend:
            return "Du är i toppen! De sämsta i gruppen åker ner till \(division.lower.title)."
        default:
            return "De bästa går upp till \(division.higher.title), de sämsta åker ner till \(division.lower.title)."
        }
    }

    // MARK: Leaderboard

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Topplista", selection: $scope) {
                ForEach(LeagueService.Scope.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            let rows = league.entries[scope] ?? []
            if league.loadingScope == scope && rows.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if rows.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                    LeaderboardRow(rank: index + 1, entry: entry, movesUp: scope == .group && index < movingCount(rows.count))
                        .contextMenu {
                            if !entry.isMe {
                                Button("Anmäl", systemImage: "exclamationmark.bubble") { reporting = entry }
                                Button("Blockera", systemImage: "hand.raised") { league.block(entry) }
                            }
                        }
                }
            }
        }
        .card()
    }

    private func movingCount(_ size: Int) -> Int {
        max(1, size / League.movingShare)
    }

    private var emptyText: String {
        switch scope {
        case .group:
            return "Du hamnar i en grupp när du har fått dina första poäng den här veckan. Hämta dagens belöning eller kör ett fokuspass!"
        case .sweden, .world:
            return "Ingen har fått poäng den här veckan än. Bli först!"
        }
    }

    private var joinCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 40))
                .foregroundStyle(Theme.brand)
            Text("Tävla mot andra")
                .font(.title3.bold())
            Text("Varje vecka hamnar du i en grupp med upp till \(League.groupSize) andra i din division. De bästa går upp, de sämsta åker ner.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Välj smeknamn") { isNicknamePresented = true }
                .buttonStyle(GlowButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func notice(symbol: String, title: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private var pointsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Så får du poäng")
                .font(.headline)
            PointRow(symbol: "scope", text: "Fokuspass", value: "1 / min, max \(League.Points.focusDailyCap) per dag")
            PointRow(symbol: "checkmark.shield", text: "Dag under din gräns", value: "+\(League.Points.dayUnderLimit)")
            PointRow(symbol: "hand.raised.fill", text: "Stänga en blockerad app", value: "+\(League.Points.close)")
            PointRow(symbol: "wind", text: "Tacka nej till en paus", value: "+\(League.Points.decline)")
            PointRow(symbol: "gift.fill", text: "Dagens belöning", value: "+\(League.Points.dailyReward)")
        }
        .card()
    }
}

private struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    let movesUp: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(rank <= 3 ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Color.secondary))
                .frame(width: 32)
            MiniPip(level: entry.level)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.isMe ? "\(entry.nickname) (du)" : entry.nickname)
                    .font(.subheadline.weight(entry.isMe ? .bold : .semibold))
                    .lineLimit(1)
                Text("Nivå \(entry.level)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if movesUp {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(Theme.mint)
                    .accessibilityLabel("Går upp")
            }
            Text("\(entry.points)")
                .font(.headline.monospacedDigit())
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(entry.isMe ? Theme.cardRaised : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct PointRow: View {
    let symbol: String
    let text: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(Theme.pink)
                .frame(width: 24)
            Text(text)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

/// A still, tiny Pip for lists, where dozens of animated ones would be too heavy.
struct MiniPip: View {
    let level: Int

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                HStack(spacing: size * 0.16) {
                    Circle().fill(.white).frame(width: size * 0.22)
                    Circle().fill(.white).frame(width: size * 0.22)
                }
                .offset(y: -size * 0.06)
            }
        }
        .accessibilityHidden(true)
    }

    private var colors: [Color] {
        switch level {
        case ..<3: return [Theme.mint, Color(red: 0.2, green: 0.75, blue: 0.95)]
        case 3..<5: return [Theme.violet, Theme.pink]
        case 5..<8: return [Theme.pink, Theme.orange]
        default: return [Theme.orange, Color(red: 1, green: 0.9, blue: 0.35)]
        }
    }
}

struct DivisionBadge: View {
    let division: Division
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Image(systemName: "shield.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                .shadow(color: colors.first?.opacity(0.6) ?? .clear, radius: 12)
            Image(systemName: division == .legend ? "crown.fill" : "star.fill")
                .font(.system(size: size * 0.3, weight: .bold))
                .foregroundStyle(.white)
                .offset(y: -size * 0.04)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("\(division.title)-ligan")
    }

    private var colors: [Color] {
        switch division {
        case .brons: return [Color(red: 0.86, green: 0.55, blue: 0.33), Color(red: 0.6, green: 0.35, blue: 0.2)]
        case .silver: return [Color(red: 0.85, green: 0.87, blue: 0.92), Color(red: 0.55, green: 0.58, blue: 0.66)]
        case .guld: return [Color(red: 1, green: 0.85, blue: 0.3), Color(red: 0.9, green: 0.6, blue: 0.1)]
        case .diamant: return [Color(red: 0.5, green: 0.95, blue: 1), Color(red: 0.25, green: 0.55, blue: 0.95)]
        case .legend: return [Theme.pink, Theme.violet]
        }
    }
}
