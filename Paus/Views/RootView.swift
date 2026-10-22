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
                        .tabItem { Label(L("Hem"), systemImage: "house.fill") }
                        .tag(AppModel.Tab.home)
                    LeagueView()
                        .tabItem { Label(L("Liga"), systemImage: "flag.checkered") }
                        .tag(AppModel.Tab.league)
                    TrophiesView()
                        .tabItem { Label(L("Troféer"), systemImage: "trophy.fill") }
                        .tag(AppModel.Tab.trophies)
                    SelectionView()
                        .tabItem { Label(L("Appar"), systemImage: "square.grid.2x2.fill") }
                        .tag(AppModel.Tab.apps)
                    RulesView()
                        .tabItem { Label(L("Regler"), systemImage: "slider.horizontal.3") }
                        .tag(AppModel.Tab.rules)
                }
            } else if model.hasFinishedIntro {
                OnboardingView()
            } else {
                IntroView()
            }
        }
        // A new identity redraws every screen in the newly chosen language.
        .id(model.language)
        .environment(\.locale, model.language.locale)
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
            L("Pip blev ledsen 😢"),
            isPresented: Binding(
                get: { model.lossMessage != nil },
                set: { if !$0 { model.lossMessage = nil } }
            )
        ) {
            Button(L("Okej"), role: .cancel) {}
        } message: {
            Text(model.lossMessage ?? "")
        }
        .alert(L("Pip märkte att du stängde av Paus"), isPresented: $model.isProtectionWarningPresented) {
            Button(L("Okej"), role: .cancel) {}
        } message: {
            Text(L("Din streak nollställdes, du förlorade upp till \(PlayerProgress.XP.disabledProtection) XP och \(League.Points.disabledProtectionPenalty) veckopoäng, och Pip tappade \(PipHealth.disabledProtection) i hälsa. Slå på Paus igen för att fortsätta blockera."))
        }
        .alert(
            L("Något gick fel"),
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
