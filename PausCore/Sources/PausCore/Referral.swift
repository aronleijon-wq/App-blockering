import Foundation

/// Inviting friends. The first code a player adds counts as their invite, and both get free Pro days:
/// the new player right away, and the one who invited them once the new player has finished a focus session.
enum Referral {
    static let bonusDays = 5
    /// Invites stop earning after about a year of free Pro.
    static let maxRewardedFriends = 73

    /// `until` pushed `days` further, counting from `now` when it has already passed.
    static func extend(_ until: Date?, byDays days: Int, from now: Date) -> Date {
        max(until ?? now, now).addingTimeInterval(TimeInterval(days * 86_400))
    }
}
