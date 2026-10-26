import Foundation

/// Walking earns minutes in the blocked apps: every `stepsPerUnlock` steps buy `minutesPerUnlock` minutes,
/// up to a cap per day. `walked` is today's step count from Health.
struct StepUnlock {
    var rules: StepRules
    var runtime: PausRuntime
    var calendar: Calendar = .current

    /// Steps walked today that haven't been traded for minutes yet.
    func unspentSteps(walked: Int, at date: Date) -> Int {
        max(0, walked - runtime.stepCounts(on: date, calendar: calendar).steps)
    }

    /// Minutes the cap still allows today.
    func minutesLeftToday(at date: Date) -> Int {
        max(0, rules.maxMinutesPerDay - runtime.stepCounts(on: date, calendar: calendar).minutes)
    }

    /// Minutes the steps walked so far can buy right now.
    func availableMinutes(walked: Int, at date: Date) -> Int {
        guard rules.stepsPerUnlock > 0, rules.minutesPerUnlock > 0 else { return 0 }
        let earned = unspentSteps(walked: walked, at: date) / rules.stepsPerUnlock
        let allowed = minutesLeftToday(at: date) / rules.minutesPerUnlock
        return min(earned, allowed) * rules.minutesPerUnlock
    }

    /// Steps still to walk for the next unlock, or nil once today's cap is used up.
    func stepsToNext(walked: Int, at date: Date) -> Int? {
        guard rules.stepsPerUnlock > 0, minutesLeftToday(at: date) >= rules.minutesPerUnlock + availableMinutes(walked: walked, at: date) else {
            return nil
        }
        return rules.stepsPerUnlock - unspentSteps(walked: walked, at: date) % rules.stepsPerUnlock
    }

    /// The steps `minutes` cost.
    func cost(minutes: Int) -> Int {
        guard rules.minutesPerUnlock > 0 else { return 0 }
        return minutes / rules.minutesPerUnlock * rules.stepsPerUnlock
    }

    /// A few amounts to offer, from one unlock up to everything available.
    func choices(walked: Int, at date: Date) -> [Int] {
        guard rules.minutesPerUnlock > 0 else { return [] }
        let units = availableMinutes(walked: walked, at: date) / rules.minutesPerUnlock
        return Set([1, 2, units].filter { $0 >= 1 && $0 <= units }).sorted().map { $0 * rules.minutesPerUnlock }
    }
}
