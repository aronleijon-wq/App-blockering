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

    static func updateRuntime(_ change: (inout PausRuntime) -> Void) {
        var value = runtime
        change(&value)
        runtime = value
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
