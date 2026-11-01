import AppIntents
import Foundation

/// A Focus filter: while an iPhone Focus such as Work or Sleep is on, Paus blocks the chosen apps.
/// Added under Settings > Focus > [a Focus] > Focus filters > Paus.
struct PausFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Blockera med Paus"
    static var description: IntentDescription? = IntentDescription("Paus blockerar dina valda appar medan fokusläget är på.")

    /// Off by default: when the Focus ends, the system runs the filter again with default values, which lifts the block.
    @Parameter(title: "Blockera apparna", default: false)
    var block: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: block ? "Blockerar apparna" : "Blockerar inte")
    }

    func perform() async throws -> some IntentResult {
        SharedStore.updateRuntime { $0.focusModeOn = block }
        ShieldController.refresh()
        return .result()
    }
}

/// Starts a focus session from Shortcuts, Siri or an automation, without opening Paus.
struct StartFocusSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Starta fokuspass"
    static var description: IntentDescription? = IntentDescription("Blockerar dina valda appar i ett fokuspass.")
    static var openAppWhenRun = false

    @Parameter(title: "Minuter", default: 25, inclusiveRange: (5, 240))
    var minutes: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let now = Date.now
        let runtime = SharedStore.runtime
        guard !SharedStore.selection.isEmpty else {
            return .result(dialog: "Välj först vilka appar Pip ska vakta i Paus.")
        }
        if let end = runtime.focusEndsAt, end > now {
            return .result(dialog: "Ett fokuspass pågår redan.")
        }
        let end = now.addingTimeInterval(TimeInterval(minutes * 60))
        try ActivityScheduler.startFocus(until: end)
        SharedStore.updateRuntime {
            $0.focusStartedAt = now
            $0.focusEndsAt = end
        }
        ShieldController.refresh()
        Notifier.scheduleFocusDone(at: end, xp: minutes + PlayerProgress.XP.focusBonus)
        return .result(dialog: "Fokuspasset är igång. Pip vaktar dina appar i \(minutes) minuter.")
    }
}

struct PausShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusSessionIntent(),
            phrases: ["Starta fokuspass i \(.applicationName)", "Starta ett fokuspass med \(.applicationName)"],
            shortTitle: "Fokuspass",
            systemImageName: "scope"
        )
    }
}
