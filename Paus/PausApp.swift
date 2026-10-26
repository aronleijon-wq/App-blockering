import SwiftUI

@main
struct PausApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
        .backgroundTask(.appRefresh(StepRefresh.identifier)) {
            await model.refreshSessionSteps()
        }
    }
}
