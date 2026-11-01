import Foundation

/// The emergency way out of every block. It ends a running focus or step session and lifts schedules
/// and the daily limit for a while, at a price in points, XP and Pip's health that rises with each use.
enum SOS {
    static let minutes = 15
}

enum BlockReason: Equatable {
    case focus(until: Date)
    /// A focus session that ends once enough steps are walked rather than at a time.
    case stepFocus(goal: Int)
    case schedule(name: String, until: Date)
    case dailyLimit(minutes: Int)
    /// The guarded apps are blocked except for a few opens a day from the shield.
    case openLimit(left: Int)
    /// An iPhone Focus, such as Work or Sleep, is on and blocks with Paus.
    case focusMode
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
            if let goal = runtime.focusStepGoal { return .stepFocus(goal: goal) }
            return .focus(until: end)
        }
        // On vacation only a focus session the user starts blocks anything.
        if rules.isOnVacation(at: date) { return nil }
        if runtime.focusModeOn { return .focusMode }
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
        if let opens = rules.openLimit {
            return .openLimit(left: max(0, opens - runtime.opens(on: date, calendar: calendar)))
        }
        return nil
    }

    /// Whether an app opened from the shield is open right now.
    func isOpenWindow(at date: Date) -> Bool {
        guard let end = runtime.openUntil else { return false }
        return end > date
    }

    /// Whether the shield can open an app now: under the open limit, with opens left and none open already.
    func canOpenApp(at date: Date) -> Bool {
        guard case .openLimit(let left) = reason(at: date), left > 0 else { return false }
        return !isOpenWindow(at: date)
    }

    func isPaused(at date: Date) -> Bool {
        guard let end = runtime.pausedUntil else { return false }
        return end > date
    }

    func isSOS(at date: Date) -> Bool {
        guard let end = runtime.sosUntil else { return false }
        return end > date
    }

    /// Whether the shield should be up at `date`. A pause lifts every block except strict focus. An SOS lifts
    /// schedules and the daily limit; it ends the focus session that was running, so a later one still blocks.
    func shouldShield(at date: Date, scheduleOverrides: [UUID: Bool] = [:]) -> Bool {
        guard let reason = reason(at: date, scheduleOverrides: scheduleOverrides) else { return false }
        if isSOS(at: date), !isFocus(reason) { return false }
        guard isPaused(at: date) else { return true }
        return isStrictFocus(reason)
    }

    /// Whether SOS can lift anything right now: always, while something is shielded.
    func canSOS(at date: Date) -> Bool {
        shouldShield(at: date)
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

    private func isFocus(_ reason: BlockReason) -> Bool {
        switch reason {
        case .focus, .stepFocus: return true
        default: return false
        }
    }

    private func isStrictFocus(_ reason: BlockReason) -> Bool {
        switch reason {
        case .focus: return rules.strictFocus
        // Steps are the only way out of a step session.
        case .stepFocus: return true
        default: return false
        }
    }
}
