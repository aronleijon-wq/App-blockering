import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model

        Group {
            if model.showsMainApp {
                TabView(selection: $model.selectedTab) {
                    HomeView()
                        .tabItem { Label(L("Hem"), systemImage: "house.fill") }
                        .tag(AppModel.Tab.home)
                    QuestsView()
                        .tabItem { Label(L("Uppdrag"), systemImage: "scroll.fill") }
                        .tag(AppModel.Tab.quests)
                    LeagueView()
                        .tabItem { Label(L("Liga"), systemImage: "flag.checkered") }
                        .tag(AppModel.Tab.league)
                    ProfileView()
                        .tabItem { Label(L("Profil"), systemImage: "person.crop.circle.fill") }
                        .tag(AppModel.Tab.profile)
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
        .overlay {
            if case .required = model.updateNeed {
                UpdateRequiredView()
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
        .onReceive(NotificationCenter.default.publisher(for: QuickAction.performed)) { note in
            if let type = note.object as? String { model.handleQuickAction(type) }
        }
        .task {
            if let type = QuickAction.takePending() { model.handleQuickAction(type) }
        }
        .alert(
            model.sosExplanation == nil ? L("Inget är blockerat just nu") : L("Lås upp allt?"),
            isPresented: $model.isSOSPresented
        ) {
            if model.sosExplanation != nil {
                Button(L("Lås upp (−\(model.sosCost) XP och poäng)"), role: .destructive) { model.useSOS() }
                Button(L("Avbryt"), role: .cancel) {}
            } else {
                Button(L("Okej"), role: .cancel) {}
            }
        } message: {
            Text(model.sosExplanation ?? L("Du kan använda appar som vanligt."))
        }
        .alert(
            L("Veckans dueller ⚔️"),
            isPresented: Binding(get: { model.duelMessage != nil }, set: { if !$0 { model.duelMessage = nil } })
        ) {
            Button(L("Okej"), role: .cancel) {}
        } message: {
            Text(model.duelMessage ?? "")
        }
        .alert(
            L("Gratis Pro! 🎉"),
            isPresented: Binding(get: { model.referralMessage != nil }, set: { if !$0 { model.referralMessage = nil } })
        ) {
            Button(L("Okej"), role: .cancel) {}
        } message: {
            Text(model.referralMessage ?? "")
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
