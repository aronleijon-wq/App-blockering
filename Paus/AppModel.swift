import FamilyControls
import Foundation
import Observation
import UserNotifications

/// App-side state. Every change is written to `SharedStore` and followed by a shield refresh,
/// because the extensions read the same store while the app isn't running.
@MainActor
@Observable
final class AppModel {
    enum Tab: Hashable {
        case today, apps, rules
    }

    var selectedTab: Tab = .today
    var authorizationStatus: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    private(set) var selection: FamilyActivitySelection = SharedStore.selection
    private(set) var rules: PausRules = SharedStore.rules
    private(set) var runtime: PausRuntime = SharedStore.runtime
    var isPauseSheetPresented = false
    var errorMessage: String?

    var engine: BlockEngine { BlockEngine(rules: rules, runtime: runtime) }
    var isAuthorized: Bool { authorizationStatus == .approved }
    var hasSelection: Bool { !selection.isEmpty }

    var isStrictFocusActive: Bool {
        guard rules.strictFocus, let end = runtime.focusEndsAt else { return false }
        return end > .now
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            errorMessage = "Paus fick inte tillgång till Skärmtid. Försök igen."
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        guard isAuthorized else { return }
        // Needed for the shield's pause button, which reaches the app through a notification.
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        reload()
    }

    /// Picks up changes the extensions made and makes sure monitoring and the shield match the rules.
    func reload() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        runtime = SharedStore.runtime
        guard isAuthorized else { return }

        if !ActivityScheduler.isInSync(rules: rules, selection: selection) {
            resyncMonitoring()
        }
        ShieldController.refresh()

        if let requested = runtime.pauseRequestedAt {
            updateRuntime { $0.pauseRequestedAt = nil }
            if Date.now.timeIntervalSince(requested) < 120, engine.canPause(at: .now) {
                isPauseSheetPresented = true
            }
        }
    }

    func saveSelection(_ newSelection: FamilyActivitySelection) {
        guard newSelection != selection, !isStrictFocusActive else { return }
        selection = newSelection
        SharedStore.selection = newSelection
        resyncMonitoring()
        ShieldController.refresh()
    }

    func updateRules(_ change: (inout PausRules) -> Void) {
        let old = rules
        var new = rules
        change(&new)
        guard new != old else { return }
        if isStrictFocusActive, !new.strictFocus { new.strictFocus = true }
        rules = new
        SharedStore.rules = new

        if new.dailyLimitMinutes != old.dailyLimitMinutes {
            // Monitoring restarts below and reports the new limit if it has already been used up.
            updateRuntime { $0.limitReachedDay = nil }
        }
        // Re-registering can reset limit counting on older iOS versions, so only do it when needed.
        if new.schedules != old.schedules || new.dailyLimitMinutes != old.dailyLimitMinutes {
            resyncMonitoring()
        }
        ShieldController.refresh()
    }

    func saveSchedule(_ schedule: BlockSchedule) {
        updateRules { rules in
            if let index = rules.schedules.firstIndex(where: { $0.id == schedule.id }) {
                rules.schedules[index] = schedule
            } else {
                rules.schedules.append(schedule)
            }
        }
    }

    func deleteSchedule(id: UUID) {
        updateRules { $0.schedules.removeAll { $0.id == id } }
    }

    func startFocus(minutes: Int) {
        guard hasSelection else { return }
        let end = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        do {
            try ActivityScheduler.startFocus(until: end)
        } catch {
            errorMessage = "Fokuspasset kunde inte startas (\(error.localizedDescription))."
            return
        }
        updateRuntime { $0.focusEndsAt = end }
        ShieldController.refresh()
    }

    func stopFocus() {
        guard !isStrictFocusActive else { return }
        ActivityScheduler.stopFocus()
        updateRuntime { $0.focusEndsAt = nil }
        ShieldController.refresh()
    }

    func takePause() {
        let now = Date.now
        guard engine.canPause(at: now) else { return }
        let end = now.addingTimeInterval(TimeInterval(rules.pause.minutes * 60))
        // Schedule the re-block first: without it the shield would stay down after the pause.
        do {
            try ActivityScheduler.startPause(until: end)
        } catch {
            errorMessage = "Pausen kunde inte startas (\(error.localizedDescription))."
            return
        }
        updateRuntime { $0.startPause(at: now, until: end, calendar: .current) }
        ShieldController.refresh()
    }

    func endPause() {
        ActivityScheduler.stopPause()
        updateRuntime { $0.pausedUntil = nil }
        ShieldController.refresh()
    }

    private func updateRuntime(_ change: (inout PausRuntime) -> Void) {
        SharedStore.updateRuntime(change)
        runtime = SharedStore.runtime
    }

    private func resyncMonitoring() {
        do {
            try ActivityScheduler.sync()
        } catch {
            errorMessage = "Scheman och daglig gräns kunde inte startas (\(error.localizedDescription))."
        }
    }
}
