import CloudKit
import Foundation
import Observation

/// A duel this week, as it stands.
struct DuelStanding: Identifiable, Equatable {
    let id: String
    let opponentID: String
    let opponentName: String
    let mine: Int
    let theirs: Int
}

struct LeaderboardEntry: Identifiable, Equatable {
    let id: String
    let nickname: String
    let points: Int
    let level: Int
    let division: Division
    let isMe: Bool
}

/// The league in CloudKit's public database. Each player owns one `Player` record per device account,
/// which only that player can change; everyone can read them.
@MainActor
@Observable
final class LeagueService {
    enum Scope: String, CaseIterable, Identifiable {
        case friends, sweden, world

        var id: Self { self }

        var title: String {
            switch self {
            case .friends: return L("Vänner")
            case .sweden: return L("Sverige")
            case .world: return L("Världen")
            }
        }
    }

    enum AccountState {
        case unknown, available, unavailable
    }

    private enum Keys {
        static let nickname = "league.nickname"
        static let blocked = "league.blocked"
        static let friendCode = "league.friendCode"
        static let friends = "league.friends"
        static let unfriended = "league.unfriended"
        static let sharesCode = "league.sharesCode"
        static let settledDuelWeeks = "league.settledDuelWeeks"
    }

    private enum DuelField {
        static let type = "Duel"
        static let challenger = "challenger"
        static let opponent = "opponent"
        static let weekKey = "weekKey"
    }

    enum FriendError: Error {
        case notFound, ownCode
    }

    private enum Field {
        static let type = "Player"
        static let nickname = "nickname"
        static let weekKey = "weekKey"
        static let weeklyPoints = "weeklyPoints"
        static let level = "level"
        static let division = "division"
        static let groupID = "groupID"
        static let country = "country"
        static let joinedAt = "joinedAt"
        static let friendCode = "friendCode"
        static let friends = "friends"
        /// The record name of the player whose code this player added first.
        static let invitedBy = "invitedBy"
        /// 1 once this invited player has finished a focus session, which earns the one who invited them.
        static let inviteQualified = "inviteQualified"
        /// Last week's key and points, so friends can settle duels after the week has turned.
        static let lastWeekKey = "lastWeekKey"
        static let lastWeekPoints = "lastWeekPoints"
    }

    private(set) var accountState: AccountState = .unknown
    private(set) var entries: [Scope: [LeaderboardEntry]] = [:]
    private(set) var loadingScope: Scope?
    private(set) var nickname: String?
    private(set) var blockedIDs: Set<String>
    /// The code friends type in to add this player. Made once per phone and kept.
    let friendCode: String
    /// Record names of the players this player added. Players who added this player are found in CloudKit.
    private(set) var friendIDs: Set<String>
    /// Players removed from the friends list, so they stay gone even though they still have this player.
    private var unfriendedIDs: Set<String>
    /// Who invited this player: the first player whose code they added.
    private(set) var invitedBy: String?
    /// Invited friends who have already earned this player free Pro, so each counts once.
    private(set) var rewardedInviteIDs: Set<String>
    /// This week's duels.
    private(set) var duels: [DuelStanding] = []
    @ObservationIgnored private var settledDuelWeeks: Set<String>

    var canCompete: Bool { accountState == .available && nickname != nil }
    /// Whether this player has invited someone, so their code must be findable even outside the league.
    private(set) var sharesCode: Bool

    @ObservationIgnored private let container: CKContainer
    @ObservationIgnored private var playerRecordName: String?
    @ObservationIgnored private var uploadedSignature: String?
    @ObservationIgnored private var uploadedGroupID: String?

    private var database: CKDatabase { container.publicCloudDatabase }

