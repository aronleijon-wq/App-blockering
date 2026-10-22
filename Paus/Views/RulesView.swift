import SwiftUI

struct RulesView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: BlockSchedule?
    @State private var isSettingsPresented = false

    private let limitOptions = [15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Form {
                proSection

                Section {
                    if model.isPro {
                        Picker(L("Daglig gräns"), selection: binding(\.dailyLimitMinutes)) {
                            Text(L("Ingen")).tag(Int?.none)
                            ForEach(limitOptions, id: \.self) { minutes in
                                Text(Format.minutes(minutes)).tag(Int?.some(minutes))
                            }
                        }
                    } else {
                        LockedRow(title: L("Daglig gräns")) { model.isPaywallPresented = true }
                    }
                } footer: {
                    Text(L("När du har använt de valda apparna så här länge under en dag blockeras de till midnatt. Håller du dig under gränsen får du \(PlayerProgress.XP.dayUnderLimit) XP."))
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
                            editing = BlockSchedule(name: L("Skola"), weekdays: [2, 3, 4, 5, 6], startMinute: 8 * 60, endMinute: 15 * 60)
                        } else {
                            model.isPaywallPresented = true
                        }
                    } label: {
                        HStack {
                            Label(L("Lägg till schema"), systemImage: "plus")
                            if !model.canAddSchedule {
                                Spacer()
                                ProBadge()
                            }
                        }
                    }
                } header: {
                    Text(L("Scheman"))
                } footer: {
                    Text(model.isPro
                         ? L("Under ett schema blockeras de valda apparna automatiskt, till exempel under skoldagen eller på kvällen.")
                         : L("Gratis ingår ett schema. Med Pro kan du ha hur många du vill."))
                }

                Section {
                    if model.isPro {
                        Toggle(L("Strikt fokus"), isOn: binding(\.strictFocus))
                            .disabled(model.isStrictFocusActive)
                    } else {
                        LockedRow(title: L("Strikt fokus")) { model.isPaywallPresented = true }
                    }
                } header: {
                    Text(L("Fokuspass"))
                } footer: {
                    Text(L("Ett strikt fokuspass går inte att avbryta, och du kan inte ta pauser under det."))
                }

                Section {
                    Toggle(L("Tillåt pauser"), isOn: binding(\.pause.isEnabled))
                    if model.rules.pause.isEnabled {
                        Picker(L("Andas först"), selection: binding(\.pause.waitSeconds)) {
                            ForEach([10, 20, 30, 60], id: \.self) { Text("\($0) s").tag($0) }
                        }
                        Picker(L("Pausens längd"), selection: binding(\.pause.minutes)) {
                            ForEach([3, 5, 10, 15], id: \.self) { Text("\($0) min").tag($0) }
                        }
                        Stepper(L("Högst \(model.rules.pause.maxPerDay) per dag"), value: binding(\.pause.maxPerDay), in: 1...10)
                    }
                } header: {
                    Text(L("Pauser"))
                } footer: {
                    Text(L("En paus öppnar de blockerade apparna en kort stund. Först svarar du varför och andas en stund. Dagens första paus är gratis, sedan kostar de \(League.pausePenalty(forPause: 2)), \(League.pausePenalty(forPause: 3)) och \(League.pausePenalty(forPause: 4)) XP och veckopoäng. Tackar du nej får du \(PlayerProgress.XP.decline) XP. Att stänga av en blockering medan den pågår kostar \(PlayerProgress.XP.escapedBlock) XP. Du åker aldrig ner en nivå."))
                }

                Section {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Label(L("Konto och inställningar"), systemImage: "person.crop.circle")
                    }
                } footer: {
                    Text(L("Ditt konto, avinstallationsskydd, vuxenfilter, semesterläge, support och integritet."))
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(L("Regler"))
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
            }
            .sheet(item: $editing) { schedule in
                ScheduleEditorView(
                    schedule: schedule,
                    isNew: !model.rules.schedules.contains { $0.id == schedule.id }
                )
            }
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            if model.isPro {
                Label(L("Du har Paus Pro"), systemImage: "checkmark.seal.fill")
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
                            Text(L("Prova Paus Pro gratis"))
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
            return L("7 dagar gratis, sedan per månad eller år")
        }
        if let perMonth = store.yearlyPerMonth {
            return L("7 dagar gratis, sedan \(yearly)/år (bara \(perMonth)/mån) eller \(monthly)/mån")
        }
        return L("7 dagar gratis, sedan \(yearly)/år eller \(monthly)/mån")
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
