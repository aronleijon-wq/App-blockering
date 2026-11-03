import Foundation

/// App versions such as "2.6" and "2.10.1", compared part by part as numbers.
enum AppVersion {
    static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }

    /// Whether `version` is older than `other`: "2.9" is older than "2.10", and "2.6" is the same as "2.6.0".
    static func isOlder(_ version: String, than other: String) -> Bool {
        let a = parts(version)
        let b = parts(other)
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x < y }
        }
        return false
    }

    /// What to ask of the user: nothing, to update when they like, or to update before going on.
    enum Need: Equatable {
        case none
        case optional(latest: String)
        case required(minimum: String)
    }

    /// `current` against the newest version in the App Store and the oldest still allowed in.
    static func need(current: String, latest: String?, minimum: String?) -> Need {
        if let minimum, isOlder(current, than: minimum) { return .required(minimum: minimum) }
        if let latest, isOlder(current, than: latest) { return .optional(latest: latest) }
        return .none
    }
}
