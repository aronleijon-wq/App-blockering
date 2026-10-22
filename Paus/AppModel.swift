import AuthenticationServices
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
        case home, league, trophies, apps, rules
    }

    var selectedTab: Tab = .home
    var authorizationStatus: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    private(set) var selection: FamilyActivitySelection = SharedStore.selection
    private(set) var rules: PausRules = SharedStore.rules
    private(set) var runtime: PausRuntime = SharedStore.runtime
    private(set) var progress: PlayerProgress = SharedStore.progress
    private(set) var coachMessage = ""
    var isPauseSheetPresented = false
    var isPaywallPresented = false
    /// Rewards to celebrate on screen; cleared when the celebration is dismissed.
    var celebration: [Reward] = []
    var errorMessage: String?
    /// Set when Paus finds its Screen Time access was turned off since the last launch.
    var isProtectionWarningPresented = false
    private(set) var hasFinishedIntro = IntroStore.isFinished
    private(set) var introAnswers = IntroStore.answers
    private(set) var account = IntroStore.account

    let store = Store()
    let league = LeagueService()
    @ObservationIgnored private var lastLeagueSync: Date?
    /// Screen Time can't be authorized in the Simulator, so there the app skips onboarding to let the design be tried out.
    /// Blocking itself only works on a real iPhone.
    private(set) var isSimulatorPreview = false
    @ObservationIgnored private var coachKey = ""

    init() {
        store.onChange = { [weak self] _ in self?.applyEntitlement() }
    }

    var isPro: Bool { store.isPro }
    /// The rules actually enforced; Pro-only features are dropped for free users.
    var effectiveRules: PausRules { rules.effective(isPro: isPro) }
    var engine: BlockEngine { BlockEngine(rules: effectiveRules, runtime: runtime) }
    var isAuthorized: Bool { authorizationStatus == .approved || isSimulatorPreview }
    var hasSelection: Bool { !selection.isEmpty }

    var isStrictFocusActive: Bool {
        guard effectiveRules.strictFocus, let end = runtime.focusEndsAt else { return false }
        return end > .now
    }

    var mood: MascotMood {
        let now = Date.now
        return MascotMood.current(reason: engine.reason(at: now), isPaused: engine.isPaused(at: now), progress: progress, at: now, calendar: .current)
    }

    /// Free users get one schedule; Pro unlocks more.
    var canAddSchedule: Bool { isPro || rules.schedules.isEmpty }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            #if targetEnvironment(simulator)
            isSimulatorPreview = true
            #else
            errorMessage = "Paus fick inte tillgång till Skärmtid. Försök igen."
            #endif
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        guard isAuthorized else { return }
        // Needed for the daily reminder and for the shield's pause button, which reaches the app through a notification.
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        reload()
    }

    /// Picks up changes the extensions made and makes sure monitoring and the shield match the rules.
    func reload() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        Task { await checkAccount() }
        checkProtection()
        runtime = SharedStore.runtime
        progress = SharedStore.progress
        guard isAuthorized else { return }

        // The monitor normally settles a finished focus session; this covers a missed callback.
        if let end = runtime.focusEndsAt, end <= .now {
            ProgressRecorder.completeFocus()
            runtime = SharedStore.runtime
        }
        SharedStore.updateProgress { [effectiveRules, runtime] progress in
            // Pip gets the night's recovery even on a day without anything else to record.
            progress.recoverOvernight(at: .now, calendar: .current)
            return progress.settleDayUnderLimit(
                limitWasSet: effectiveRules.dailyLimitMinutes != nil,
                limitReachedDay: runtime.limitReachedDay,
                at: .now,
                calendar: .current
            )
        }
        progress = SharedStore.progress

        if !ActivityScheduler.isInSync(rules: effectiveRules, selection: selection) {
            resyncMonitoring()
        }
        ShieldController.refresh()
        scheduleReminder()
        showPendingCelebrations()

        if let requested = runtime.pauseRequestedAt {
            updateRuntime { $0.pauseRequestedAt = nil }
            if Date.now.timeIntervalSince(requested) < 120, engine.canPause(at: .now) {
                isPauseSheetPresented = true
            }
        }
        Task { await store.refresh() }
        Task { await refreshCoach() }
        Task { await syncLeague(force: false) }
    }

    // MARK: Intro and account

    /// Ends the intro, with the answers when the user got as far as giving them.
    func finishIntro(answers: IntroAnswers?) {
        if let answers {
            introAnswers = answers
            IntroStore.answers = answers
        }
        hasFinishedIntro = true
        IntroStore.isFinished = true
    }

    /// Saves the account from Sign in with Apple. Returns whether it worked; cancelling isn't an error.
    @discardableResult
    func signIn(_ result: Result<ASAuthorization, Error>) -> Bool {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return false }
            var signedIn = PausAccount(credential: credential)
            // Signing in again on the same phone doesn't share the name a second time.
            if let account, account.userID == signedIn.userID {
                signedIn.givenName = signedIn.givenName ?? account.givenName
                signedIn.email = signedIn.email ?? account.email
            }
            account = signedIn
            IntroStore.account = signedIn
            return true
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "Inloggningen med Apple misslyckades. Försök igen."
            }
            return false
        }
    }

    /// The first name Pip uses: the one typed in the intro, otherwise the one from Apple.
    var firstName: String? {
        if let name = introAnswers?.name, !name.isEmpty { return name }
        return account?.givenName
    }

    func signOut() {
        account = nil
        IntroStore.account = nil
    }

    /// Signs out when the user has stopped using Sign in with Apple for Paus.
    private func checkAccount() async {
        guard let userID = account?.userID else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
        if state == .revoked || state == .notFound {
            signOut()
        }
    }

    // MARK: Privacy

    /// Deletes the league record, local progress, rules and selection, and lifts every block.
    /// Not offered during strict focus, where it would be a way around the session.
    func deleteAllData() async {
        guard !isStrictFocusActive else { return }
        if league.nickname != nil {
            do {
                try await league.leave()
            } catch {
                errorMessage = "Din ligadata kunde inte raderas just nu. Kontrollera internet och försök igen."
                return
            }
        }
        ActivityScheduler.stopAll()
        SharedStore.eraseUserData()
        signOut()
        introAnswers = nil
        IntroStore.answers = nil
        ShieldController.refresh()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        selection = SharedStore.selection
        rules = SharedStore.rules
        runtime = SharedStore.runtime
        progress = SharedStore.progress
        celebration = []
        selectedTab = .home
    }

    // MARK: League

    /// Settles a finished week, joins this week's group once the player has points and publishes the score.
    func syncLeague(force: Bool) async {
        if !force, let lastLeagueSync, Date.now.timeIntervalSince(lastLeagueSync) < 60 { return }
        lastLeagueSync = .now
        await league.refreshAccount()
        guard league.canCompete else { return }
        do {
            SharedStore.updateProgress { progress in
                progress.rollWeek(at: .now, calendar: .current)
                return []
            }
            if let finished = SharedStore.progress.finishedWeek {
                var standing: (rank: Int, size: Int)?
                if let groupID = finished.groupID {
                    standing = try await league.standing(weekKey: finished.weekKey, groupID: groupID)
                }
                SharedStore.updateProgress { $0.settleFinishedWeek(rank: standing?.rank, groupSize: standing?.size) }
            }

            let current = SharedStore.progress
            if current.leagueGroupID == nil, current.weeklyPoints > 0, let weekKey = current.weekKey {
                let groupID = try await league.findGroup(weekKey: weekKey, division: current.division)
                SharedStore.updateProgress { progress in
                    if progress.weekKey == weekKey, progress.leagueGroupID == nil {
                        progress.leagueGroupID = groupID
                    }
                    return []
                }
            }
            progress = SharedStore.progress
            try await league.upload(progress)
            showPendingCelebrations()
        } catch {
            // The league is a bonus; it retries on the next sync rather than interrupting the user.
            lastLeagueSync = nil
        }
    }

    // MARK: Rewards

    func claimDailyReward() {
        let rewards = ProgressRecorder.record(.claimedDailyReward)
        guard !rewards.isEmpty else { return }
        progress = SharedStore.progress
        celebration = rewards
        scheduleReminder()
        Task { await refreshCoach() }
    }

    func dismissCelebration() {
        celebration = []
        SharedStore.updateProgress { progress in
            progress.pendingRewards = []
            return []
        }
        progress = SharedStore.progress
    }

    /// Turning off Screen Time access is the easiest way around every block, so it costs points and the streak.
    private func checkProtection() {
        #if !targetEnvironment(simulator)
        if authorizationStatus == .approved {
            SharedStore.wasAuthorized = true
        } else if SharedStore.wasAuthorized {
            // The status can read as not determined for a moment at launch, so look again before judging.
            Task {
                try? await Task.sleep(for: .seconds(3))
                let status = AuthorizationCenter.shared.authorizationStatus
                authorizationStatus = status
                guard status != .approved, SharedStore.wasAuthorized else { return }
                SharedStore.wasAuthorized = false
                ProgressRecorder.record(.disabledProtection)
                progress = SharedStore.progress
                isProtectionWarningPresented = true
            }
        }
        #endif
    }

    func recordPauseReason(_ reason: PauseReason) {
        SharedStore.updateProgress { progress in
            progress.recordPauseReason(reason)
            return []
        }
        progress = SharedStore.progress
    }

    func declinePause() {
        ProgressRecorder.record(.declinedPause)
        progress = SharedStore.progress
        showPendingCelebrations()
    }

    private func showPendingCelebrations() {
        guard celebration.isEmpty, !progress.pendingRewards.isEmpty else { return }
        celebration = progress.pendingRewards
    }

    private func refreshCoach() async {
        let now = Date.now
        let currentMood = self.mood
        let key = "\(DayKey.string(for: now, calendar: .current))-\(currentMood.rawValue)-\(progress.level)-\(isPro)"
        guard key != coachKey else { return }
        coachKey = key
        coachMessage = Coach.fallbackMessage(mood: currentMood, progress: progress, at: now)
        if isPro {
            coachMessage = await Coach.message(mood: currentMood, progress: progress, isPro: true, at: now)
        }
    }

    private func scheduleReminder() {
        let now = Date.now
        Reminders.scheduleNext(
            rewardClaimedToday: !progress.canClaimDailyReward(at: now, calendar: .current),
            streak: progress.currentStreak(at: now, calendar: .current),
            now: now
        )
    }

    // MARK: Rules

    func saveSelection(_ newSelection: FamilyActivitySelection) {
        guard newSelection != selection, !isStrictFocusActive else { return }
        selection = newSelection
        SharedStore.selection = newSelection
        resyncMonitoring()
        ShieldController.refresh()
    }

    func updateRules(_ change: (inout PausRules) -> Void) {
        let oldRules = rules
        let oldEffective = effectiveRules
        var new = rules
        change(&new)
        guard new != oldRules else { return }
        if isStrictFocusActive, !new.strictFocus { new.strictFocus = true }
        rules = new
        SharedStore.rules = new

        let newEffective = effectiveRules
        if newEffective.dailyLimitMinutes != oldEffective.dailyLimitMinutes {
            // Monitoring restarts below and reports the new limit if it has already been used up.
            updateRuntime { $0.limitReachedDay = nil }
        }
        // Re-registering can reset limit counting on older iOS versions, so only do it when needed.
        if newEffective.schedules != oldEffective.schedules || newEffective.dailyLimitMinutes != oldEffective.dailyLimitMinutes {
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

    private func applyEntitlement() {
        resyncMonitoring()
        ShieldController.refresh()
        Task { await refreshCoach() }
    }

    // MARK: Focus and pauses

    func startFocus(minutes: Int) {
        guard hasSelection else { return }
        let now = Date.now
        let end = now.addingTimeInterval(TimeInterval(minutes * 60))
        do {
            try ActivityScheduler.startFocus(until: end)
        } catch {
            errorMessage = "Fokuspasset kunde inte startas (\(error.localizedDescription))."
            return
        }
        updateRuntime {
            $0.focusStartedAt = now
            $0.focusEndsAt = end
        }
        ShieldController.refresh()
        Task { await refreshCoach() }
    }

    /// Ends a non-strict focus session early, without XP.
    func stopFocus() {
        guard !isStrictFocusActive else { return }
        ActivityScheduler.stopFocus()
        updateRuntime {
            $0.focusStartedAt = nil
            $0.focusEndsAt = nil
        }
        ShieldController.refresh()
        Task { await refreshCoach() }
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
        ProgressRecorder.record(.tookPause)
        progress = SharedStore.progress
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
