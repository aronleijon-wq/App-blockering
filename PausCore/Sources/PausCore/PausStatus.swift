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
    /// For a step session: the goal, the steps walked so far and when they were counted.
    var stepGoal: Int? = nil
    var steps: Int? = nil
    var stepsCheckedAt: Date? = nil

    /// Steps still to walk in a step session.
    var stepsLeft: Int? {
        stepGoal.map { max(0, $0 - (steps ?? 0)) }
    }

    static var free: PausStatus { PausStatus(kind: .free, title: L("Inget blockeras")) }

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
            return PausStatus(kind: .focus, title: L("Fokuspass"), start: runtime.focusStartedAt, end: until)
        case .stepFocus(let goal):
            // Ends with the steps, not at a time, so there is no countdown to show.
            return PausStatus(
                kind: .focus, title: L("Stegpass"), start: runtime.focusStartedAt, end: nil,
                stepGoal: goal, steps: runtime.focusStepsWalked ?? 0, stepsCheckedAt: runtime.focusStepsCheckedAt
            )
        case .schedule(let name, let until):
            return PausStatus(kind: .schedule, title: name, start: nil, end: until)
        case .dailyLimit:
            let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
            return PausStatus(kind: .limit, title: L("Dagens tid är slut"), start: nil, end: midnight)
        }
    }

    var isBlocking: Bool {
        kind == .focus || kind == .schedule || kind == .limit
    }
}
