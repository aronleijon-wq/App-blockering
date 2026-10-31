import SwiftUI

struct LeagueView: View {
    @Environment(AppModel.self) private var model
    @State private var scope: LeagueService.Scope = .friends
    @State private var isAddFriendPresented = false
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
                            title: L("Logga in på iCloud"),
                            text: L("Ligan använder iCloud. Logga in under Inställningar > [ditt namn] för att tävla.")
                        )
                    } else if league.nickname == nil {
                        joinCard
                    } else {
                        leaderboard
                    }
                    inviteCard
                    pointsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle(L("Liga"))
            .toolbar {
                if league.nickname != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isNicknamePresented = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                        .accessibilityLabel(L("Ändra smeknamn"))
                    }
                }
            }
            .refreshable {
                await model.syncLeague(force: true)
                await league.load(scope, progress: model.progress)
            }
            // Runs again after a new nickname, new points or a new level, so the list never lags behind.
            .task(id: "\(scope.rawValue)|\(league.nickname ?? "")|\(model.progress.weeklyPoints)|\(model.progress.level)") {
                await model.syncLeague(force: false)
                await league.load(scope, progress: model.progress)
            }
            .sheet(isPresented: $isNicknamePresented) {
                NicknameSheet()
            }
            .sheet(isPresented: $isAddFriendPresented) {
                AddFriendSheet {
                    await model.syncLeague(force: true)
                    await league.load(.friends, progress: model.progress)
                }
            }
            .confirmationDialog(
                L("Anmäl \(reporting?.nickname ?? "")?"),
                isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }),
                titleVisibility: .visible
            ) {
                Button(L("Anmäl olämpligt namn"), role: .destructive) {
                    if let entry = reporting {
                        Task { await league.report(entry) }
                    }
                }
                Button(L("Avbryt"), role: .cancel) {}
            } message: {
                Text(L("Spelaren döljs för dig och namnet granskas."))
            }
        }
    }

    // MARK: Header

    private var header: some View {
        let progress = model.progress
        let now = Date.now
        return VStack(spacing: 14) {
            DivisionBadge(division: progress.division, size: 84)
            Text(L("\(progress.division.title)-ligan"))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.brand)
            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(progress.pointsThisWeek(at: now, calendar: .current))")
                        .font(.title2.bold().monospacedDigit())
                    Text(L("poäng den här veckan"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text(timeLeft(now: now))
                        .font(.title2.bold().monospacedDigit())
                    Text(L("kvar av veckan"))
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
        return days > 0 ? L("\(days) d \(hours) h") : "\(hours) h \((seconds % 3600) / 60) min"
    }

    private func rulesText(for division: Division) -> String {
        switch (division.promotionPoints, division.relegationPoints) {
        case let (up?, down?):
            return L("Nå \(up) poäng för att gå upp till \(division.higher.title). Under \(down) åker du ner till \(division.lower.title).")
        case let (up?, nil):
            return L("Nå \(up) poäng den här veckan för att gå upp till \(division.higher.title).")
        case let (nil, down?):
            return L("Du är i toppen! Under \(down) poäng åker du ner till \(division.lower.title).")
        case (nil, nil):
            return ""
        }
    }

    // MARK: Leaderboard

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(L("Topplista"), selection: $scope) {
                ForEach(LeagueService.Scope.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            if scope == .friends {
                friendCodeRow
            }

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
                    LeaderboardRow(rank: index + 1, entry: entry)
                        .contextMenu {
                            if !entry.isMe {
                                if scope == .friends {
                                    Button(L("Ta bort vän"), systemImage: "person.badge.minus") { league.removeFriend(entry) }
                                }
                                Button(L("Anmäl"), systemImage: "exclamationmark.bubble") { reporting = entry }
                                Button(L("Blockera"), systemImage: "hand.raised") { league.block(entry) }
                            }
                        }
                }
            }
        }
        .card()
    }

    /// The player's own code, and the way to add someone else's.
    private var friendCodeRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Din vänkod"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(league.friendCode)
                    .font(.title3.bold().monospaced())
                    .textSelection(.enabled)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = league.friendCode
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .accessibilityLabel(L("Kopiera koden"))
            Button {
                isAddFriendPresented = true
            } label: {
                Label(L("Lägg till"), systemImage: "person.badge.plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.violet)
        }
        .padding(12)
        .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyText: String {
        switch scope {
        case .friends:
            return L("Lägg till en vän med deras kod, eller skicka din. Den som scrollar minst vinner veckan.")
        case .sweden, .world:
            return L("Ingen har fått poäng den här veckan än. Bli först!")
        }
    }

    private var inviteCard: some View {
        ShareLink(
            item: AppInfo.inviteURL,
            subject: Text(L("Utmana mig i Paus")),
            message: Text(AppInfo.inviteMessage(nickname: league.nickname, code: league.friendCode))
        ) {
            HStack(spacing: 14) {
                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.glow, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Utmana dina vänner"))
                        .font(.headline)
                    Text(L("Skicka din kod. Den som scrollar minst vinner veckan."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
            .card()
        }
        .buttonStyle(.plain)
    }

    private var joinCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 40))
                .foregroundStyle(Theme.brand)
            Text(L("Tävla mot andra"))
                .font(.title3.bold())
            Text(L("Tävla mot dina vänner och resten av Sverige. Samla poäng varje vecka och klättra i divisionerna."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(L("Välj smeknamn")) { isNicknamePresented = true }
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
            Text(L("Så får du poäng"))
                .font(.headline)
            PointRow(symbol: "scope", text: L("Fokuspass"), value: L("1 / min, max \(League.Points.focusDailyCap) per dag"))
            PointRow(symbol: "checkmark.shield", text: L("Dag under din gräns"), value: "+\(League.Points.dayUnderLimit)")
            PointRow(symbol: "hand.raised.fill", text: L("Stänga en blockerad app"), value: "+\(League.Points.close)")
            PointRow(symbol: "wind", text: L("Tacka nej till en paus"), value: "+\(League.Points.decline)")
            PointRow(symbol: "gift.fill", text: L("Dagens belöning"), value: "+\(League.Points.dailyReward)")
        }
        .card()
    }
}

private struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry

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
                Text(L("Nivå \(entry.level)"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
        .accessibilityLabel(L("\(division.title)-ligan"))
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
