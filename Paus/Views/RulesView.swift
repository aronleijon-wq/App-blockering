import AuthenticationServices
import SwiftUI

struct RulesView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: BlockSchedule?
    @State private var isDeleteConfirmationPresented = false

    private let limitOptions = [15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Form {
                proSection

                Section {
                    if model.isPro {
                        Picker("Daglig gräns", selection: binding(\.dailyLimitMinutes)) {
                            Text("Ingen").tag(Int?.none)
                            ForEach(limitOptions, id: \.self) { minutes in
                                Text(Format.minutes(minutes)).tag(Int?.some(minutes))
                            }
                        }
                    } else {
                        LockedRow(title: "Daglig gräns") { model.isPaywallPresented = true }
                    }
                } footer: {
                    Text("När du har använt de valda apparna så här länge under en dag blockeras de till midnatt. Håller du dig under gränsen får du \(PlayerProgress.XP.dayUnderLimit) XP.")
                }

                Section {
                    ForEach(Array(model.rules.schedules.enumerated()), id: \.element.id) { index, schedule in
                        Button {
                            editing = schedule
                        } label: {
                            ScheduleRow(schedule: schedule, isLocked: !model.isPro && index > 0)
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        model.updateRules { $0.schedules.remove(atOffsets: offsets) }
                    }

                    Button {
                        if model.canAddSchedule {
                            editing = BlockSchedule(name: "Skola", weekdays: [2, 3, 4, 5, 6], startMinute: 8 * 60, endMinute: 15 * 60)
                        } else {
                            model.isPaywallPresented = true
                        }
                    } label: {
                        HStack {
                            Label("Lägg till schema", systemImage: "plus")
                            if !model.canAddSchedule {
                                Spacer()
                                ProBadge()
                            }
                        }
                    }
                } header: {
                    Text("Scheman")
                } footer: {
                    Text(model.isPro
                         ? "Under ett schema blockeras de valda apparna automatiskt, till exempel under skoldagen eller på kvällen."
                         : "Gratis ingår ett schema. Med Pro kan du ha hur många du vill.")
                }

                Section {
                    if model.isPro {
                        Toggle("Strikt fokus", isOn: binding(\.strictFocus))
                            .disabled(model.isStrictFocusActive)
                    } else {
                        LockedRow(title: "Strikt fokus") { model.isPaywallPresented = true }
                    }
                } header: {
                    Text("Fokuspass")
                } footer: {
                    Text("Ett strikt fokuspass går inte att avbryta, och du kan inte ta pauser under det.")
                }

                Section {
                    Toggle("Tillåt pauser", isOn: binding(\.pause.isEnabled))
                    if model.rules.pause.isEnabled {
                        Picker("Andas först", selection: binding(\.pause.waitSeconds)) {
                            ForEach([10, 20, 30, 60], id: \.self) { Text("\($0) s").tag($0) }
                        }
                        Picker("Pausens längd", selection: binding(\.pause.minutes)) {
                            ForEach([3, 5, 10, 15], id: \.self) { Text("\($0) min").tag($0) }
                        }
                        Stepper("Högst \(model.rules.pause.maxPerDay) per dag", value: binding(\.pause.maxPerDay), in: 1...10)
                    }
                } header: {
                    Text("Pauser")
                } footer: {
                    Text("En paus öppnar de blockerade apparna en kort stund. Först svarar du varför och andas en stund. Dagens första paus är gratis, sedan kostar de \(League.pausePenalty(forPause: 2)), \(League.pausePenalty(forPause: 3)) och \(League.pausePenalty(forPause: 4)) veckopoäng. Tackar du nej får du \(PlayerProgress.XP.decline) XP.")
                }

                accountSection

                Section {
                    NavigationLink("Integritetspolicy") { PrivacyPolicyView() }
                    Link("Användarvillkor", destination: AppInfo.termsURL)
                    if let mail = AppInfo.supportMailURL {
                        Link("Kontakta support", destination: mail)
                    }
                    Button("Radera all min data", role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                    .disabled(model.isStrictFocusActive)
                } header: {
                    Text("Om och integritet")
                } footer: {
                    Text(model.isStrictFocusActive ? "Data kan inte raderas under strikt fokus." : "Paus fungerar utan konto, och det mesta stannar på din telefon.")
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Regler")
            .confirmationDialog("Radera all din data?", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
                Button("Radera allt", role: .destructive) {
                    Task { await model.deleteAllData() }
                }
                Button("Avbryt", role: .cancel) {}
            } message: {
                Text("XP, nivå, streak, troféer, regler, dina svar från introduktionen, ditt konto och ditt ligakonto raderas och alla blockeringar tas bort. Det går inte att ångra. En prenumeration sägs upp separat i Inställningar.")
            }
            .sheet(item: $editing) { schedule in
                ScheduleEditorView(
                    schedule: schedule,
                    isNew: !model.rules.schedules.contains { $0.id == schedule.id }
                )
            }
        }
    }

    private var accountSection: some View {
        Section {
            if let account = model.account {
                Label("Inloggad som \(account.displayName)", systemImage: "person.crop.circle.badge.checkmark")
                Button("Logga ut", role: .destructive) { model.signOut() }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    model.signIn(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 46)
            }
        } header: {
            Text("Konto")
        } footer: {
            Text("Kontot sparas bara på den här telefonen. Allt i Paus fungerar även utan konto.")
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            if model.isPro {
                Label("Du har Paus Pro", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.mint)
            } else {
                Button {
                    model.isPaywallPresented = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Theme.glow, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Prova Paus Pro gratis")
                                .font(.headline)
                            Text(proPriceText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .foregroundStyle(.primary)
            }
        }
        .listRowBackground(Theme.cardRaised)
    }

    private var proPriceText: String {
        let store = model.store
        guard let monthly = store.monthlyPrice, let yearly = store.yearlyPrice else {
            return "7 dagar gratis, sedan per månad eller år"
        }
        if let perMonth = store.yearlyPerMonth {
            return "7 dagar gratis, sedan \(yearly)/år (bara \(perMonth)/mån) eller \(monthly)/mån"
        }
        return "7 dagar gratis, sedan \(yearly)/år eller \(monthly)/mån"
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<PausRules, Value>) -> Binding<Value> {
        Binding(
            get: { model.rules[keyPath: keyPath] },
            set: { newValue in model.updateRules { $0[keyPath: keyPath] = newValue } }
        )
    }
}

private struct LockedRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                ProBadge()
            }
        }
        .foregroundStyle(.primary)
    }
}

private struct ScheduleRow: View {
    let schedule: BlockSchedule
    let isLocked: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.name)
                    .font(.headline)
                Text("\(Format.weekdays(schedule.weekdays)) · \(Format.clock(minute: schedule.startMinute))–\(Format.clock(minute: schedule.endMinute))")
                    .foregroundStyle(.secondary)
            }
            if isLocked {
                Spacer()
                ProBadge()
            }
        }
        .opacity(schedule.isEnabled && !isLocked ? 1 : 0.5)
    }
}
