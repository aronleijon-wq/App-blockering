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
    var opponentLevel = 1
    var opponentOutfit: Outfit = .none
}

struct LeaderboardEntry: Identifiable, Equatable {
    let id: String
    let nickname: String
    let points: Int
    let level: Int
    let division: Division
    let isMe: Bool
    /// What the player's Pip wears, so everyone in the league sees it.
    var outfit: Outfit = .none
    /// All the XP the player has earned, for the all-time leaderboard.
    var xp = 0
}

/// The league in CloudKit's public database. Each player owns one `Player` record per device account,
/// which only that player can change; everyone can read them.
@MainActor
@Observable
final class LeagueService {
    enum Scope: String, CaseIterable, Identifiable {
        case friends, country, world

        var id: Self { self }

        var title: String {
            switch self {
            case .friends: return L("Vänner")
            case .country: return "\(Country.flag(LeagueService.countryCode)) " + L("Mitt land")
            case .world: return L("Världen")
            }
        }
    }

    /// Which stretch of time a leaderboard covers.
    enum Period: String, CaseIterable, Identifiable {
        case week, allTime

        var id: Self { self }

        var title: String {
            switch self {
            case .week: return L("Den här veckan")
            case .allTime: return L("Genom tiderna")
            }
        }
    }

    struct Board: Hashable {
        let scope: Scope
        let period: Period
    }

    /// The country this player competes for: the phone's region, so it matches what was uploaded.
    nonisolated static var countryCode: String { Country.code(from: Locale.current.region?.identifier) }

    /// The player's country in the app's language, such as "Norge" or "Norway".
    nonisolated static var countryName: String {
        Language.current.locale.localizedString(forRegionCode: countryCode) ?? countryCode
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
        /// The player's Pip outfit, as `Outfit.code`.
        static let outfit = "outfit"
        /// All the XP the player has earned. Queryable and sortable, for the all-time leaderboard.
        static let totalXP = "totalXP"
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
    private(set) var entries: [Board: [LeaderboardEntry]] = [:]
    private(set) var loadingBoard: Board?
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
    /// False once CloudKit has refused the outfit field, which happens until it is deployed to Production.
    @ObservationIgnored private var sendsOutfit = true
    /// The same for the all-time XP field.
    @ObservationIgnored private var sendsTotalXP = true

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
        let signature = "\(lastWeek?.weekKey ?? "")|\(lastWeek?.points ?? 0)|\(nickname ?? "")|\(friendCode)|\(friends)|\(invitedBy ?? "")|\(qualified)|\(week ?? "")|\(progress.weeklyPoints)|\(progress.level)|\(progress.division.rawValue)|\(progress.outfit.code)|\(progress.xp)"
        guard signature != uploadedSignature else { return }

        let recordID = try await myRecordID()
        // Until a new field is deployed to the Production schema, CloudKit refuses records that carry it. The league
        // keeps working without that field then: first without all-time XP, then without the outfit, then without both.
        var attempts: [(outfit: Bool, totalXP: Bool)] = [(sendsOutfit, sendsTotalXP)]
        if sendsTotalXP { attempts.append((sendsOutfit, false)) }
        if sendsOutfit { attempts.append((false, sendsTotalXP)) }
        if sendsOutfit && sendsTotalXP { attempts.append((false, false)) }
        var failure: Error?
        for attempt in attempts {
            do {
                try await savePlayer(playerRecord(recordID, progress: progress, outfit: attempt.outfit, totalXP: attempt.totalXP))
                sendsOutfit = attempt.outfit
                sendsTotalXP = attempt.totalXP
                failure = nil
                break
            } catch {
                failure = error
            }
        }
        if let failure { throw failure }
        uploadedSignature = signature
        uploadedGroupID = progress.leagueGroupID
    }

    private func savePlayer(_ record: CKRecord) async throws {
        // Changed keys only, so the record can be saved without fetching it first.
        let (results, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys, atomically: false)
        if case .failure(let error) = results[record.recordID] { throw error }
    }

