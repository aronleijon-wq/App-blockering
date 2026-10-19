import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model

        Group {
            if model.isAuthorized {
                TabView(selection: $model.selectedTab) {
                    HomeView()
                        .tabItem { Label("Hem", systemImage: "house.fill") }
                        .tag(AppModel.Tab.home)
                    TrophiesView()
                        .tabItem { Label("Troféer", systemImage: "trophy.fill") }
                        .tag(AppModel.Tab.trophies)
                    SelectionView()
                        .tabItem { Label("Appar", systemImage: "square.grid.2x2.fill") }
                        .tag(AppModel.Tab.apps)
                    RulesView()
                        .tabItem { Label("Regler", systemImage: "slider.horizontal.3") }
                        .tag(AppModel.Tab.rules)
                }
            } else {
                OnboardingView()
            }
        }
        .tint(Theme.pink)
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
        .task { model.reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.reload() }
        }
        .sheet(isPresented: $model.isPauseSheetPresented) {
            PauseView()
        }
        .sheet(isPresented: $model.isPaywallPresented) {
            PaywallView()
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { !model.celebration.isEmpty },
                set: { if !$0 { model.dismissCelebration() } }
            )
        ) {
            CelebrationView(rewards: model.celebration)
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
