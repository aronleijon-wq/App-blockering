import SwiftUI

@main
struct PausApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onAppear { QuickAction.install() }
        }
        .backgroundTask(.appRefresh(StepRefresh.identifier)) {
            await model.refreshSessionSteps()
        }
    }
}
