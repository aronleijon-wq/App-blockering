import FamilyControls
import Foundation

enum AppGroup {
    /// Read from the `PausAppGroup` Info.plist key, which build settings derive from `PAUS_BUNDLE_PREFIX`,
    /// so the app and every extension resolve the same group.
    static let identifier: String =
        Bundle.main.object(forInfoDictionaryKey: "PausAppGroup") as? String ?? "group.se.aronleijon.paus"

    static var defaults: UserDefaults { UserDefaults(suiteName: identifier) ?? .standard }
}

/// Rules, runtime state and the selected apps, stored in the App Group so the app and its extensions share them.
enum SharedStore {
    private static let rulesKey = "rules"
    private static let runtimeKey = "runtime"
    private static let selectionKey = "selection"
    private static let progressKey = "progress"
    private static let proKey = "isPro"
    private static let wasAuthorizedKey = "wasAuthorized"
    private static let notificationSettingsKey = "notificationSettings"

    static var rules: PausRules {
        get { load(rulesKey) ?? PausRules() }
        set { save(newValue, forKey: rulesKey) }
    }

    static var runtime: PausRuntime {
        get { load(runtimeKey) ?? PausRuntime() }
        set { save(newValue, forKey: runtimeKey) }
    }

    static var selection: FamilyActivitySelection {
        get { load(selectionKey) ?? FamilyActivitySelection() }
        set { save(newValue, forKey: selectionKey) }
    }

    static var progress: PlayerProgress {
        get { load(progressKey) ?? PlayerProgress() }
        set { save(newValue, forKey: progressKey) }
    }

    /// Mirrors the app's StoreKit entitlement so the extensions apply the same rules.
    static var isPro: Bool {
        get { AppGroup.defaults.bool(forKey: proKey) }
        set { AppGroup.defaults.set(newValue, forKey: proKey) }
    }

    /// Whether Paus had Screen Time access last time it checked, to notice when it is turned off.
    static var wasAuthorized: Bool {
        get { AppGroup.defaults.bool(forKey: wasAuthorizedKey) }
        set { AppGroup.defaults.set(newValue, forKey: wasAuthorizedKey) }
    }

    static var notificationSettings: NotificationSettings {
        get { load(notificationSettingsKey) ?? NotificationSettings() }
        set { save(newValue, forKey: notificationSettingsKey) }
    }

    /// The rules actually enforced, with Pro-only features dropped for free users.
    static var effectiveRules: PausRules { rules.effective(isPro: isPro) }

    /// Erases everything Paus stores about the user on this device, except the Pro entitlement mirror.
    static func eraseUserData() {
        for key in [rulesKey, runtimeKey, selectionKey, progressKey, wasAuthorizedKey, notificationSettingsKey] {
            AppGroup.defaults.removeObject(forKey: key)
        }
    }

    static func updateRuntime(_ change: (inout PausRuntime) -> Void) {
        var value = runtime
        change(&value)
        runtime = value
    }

    /// Reads the latest progress before changing it, since the extensions write it too.
    @discardableResult
    static func updateProgress(_ change: (inout PlayerProgress) -> [Reward]) -> [Reward] {
        var value = progress
        let rewards = change(&value)
        progress = value
        return rewards
    }

    private static func load<Value: Decodable>(_ key: String) -> Value? {
        guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    private static func save<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }
}

extension FamilyActivitySelection {
    var isEmpty: Bool {
        applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
    }
}
