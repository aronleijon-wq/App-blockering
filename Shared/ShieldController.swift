// Screen Time code, which the widgets leave out since they have no Family Controls entitlement.
#if !WIDGET_EXTENSION
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
        let rules = SharedStore.effectiveRules
        let engine = BlockEngine(rules: rules, runtime: SharedStore.runtime)
        if engine.shouldShield(at: date, scheduleOverrides: scheduleOverrides) {
            apply(SharedStore.selection)
            // Without this, deleting and reinstalling Paus would be the easy way out of a block.
            store.application.denyAppRemoval = rules.preventUninstall ? true : nil
        } else {
            store.clearAllSettings()
        }
        store.webContent.blockedByFilter = rules.adultFilter ? .auto() : nil
        WidgetRefresher.reload()
    }

    private static func apply(_ selection: FamilyActivitySelection) {
        let categories = selection.categoryTokens
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }
}
#endif
