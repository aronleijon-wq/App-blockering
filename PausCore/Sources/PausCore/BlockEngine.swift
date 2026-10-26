import Foundation

enum BlockReason: Equatable {
    case focus(until: Date)
    case schedule(name: String, until: Date)
    case dailyLimit(minutes: Int)
}

/// Decides whether the selected apps should be blocked. The app and every extension use it,
/// so they all agree no matter which process changed the state last.
struct BlockEngine {
    var rules: PausRules
    var runtime: PausRuntime
    var calendar: Calendar = .current

    /// Why the apps are blocked at `date`, ignoring pauses. Focus wins over schedules, which win over the daily limit.
    ///
    /// `scheduleOverrides` comes from DeviceActivity callbacks for a schedule boundary: `true` evaluates that
    /// schedule a minute later and `false` treats it as ended, so a callback a few seconds early can't flip the result.
    func reason(at date: Date, scheduleOverrides: [UUID: Bool] = [:]) -> BlockReason? {
        if let end = runtime.focusEndsAt, end > date {
            return .focus(until: end)
        }
        // On vacation only a focus session the user starts blocks anything.
        if rules.isOnVacation(at: date) { return nil }
        for schedule in rules.schedules {
            let override = scheduleOverrides[schedule.id]
            if override == false { continue }
            let probe = override == true ? date.addingTimeInterval(60) : date
            if let window = schedule.activeWindow(containing: probe, calendar: calendar) {
                return .schedule(name: schedule.name, until: window.end)
            }
        }
        if let limit = rules.dailyLimitMinutes, runtime.limitReachedDay == DayKey.string(for: date, calendar: calendar) {
            return .dailyLimit(minutes: limit)
        }
        return nil
    }

    func isPaused(at date: Date) -> Bool {
        guard let end = runtime.pausedUntil else { return false }
        return end > date
    }

    /// Whether the shield should be up at `date`. A pause lifts every block except strict focus.
    func shouldShield(at date: Date, scheduleOverrides: [UUID: Bool] = [:]) -> Bool {
        guard let reason = reason(at: date, scheduleOverrides: scheduleOverrides) else { return false }
        guard isPaused(at: date) else { return true }
        return isStrictFocus(reason)
    }

    func pausesLeft(at date: Date) -> Int {
        max(0, rules.pause.maxPerDay - runtime.counts(on: date, calendar: calendar).pauses)
    }

    func canPause(at date: Date) -> Bool {
        guard
            rules.pause.isEnabled,
            !isPaused(at: date),
            pausesLeft(at: date) > 0,
            let reason = reason(at: date)
        else { return false }
        return !isStrictFocus(reason)
    }

    /// Whether minutes earned by walking can lift the block at `date`: something has to be blocking, and a strict
    /// focus session can't be walked out of. A running pause can be extended.
    func canSpendSteps(at date: Date) -> Bool {
        guard rules.steps.isEnabled, let reason = reason(at: date) else { return false }
        return !isStrictFocus(reason)
    }

    private func isStrictFocus(_ reason: BlockReason) -> Bool {
        if case .focus = reason { return rules.strictFocus }
        return false
    }
}
