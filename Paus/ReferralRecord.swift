import Foundation
import Security

/// What free Pro from invites depends on: when the free days run out, which invited friends have already earned
/// them, and who invited this player. Kept in the keychain as well as on the phone. The keychain survives deleting
/// Paus and follows the user to a new phone through iCloud Keychain, so reinstalling neither loses earned days nor
/// lets the same friends earn them again.
enum ReferralRecord {
    private struct Saved: Codable, Equatable {
        var bonusUntil: Date?
        var rewardedInvites: Set<String> = []
        var invitedBy: String?
    }

    private static let keychainKey = "referral"
    private static let rewardedKey = "league.rewardedInvites"
    private static let invitedByKey = "league.invitedBy"

    /// When the free Pro days run out.
    static var bonusUntil: Date? { current().bonusUntil }

    /// Who invited this player: the first player whose code they added.
    static var invitedBy: String? {
        get { current().invitedBy }
        set { update { $0.invitedBy = newValue } }
    }

    /// Invited friends who have already earned free Pro. Throws while the keychain is locked, so nobody is
    /// rewarded again because of a list that only looks empty.
    static func rewardedInvites() throws -> Set<String> {
        try merged(SecureStore.value(Saved.self, forKey: keychainKey)).rewardedInvites
    }

    static func addRewardedInvites(_ ids: some Sequence<String>) {
        update { $0.rewardedInvites.formUnion(ids) }
    }

    /// Adds `days` of free Pro and returns when it now runs out.
    static func extendBonus(byDays days: Int) -> Date {
        var until = Date.now
        update {
            until = Referral.extend($0.bonusUntil, byDays: days, from: .now)
            $0.bonusUntil = until
        }
        return until
    }

    /// Copies what is only on the phone into the keychain, for players who earned free Pro before it was kept there.
    static func backUp() {
        update { _ in }
    }

    /// The keychain and the phone merged, or the phone alone while the keychain is locked.
    private static func current() -> Saved {
        merged(try? SecureStore.value(Saved.self, forKey: keychainKey))
    }

    /// The later end date, every rewarded friend, and whichever invite is known.
    private static func merged(_ stored: Saved?) -> Saved {
        var saved = stored ?? Saved()
        if let local = SharedStore.proBonusUntil, local > saved.bonusUntil ?? .distantPast {
            saved.bonusUntil = local
        }
        saved.rewardedInvites.formUnion(UserDefaults.standard.stringArray(forKey: rewardedKey) ?? [])
        if saved.invitedBy == nil {
            saved.invitedBy = UserDefaults.standard.string(forKey: invitedByKey)
        }
        return saved
    }

    /// Changes the record in both places. While the keychain is locked only the phone is written, so the keychain is
    /// never overwritten with less than it holds.
    private static func update(_ change: (inout Saved) -> Void) {
        let stored = Result { try SecureStore.value(Saved.self, forKey: keychainKey) }
        var saved = merged(try? stored.get())
        change(&saved)
        SharedStore.proBonusUntil = saved.bonusUntil
        UserDefaults.standard.set(saved.rewardedInvites.sorted(), forKey: rewardedKey)
        UserDefaults.standard.set(saved.invitedBy, forKey: invitedByKey)
        if case .success(let old) = stored, old != saved {
            SecureStore.set(saved, forKey: keychainKey)
        }
    }
}

/// Codable values in the keychain, synced through iCloud Keychain when it is on.
enum SecureStore {
    /// The keychain can't be read before the phone is first unlocked after a restart.
    struct Locked: Error {}

    private static let service = "paus.secure"

    /// The value for `key`, or nil when there is none or the keychain can't be used at all.
    static func value<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        var lookup = query(key)
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecInteractionNotAllowed { throw Locked() }
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func set<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let status = SecItemUpdate(query(key) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else { return }
        var item = query(key)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }

    private static func query(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: true,
        ]
    }
}
