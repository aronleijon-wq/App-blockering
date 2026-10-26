import Foundation

/// A focus session that ends once enough steps are walked rather than at a set time. Like strict focus it
/// can't be stopped or paused: walking is the only way out.
enum StepFocus {
    static let goals = [1000, 2000, 5000]
    /// A step session still ends after this long, so a phone that can't count steps doesn't stay locked for good.
    static let backstop: TimeInterval = 24 * 3600
    /// XP grows with the minutes walked up to this many, so a slow session doesn't earn a day's worth.
    static let maxRewardMinutes = 90

    /// The minutes a step session that started at `start` and was walked by `date` is rewarded for.
    static func rewardMinutes(from start: Date, to date: Date) -> Int {
        min(maxRewardMinutes, max(1, Int((date.timeIntervalSince(start) / 60).rounded())))
    }
}
