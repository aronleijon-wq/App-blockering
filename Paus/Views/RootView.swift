import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model

        Group {
            if model.isAuthorized {
                TabView(selection: $model.selectedTab) {
                    TodayView()
                        .tabItem { Label("Idag", systemImage: "sun.max") }
                        .tag(AppModel.Tab.today)
                    SelectionView()
                        .tabItem { Label("Appar", systemImage: "square.grid.2x2") }
                        .tag(AppModel.Tab.apps)
                    RulesView()
                        .tabItem { Label("Regler", systemImage: "slider.horizontal.3") }
                        .tag(AppModel.Tab.rules)
                }
            } else {
                OnboardingView()
            }
        }
        .task { model.reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.reload() }
        }
        .sheet(isPresented: $model.isPauseSheetPresented) {
            PauseView()
        }
        .alert(
            "Något gick fel",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