    private func playerRecord(_ recordID: CKRecord.ID, progress: PlayerProgress, outfit: Bool, totalXP: Bool) -> CKRecord {
        let friends = friendIDs.sorted()
        let week = progress.weekKey.flatMap { progress.weeklyPoints > 0 ? $0 : nil }
        let qualified = progress.focusSessions > 0
        let lastWeek = progress.lastWeek
        let record = CKRecord(recordType: Field.type, recordID: recordID)
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
            record[Field.country] = Self.countryCode
            // Kept for players who joined a group before friends replaced groups, so last week can be settled.
            if let groupID = progress.leagueGroupID, groupID != uploadedGroupID {
                record[Field.groupID] = groupID
                record[Field.joinedAt] = Date.now
            }
        }
        if outfit, nickname != nil {
            record[Field.outfit] = progress.outfit.code
        }
        // Every league player is on the all-time leaderboard, also in weeks without points.
        if totalXP, nickname != nil {
            record[Field.totalXP] = progress.xp
            record[Field.level] = progress.level
            record[Field.country] = Self.countryCode
        }
        return record
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
            return DuelStanding(id: "\(weekKey)-\(id)", opponentID: id, opponentName: record?[Field.nickname] as? String ?? L("Ny spelare"), mine: mine, theirs: theirs,
                                opponentLevel: record?[Field.level] as? Int ?? 1, opponentOutfit: Outfit(code: record?[Field.outfit] as? String))
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

    func load(_ scope: Scope, period: Period = .week, progress: PlayerProgress) async {
        guard let weekKey = progress.weekKey else { return }
        let board = Board(scope: scope, period: period)
        loadingBoard = board
        defer { loadingBoard = nil }
        do {
            let records: [CKRecord]
            let anyXP = NSPredicate(format: "%K > %@", Field.totalXP, NSNumber(value: 0))
            switch (scope, period) {
            case (.friends, _):
                records = try await friendRecords()
            case (.country, .week):
                records = try await query(NSPredicate(format: "%K == %@ AND %K == %@", Field.weekKey, weekKey, Field.country, Self.countryCode), limit: 100)
            case (.world, .week):
                records = try await query(NSPredicate(format: "%K == %@", Field.weekKey, weekKey), limit: 100)
            case (.country, .allTime):
                let inCountry = NSPredicate(format: "%K == %@", Field.country, Self.countryCode)
                records = try await query(NSCompoundPredicate(andPredicateWithSubpredicates: [inCountry, anyXP]), sortedBy: Field.totalXP, limit: 100)
            case (.world, .allTime):
                records = try await query(anyXP, sortedBy: Field.totalXP, limit: 100)
            }
            let me = try? await myRecordID().recordName
            var rows = records.compactMap { record -> LeaderboardEntry? in
                guard !blockedIDs.contains(record.recordID.recordName) else { return nil }
                let isMe = record.recordID.recordName == me
                // A friend who hasn't scored this week still shows last week's numbers in CloudKit.
                let thisWeek = record[Field.weekKey] as? String == weekKey
                let theirXP: Int = record[Field.totalXP] as? Int ?? 0
                // CloudKit can take a while to return a record that was just saved, so the player's own
                // row always shows what this phone knows.
                return LeaderboardEntry(
                    id: record.recordID.recordName,
                    nickname: isMe ? nickname ?? "?" : record[Field.nickname] as? String ?? L("Ny spelare"),
                    points: isMe ? progress.weeklyPoints : thisWeek ? record[Field.weeklyPoints] as? Int ?? 0 : 0,
                    level: isMe ? progress.level : record[Field.level] as? Int ?? 1,
                    division: isMe ? progress.division : Division(rawValue: record[Field.division] as? Int ?? 0) ?? .brons,
                    isMe: isMe,
                    outfit: isMe ? progress.outfit : Outfit(code: record[Field.outfit] as? String),
                    xp: isMe ? progress.xp : theirXP
                )
            }
            if scope == .friends, let me, !rows.contains(where: \.isMe) {
                rows.append(LeaderboardEntry(id: me, nickname: nickname ?? "?", points: progress.weeklyPoints,
                                             level: progress.level, division: progress.division, isMe: true, outfit: progress.outfit,
                                             xp: progress.xp))
            }
            switch period {
            case .week: entries[board] = rows.sorted { $0.points > $1.points }
            case .allTime: entries[board] = rows.sorted { $0.xp > $1.xp }
            }
        } catch {
            // A brand-new league has no Player records yet, and CloudKit refuses a query on a field it doesn't
            // know yet. Both show as an empty list.
            entries[board] = []
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
        for board in Array(entries.keys) {
            entries[board]?.removeAll { $0.id == entry.id }
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
