import FamilyControls
import Foundation
import ManagedSettings

extension ManagedSettingsStore.Name {
    static let paus = Self("paus")
}

/// Owns the single settings store that shields the selected apps.
enum ShieldController {
    private static let store = ManagedSettingsStore(named: .paus)

    /// Raises or lowers the shield to match the stored rules and runtime state.
    /// Call it after anything that changes them; it is safe to call repeatedly.
    static func refresh(at date: Date = .now, scheduleOverrides: [UUID: Bool] = [:]) {
        let engine = BlockEngine(rules: SharedStore.rules, runtime: SharedStore.runtime)
        if engine.shouldShield(at: date, scheduleOverrides: scheduleOverrides) {
            apply(SharedStore.selection)
        } else {
            store.clearAllSettings()
        }
    }

    private static func apply(_ selection: FamilyActivitySelection) {
        let categories = selection.categoryTokens
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }
}