    init() {
        let identifier = Bundle.main.object(forInfoDictionaryKey: "PausCloudContainer") as? String ?? "iCloud.se.aronleijon.paus"
        container = CKContainer(identifier: identifier)
        nickname = UserDefaults.standard.string(forKey: Keys.nickname)
        blockedIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.blocked) ?? [])
        friendIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.friends) ?? [])
        unfriendedIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.unfriended) ?? [])
        invitedBy = ReferralRecord.invitedBy
        rewardedInviteIDs = (try? ReferralRecord.rewardedInvites()) ?? []
        sharesCode = UserDefaults.standard.bool(forKey: Keys.sharesCode)
        settledDuelWeeks = Set(UserDefaults.standard.stringArray(forKey: Keys.settledDuelWeeks) ?? [])
        if let code = UserDefaults.standard.string(forKey: Keys.friendCode) {
            friendCode = code
        } else {
            friendCode = FriendCode.make()
            UserDefaults.standard.set(friendCode, forKey: Keys.friendCode)
        }
    }

    func refreshAccount() async {
        let status = try? await container.accountStatus()
        accountState = status == .available ? .available : .unavailable
    }

    /// Called when the player invites someone: from now on their code is uploaded so the friend can add it.
    func shareCode() {
        guard !sharesCode else { return }
        sharesCode = true
        UserDefaults.standard.set(true, forKey: Keys.sharesCode)
        uploadedSignature = nil
    }

    func setNickname(_ name: String) {
        nickname = name.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(nickname, forKey: Keys.nickname)
        uploadedSignature = nil
    }

    /// Removes the player from the league: deletes their record and forgets the nickname.
    func leave() async throws {
        let recordID = try await myRecordID()
        _ = try await database.modifyRecords(saving: [], deleting: [recordID])
        nickname = nil
        sharesCode = false
        UserDefaults.standard.removeObject(forKey: Keys.nickname)
        UserDefaults.standard.removeObject(forKey: Keys.sharesCode)
        uploadedSignature = nil
        uploadedGroupID = nil
        entries = [:]
    }

    /// Rank and size of a finished week's group, or nil when the player isn't in it.
    func standing(weekKey: String, groupID: String) async throws -> (rank: Int, size: Int)? {
        let records = try await query(NSPredicate(format: "%K == %@ AND %K == %@", Field.weekKey, weekKey, Field.groupID, groupID), limit: League.groupSize + 10)
        let me = try await myRecordID().recordName
        guard let index = records.firstIndex(where: { $0.recordID.recordName == me }) else { return nil }
        return (index + 1, records.count)
    }

    /// Publishes the player's nickname, friend code and friends, and their week once it has points. A player who
    /// invited someone without joining the league uploads only the code, which keeps them off the leaderboards.
    /// Skips the upload when nothing visible changed.
    func upload(_ progress: PlayerProgress) async throws {
        guard nickname != nil || sharesCode else { return }
        let friends = friendIDs.sorted()
        let week = progress.weekKey.flatMap { progress.weeklyPoints > 0 ? $0 : nil }
        let qualified = progress.focusSessions > 0
        let lastWeek = progress.lastWeek
        let signature = "\(lastWeek?.weekKey ?? "")|\(lastWeek?.points ?? 0)|\(nickname ?? "")|\(friendCode)|\(friends)|\(invitedBy ?? "")|\(qualified)|\(week ?? "")|\(progress.weeklyPoints)|\(progress.level)|\(progress.division.rawValue)"
        guard signature != uploadedSignature else { return }

        let record = CKRecord(recordType: Field.type, recordID: try await myRecordID())
        if let nickname {
            record[Field.nickname] = nickname
        }
        record[Field.friendCode] = friendCode
        // CloudKit can't store an empty list, so a player without friends gets none.
        if friends.isEmpty {
            record[Field.friends] = nil
        } else {
            record[Field.friends] = friends
        }
        if let lastWeek, nickname != nil {
            record[Field.lastWeekKey] = lastWeek.weekKey
            record[Field.lastWeekPoints] = lastWeek.points
        }
        if let invitedBy {
            record[Field.invitedBy] = invitedBy
            record[Field.inviteQualified] = qualified ? 1 : 0
        }
        if let week, nickname != nil {
            record[Field.weekKey] = week
            record[Field.weeklyPoints] = progress.weeklyPoints
            record[Field.level] = progress.level
            record[Field.division] = progress.division.rawValue
            record[Field.country] = Locale.current.region?.identifier ?? "SE"
            // Kept for players who joined a group before friends replaced groups, so last week can be settled.
            if let groupID = progress.leagueGroupID, groupID != uploadedGroupID {
                record[Field.groupID] = groupID
                record[Field.joinedAt] = Date.now
            }
        }
        // Changed keys only, so the record can be saved without fetching it first.
        let (results, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys, atomically: false)
        if case .failure(let error) = results[record.recordID] { throw error }
        uploadedSignature = signature
        uploadedGroupID = progress.leagueGroupID
    }

    // MARK: Duels

    /// Challenges a friend to a duel for the week `weekKey`.
    func startDuel(with entry: LeaderboardEntry, weekKey: String) async throws {
        let me = try await myRecordID().recordName
        let record = CKRecord(recordType: DuelField.type, recordID: CKRecord.ID(recordName: "duel-\(weekKey)-\(me)-\(entry.id)"))
        record[DuelField.challenger] = me
        record[DuelField.opponent] = entry.id
        record[DuelField.weekKey] = weekKey
        let (results, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys, atomically: false)
        if case .failure(let error) = results[record.recordID] { throw error }
    }

    /// Loads this week's duels, with the points each side has so far.
    func loadDuels(progress: PlayerProgress) async {
        let weekKey = League.weekKey(for: .now, calendar: .current)
        guard let opponents = try? await duelOpponents(weekKey: weekKey), !opponents.isEmpty else {
            duels = []
            return
        }
        let mine = progress.pointsThisWeek(at: .now, calendar: .current)
        let records = (try? await opponentRecords(opponents)) ?? [:]
        duels = opponents.compactMap { id -> DuelStanding? in
            guard !blockedIDs.contains(id) else { return nil }
            let record = records[id]
            let theirs = record?[Field.weekKey] as? String == weekKey ? record?[Field.weeklyPoints] as? Int ?? 0 : 0
            return DuelStanding(id: "\(weekKey)-\(id)", opponentID: id, opponentName: record?[Field.nickname] as? String ?? L("Ny spelare"), mine: mine, theirs: theirs)
        }
        .sorted { $0.opponentName < $1.opponentName }
    }

    /// Settles last week's duels once: each opponent's points for that week against `myPoints`.
    func settleDuels(weekKey: String, myPoints: Int) async throws -> [(name: String, outcome: Duel.Outcome)] {
        guard !settledDuelWeeks.contains(weekKey) else { return [] }
        let opponents = try await duelOpponents(weekKey: weekKey)
        let records = try await opponentRecords(opponents)
        let results = opponents.map { id -> (name: String, outcome: Duel.Outcome) in
            let record = records[id]
            let theirs: Int
            if record?[Field.weekKey] as? String == weekKey {
                theirs = record?[Field.weeklyPoints] as? Int ?? 0
            } else if record?[Field.lastWeekKey] as? String == weekKey {
                theirs = record?[Field.lastWeekPoints] as? Int ?? 0
            } else {
                theirs = 0
            }
            return (record?[Field.nickname] as? String ?? L("Ny spelare"), Duel.outcome(mine: myPoints, theirs: theirs))
        }
        settledDuelWeeks.insert(weekKey)
        UserDefaults.standard.set(Array(settledDuelWeeks), forKey: Keys.settledDuelWeeks)
        return results
    }

    /// Who this player duels in `weekKey`, whether they challenged or were challenged.
    private func duelOpponents(weekKey: String) async throws -> [String] {
        let me = try await myRecordID().recordName
        let started = try await duelQuery(NSPredicate(format: "%K == %@ AND %K == %@", DuelField.challenger, me, DuelField.weekKey, weekKey))
        let received = try await duelQuery(NSPredicate(format: "%K == %@ AND %K == %@", DuelField.opponent, me, DuelField.weekKey, weekKey))
        let ids = started.compactMap { $0[DuelField.opponent] as? String } + received.compactMap { $0[DuelField.challenger] as? String }
        return Array(Set(ids))
    }

    private func duelQuery(_ predicate: NSPredicate) async throws -> [CKRecord] {
        let (results, _) = try await database.records(matching: CKQuery(recordType: DuelField.type, predicate: predicate), resultsLimit: 50)
        return results.compactMap { try? $0.1.get() }
    }

    private func opponentRecords(_ ids: [String]) async throws -> [String: CKRecord] {
        guard !ids.isEmpty else { return [:] }
        var records: [String: CKRecord] = [:]
        for (id, result) in try await database.records(for: ids.map { CKRecord.ID(recordName: $0) }) {
            if let record = try? result.get() { records[id.recordName] = record }
        }
        return records
    }

    // MARK: Friends

    /// Adds the player with `code` as a friend. They see this player too, without adding back.
    /// Returns true when it also counted as this player's invite, the first code they ever added.
    @discardableResult
    func addFriend(code: String) async throws -> Bool {
        let code = FriendCode.normalized(code)
        guard code != friendCode else { throw FriendError.ownCode }
        let myID = try await myRecordID()
        let matches = try await query(NSPredicate(format: "%K == %@", Field.friendCode, code), sortedBy: nil, limit: 1)
        guard let id = matches.first?.recordID.recordName, id != myID.recordName else { throw FriendError.notFound }
        friendIDs.insert(id)
        unfriendedIDs.remove(id)
        saveFriends()
        uploadedSignature = nil

        // The invite is checked against the saved record too, so reinstalling Paus can't earn it twice.
        guard invitedBy == nil else { return false }
        let saved = try? await database.record(for: myID)
        guard saved?[Field.invitedBy] == nil else {
            invitedBy = saved?[Field.invitedBy] as? String
            ReferralRecord.invitedBy = invitedBy
            return false
        }
        invitedBy = id
        ReferralRecord.invitedBy = id
        return true
    }

    /// Players this player invited who have since finished a focus session and haven't earned anything yet.
    /// Each is counted once, up to `Referral.maxRewardedFriends`, even after Paus is reinstalled.
    func newlyQualifiedInvites() async throws -> Int {
        rewardedInviteIDs = try ReferralRecord.rewardedInvites()
        let room = Referral.maxRewardedFriends - rewardedInviteIDs.count
        guard room > 0 else { return 0 }
        let me = try await myRecordID().recordName
        let invited = try await query(NSPredicate(format: "%K == %@", Field.invitedBy, me), sortedBy: nil, limit: 200)
        let fresh = invited
            .filter { ($0[Field.inviteQualified] as? Int ?? 0) == 1 }
            .map(\.recordID.recordName)
            .filter { !rewardedInviteIDs.contains($0) && !blockedIDs.contains($0) }
            .prefix(room)
        guard !fresh.isEmpty else { return 0 }
        rewardedInviteIDs.formUnion(fresh)
        ReferralRecord.addRewardedInvites(fresh)
        return fresh.count
    }

    func removeFriend(_ entry: LeaderboardEntry) {
        friendIDs.remove(entry.id)
        unfriendedIDs.insert(entry.id)
        saveFriends()
        uploadedSignature = nil
        entries[.friends]?.removeAll { $0.id == entry.id }
    }

    private func saveFriends() {
        UserDefaults.standard.set(Array(friendIDs), forKey: Keys.friends)
        UserDefaults.standard.set(Array(unfriendedIDs), forKey: Keys.unfriended)
    }

    func load(_ scope: Scope, progress: PlayerProgress) async {
        guard let weekKey = progress.weekKey else { return }
        loadingScope = scope
        defer { loadingScope = nil }
        do {
            let records: [CKRecord]
            switch scope {
            case .friends:
                records = try await friendRecords()
            case .sweden:
                records = try await query(NSPredicate(format: "%K == %@ AND %K == %@", Field.weekKey, weekKey, Field.country, "SE"), limit: 100)
            case .world:
                records = try await query(NSPredicate(format: "%K == %@", Field.weekKey, weekKey), limit: 100)
            }
            let me = try? await myRecordID().recordName
            var rows = records.compactMap { record -> LeaderboardEntry? in
                guard !blockedIDs.contains(record.recordID.recordName) else { return nil }
                let isMe = record.recordID.recordName == me
                // A friend who hasn't scored this week still shows last week's numbers in CloudKit.
                let thisWeek = record[Field.weekKey] as? String == weekKey
                // CloudKit can take a while to return a record that was just saved, so the player's own
                // row always shows what this phone knows.
                return LeaderboardEntry(
                    id: record.recordID.recordName,
                    nickname: isMe ? nickname ?? "?" : record[Field.nickname] as? String ?? L("Ny spelare"),
                    points: isMe ? progress.weeklyPoints : thisWeek ? record[Field.weeklyPoints] as? Int ?? 0 : 0,
                    level: isMe ? progress.level : record[Field.level] as? Int ?? 1,
                    division: isMe ? progress.division : Division(rawValue: record[Field.division] as? Int ?? 0) ?? .brons,
                    isMe: isMe
                )
            }
            if scope == .friends, let me, !rows.contains(where: \.isMe) {
                rows.append(LeaderboardEntry(id: me, nickname: nickname ?? "?", points: progress.weeklyPoints,
                                             level: progress.level, division: progress.division, isMe: true))
            }
            entries[scope] = rows.sorted { $0.points > $1.points }
        } catch {
            // A brand-new league has no Player records yet, which CloudKit reports as an error.
            entries[scope] = []
        }
    }

    /// The players this player added, and the players who added this player.
    private func friendRecords() async throws -> [CKRecord] {
        let me = try await myRecordID()
        var records: [String: CKRecord] = [:]
        let added = friendIDs.map { CKRecord.ID(recordName: $0) }
        if !added.isEmpty {
            for (id, result) in try await database.records(for: added) {
                if let record = try? result.get() { records[id.recordName] = record }
            }
        }
        let addedMe = try await query(NSPredicate(format: "%K CONTAINS %@", Field.friends, me.recordName), sortedBy: nil, limit: 100)
        for record in addedMe where !unfriendedIDs.contains(record.recordID.recordName) {
            records[record.recordID.recordName] = record
        }
        return Array(records.values)
    }

    /// Reports a player for review and hides them.
    func report(_ entry: LeaderboardEntry) async {
        let report = CKRecord(recordType: "Report")
        report["reportedPlayer"] = entry.id
        report["nickname"] = entry.nickname
        report["reason"] = "inappropriate-nickname"
        _ = try? await database.save(report)
        block(entry)
    }

    func block(_ entry: LeaderboardEntry) {
        blockedIDs.insert(entry.id)
        UserDefaults.standard.set(Array(blockedIDs), forKey: Keys.blocked)
        for scope in Scope.allCases {
            entries[scope]?.removeAll { $0.id == entry.id }
        }
    }

    private func myRecordID() async throws -> CKRecord.ID {
        if let playerRecordName { return CKRecord.ID(recordName: playerRecordName) }
        let user = try await container.userRecordID()
        let name = "player-\(user.recordName)"
        playerRecordName = name
        return CKRecord.ID(recordName: name)
    }

    /// Records matching `predicate`, best first when sorted. Lookups pass no sort key, which needs no sortable index.
    private func query(_ predicate: NSPredicate, sortedBy key: String? = Field.weeklyPoints, limit: Int) async throws -> [CKRecord] {
        let query = CKQuery(recordType: Field.type, predicate: predicate)
        if let key {
            query.sortDescriptors = [NSSortDescriptor(key: key, ascending: false)]
        }
        let (results, _) = try await database.records(matching: query, resultsLimit: limit)
        return results.compactMap { try? $0.1.get() }
    }
}
