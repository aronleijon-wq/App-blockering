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
        case group, sweden, world

        var id: Self { self }

        var title: String {
            switch self {
            case .group: return "Min grupp"
            case .sweden: return "Sverige"
            case .world: return "Världen"
            }
        }
    }

    enum AccountState {
        case unknown, available, unavailable
    }

    private enum Keys {
        static let nickname = "league.nickname"
        static let blocked = "league.blocked"
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
    }

    private(set) var accountState: AccountState = .unknown
    private(set) var entries: [Scope: [LeaderboardEntry]] = [:]
    private(set) var loadingScope: Scope?
    private(set) var nickname: String?
    private(set) var blockedIDs: Set<String>

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

    /// The newest group in the division with room left, or a new one. Groups fill up as players become active,
    /// so nobody waits for a server to sort them.
    func findGroup(weekKey: String, division: Division) async throws -> String {
        let newest = try await query(
            NSPredicate(format: "%K == %@ AND %K == %d", Field.weekKey, weekKey, Field.division, division.rawValue),
            sortedBy: Field.joinedAt,
            limit: 1
        )
        if let groupID = newest.first?[Field.groupID] as? String, !groupID.isEmpty {
            let members = try await query(NSPredicate(format: "%K == %@ AND %K == %@", Field.weekKey, weekKey, Field.groupID, groupID), limit: League.groupSize)
            if members.count < League.groupSize { return groupID }
        }
        return "\(weekKey)-\(division.rawValue)-\(UUID().uuidString.prefix(8))"
    }

    /// Publishes the player's week. Skips the upload when nothing visible changed.
    func upload(_ progress: PlayerProgress) async throws {
        guard let nickname, let weekKey = progress.weekKey, let groupID = progress.leagueGroupID else { return }
        let signature = "\(nickname)|\(weekKey)|\(progress.weeklyPoints)|\(progress.level)|\(progress.division.rawValue)|\(groupID)"
        guard signature != uploadedSignature else { return }

        let record = CKRecord(recordType: Field.type, recordID: try await myRecordID())
        record[Field.nickname] = nickname
        record[Field.weekKey] = weekKey
        record[Field.weeklyPoints] = progress.weeklyPoints
        record[Field.level] = progress.level
        record[Field.division] = progress.division.rawValue
        record[Field.groupID] = groupID
        record[Field.country] = Locale.current.region?.identifier ?? "SE"
        if groupID != uploadedGroupID {
            record[Field.joinedAt] = Date.now
        }
        // Changed keys only, so the record can be saved without fetching it first.
        let (results, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys, atomically: false)
        if case .failure(let error) = results[record.recordID] { throw error }
        uploadedSignature = signature
        uploadedGroupID = groupID
    }

    func load(_ scope: Scope, progress: PlayerProgress) async {
        guard let weekKey = progress.weekKey else { return }
        let predicate: NSPredicate
        switch scope {
        case .group:
            guard let groupID = progress.leagueGroupID else {
                entries[scope] = []
                return
            }
            predicate = NSPredicate(format: "%K == %@ AND %K == %@", Field.weekKey, weekKey, Field.groupID, groupID)
        case .sweden:
            predicate = NSPredicate(format: "%K == %@ AND %K == %@", Field.weekKey, weekKey, Field.country, "SE")
        case .world:
            predicate = NSPredicate(format: "%K == %@", Field.weekKey, weekKey)
        }
        loadingScope = scope
        defer { loadingScope = nil }
        do {
            let records = try await query(predicate, limit: scope == .group ? League.groupSize + 10 : 100)
            let me = try? await myRecordID().recordName
            entries[scope] = records.compactMap { record in
                guard !blockedIDs.contains(record.recordID.recordName) else { return nil }
                return LeaderboardEntry(
                    id: record.recordID.recordName,
                    nickname: record[Field.nickname] as? String ?? "?",
                    points: record[Field.weeklyPoints] as? Int ?? 0,
                    level: record[Field.level] as? Int ?? 1,
                    division: Division(rawValue: record[Field.division] as? Int ?? 0) ?? .brons,
                    isMe: record.recordID.recordName == me
                )
            }
        } catch {
            // A brand-new league has no Player records yet, which CloudKit reports as an error.
            entries[scope] = []
        }
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

    private func query(_ predicate: NSPredicate, sortedBy key: String = Field.weeklyPoints, limit: Int) async throws -> [CKRecord] {
        let query = CKQuery(recordType: Field.type, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: key, ascending: false)]
        let (results, _) = try await database.records(matching: query, resultsLimit: limit)
        return results.compactMap { try? $0.1.get() }
    }
}
