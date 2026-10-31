import SwiftUI
import UIKit

/// The actions in the menu that opens when the app icon is held.
@MainActor
enum QuickAction {
    static let sos = "paus.sos"
    /// Posted with the action's type when one is chosen while Paus runs.
    static let performed = Notification.Name("paus.quick-action")

    /// An action chosen to launch Paus, waiting for the first screen to appear.
    private static var pending: String?

    /// Puts SOS in the app icon's menu. It's set from the app, so it follows the chosen language.
    static func install() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: sos,
                localizedTitle: L("SOS – lås upp"),
                localizedSubtitle: L("Vid en nödsituation."),
                icon: UIApplicationShortcutIcon(systemImageName: "sos"),
                userInfo: nil
            ),
        ]
    }

    static func receive(_ type: String, launching: Bool) {
        if launching {
            pending = type
        } else {
            NotificationCenter.default.post(name: performed, object: type)
        }
    }

    static func takePending() -> String? {
        defer { pending = nil }
        return pending
    }
}

/// Picks up quick actions, which SwiftUI doesn't deliver on its own.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let item = options.shortcutItem {
            QuickAction.receive(item.type, launching: true)
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

@MainActor
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        QuickAction.receive(shortcutItem.type, launching: false)
        completionHandler(true)
    }
}
