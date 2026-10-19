import SwiftUI

struct RulesView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: BlockSchedule?

    private let limitOptions = [15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Daglig gräns", selection: binding(\.dailyLimitMinutes)) {
                        Text("Ingen").tag(Int?.none)
                        ForEach(limitOptions, id: \.self) { minutes in
                            Text(Format.minutes(minutes)).tag(Int?.some(minutes))
                        }
                    }
                } footer: {
                    Text("När du har använt de valda apparna så här länge under en dag blockeras de till midnatt.")
                }

                Section {
                    ForEach(model.rules.schedules) { schedule in
                        Button {
                            editing = schedule
                        } label: {
                            ScheduleRow(schedule: schedule)
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        model.updateRules { $0.schedules.remove(atOffsets: offsets) }
                    }

                    Button {
                        editing = BlockSchedule(name: "Skola", weekdays: [2, 3, 4, 5, 6], startMinute: 8 * 60, endMinute: 15 * 60)
                    } label: {
                        Label("Lägg till schema", systemImage: "plus")
                    }
                } header: {
                    Text("Scheman")
                } footer: {
                    Text("Under ett schema blockeras de valda apparna automatiskt, till exempel under skoldagen eller på kvällen.")
                }

                Section {
                    Toggle("Strikt fokus", isOn: binding(\.strictFocus))
                        .disabled(model.isStrictFocusActive)
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
                    Text("En paus öppnar de blockerade apparna en kort stund. Innan dess andas du en stund, så att det blir ett medvetet val.")
                }
            }
            .navigationTitle("Regler")
            .sheet(item: $editing) { schedule in
                ScheduleEditorView(
                    schedule: schedule,
                    isNew: !model.rules.schedules.contains { $0.id == schedule.id }
                )
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<PausRules, Value>) -> Binding<Value> {
        Binding(
            get: { model.rules[keyPath: keyPath] },
            set: { newValue in model.updateRules { $0[keyPath: keyPath] = newValue } }
        )
    }
}

private struct ScheduleRow: View {
    let schedule: BlockSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(schedule.name)
                .font(.headline)
            Text("\(Format.weekdays(schedule.weekdays)) · \(Format.clock(minute: schedule.startMinute))–\(Format.clock(minute: schedule.endMinute))")
                .foregroundStyle(.secondary)
        }
        .opacity(schedule.isEnabled ? 1 : 0.5)
    }
}
