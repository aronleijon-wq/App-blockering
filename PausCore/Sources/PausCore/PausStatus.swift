import Foundation

/// What Paus is doing right now, for the lock screen and widgets.
struct PausStatus: Codable, Hashable {
    enum Kind: String, Codable {
        case focus, pause, schedule, limit, free
    }

    var kind: Kind
    var title: String
    var start: Date?
    var end: Date?

    static let free = PausStatus(kind: .free, title: "Inget blockeras")

    /// The status at `date`. A pause wins over the block it lifts, except strict focus, which can't be paused.
    static func at(_ date: Date, rules: PausRules, runtime: PausRuntime, calendar: Calendar) -> PausStatus {
        let engine = BlockEngine(rules: rules, runtime: runtime, calendar: calendar)
        guard let reason = engine.reason(at: date) else { return .free }
        if !engine.shouldShield(at: date), let pausedUntil = runtime.pausedUntil {
            let start = pausedUntil.addingTimeInterval(-TimeInterval(rules.pause.minutes * 60))
            return PausStatus(kind: .pause, title: "Paus", start: start, end: pausedUntil)
        }
        switch reason {
        case .focus(let until):
            return PausStatus(kind: .focus, title: "Fokuspass", start: runtime.focusStartedAt, end: until)
        case .schedule(let name, let until):
            return PausStatus(kind: .schedule, title: name, start: nil, end: until)
        case .dailyLimit:
            let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
            return PausStatus(kind: .limit, title: "Dagens tid är slut", start: nil, end: midnight)
        }
    }

    var isBlocking: Bool {
        kind == .focus || kind == .schedule || kind == .limit
    }
}
