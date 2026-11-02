import ActivityKit
import Foundation
import WidgetKit

/// The Live Activity on the lock screen and in the Dynamic Island: what is blocked or paused, and for how long.
struct PausActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: PausStatus
        var health: Int
        /// Pip's level and the streak, for Pip's colors and the flame. Missing in activities from older versions.
        var level: Int? = nil
        var streak: Int? = nil
    }
}

enum WidgetRefresher {
    /// Lets the widgets redraw after the rules, a block or Pip's health changed.
    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
