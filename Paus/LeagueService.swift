import CloudKit
import Foundation
import Observation

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

    var canCompete: Bool { accountState == .available && nickname != nil }

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
        UserDefaults.standard.removeObject(forKey: Keys.nickname)
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

    /// Publishes the player's nickname, friend code and friends, and their week once it has points.
    /// Skips the upload when nothing visible changed.
    func upload(_ progress: PlayerProgress) async throws {
        guard let nickname else { return }
        let friends = friendIDs.sorted()
        let week = progress.weekKey.flatMap { progress.weeklyPoints > 0 ? $0 : nil }
        let signature = "\(nickname)|\(friendCode)|\(friends)|\(week ?? "")|\(progress.weeklyPoints)|\(progress.level)|\(progress.division.rawValue)"
        guard signature != uploadedSignature else { return }

        let record = CKRecord(recordType: Field.type, recordID: try await myRecordID())
        record[Field.nickname] = nickname
        record[Field.friendCode] = friendCode
        // CloudKit can't store an empty list, so a player without friends gets none.
        if friends.isEmpty {
            record[Field.friends] = nil
        } else {
            record[Field.friends] = friends
        }
        if let week {
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

    // MARK: Friends

    /// Adds the player with `code` as a friend. They see this player too, without adding back.
    func addFriend(code: String) async throws {
        let code = FriendCode.normalized(code)
        guard code != friendCode else { throw FriendError.ownCode }
        let me = try await myRecordID().recordName
        let matches = try await query(NSPredicate(format: "%K == %@", Field.friendCode, code), sortedBy: nil, limit: 1)
        guard let id = matches.first?.recordID.recordName, id != me else { throw FriendError.notFound }
        friendIDs.insert(id)
        unfriendedIDs.remove(id)
        saveFriends()
        uploadedSignature = nil
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
                    nickname: isMe ? nickname ?? "?" : record[Field.nickname] as? String ?? "?",
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
