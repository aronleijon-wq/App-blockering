import SwiftUI

struct ScheduleEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var schedule: BlockSchedule
    let isNew: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Namn", text: $schedule.name)
                    Toggle("Aktivt", isOn: $schedule.isEnabled)
                }

                Section("Dagar") {
                    WeekdayPicker(selection: $schedule.weekdays)
                }

                Section {
                    DatePicker("Från", selection: time(\.startMinute), displayedComponents: .hourAndMinute)
                    DatePicker("Till", selection: time(\.endMinute), displayedComponents: .hourAndMinute)
                } header: {
                    Text("Tid")
                } footer: {
                    Text(timeFooter)
                }

                if !isNew {
                    Section {
                        Button("Ta bort schemat", role: .destructive) {
                            model.deleteSchedule(id: schedule.id)
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(isNew ? "Nytt schema" : "Ändra schema")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        schedule.name = schedule.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        model.saveSchedule(schedule)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !schedule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !schedule.weekdays.isEmpty
            && hasValidLength
    }

    /// DeviceActivity needs at least 15 minutes, and a window can't cover the whole day.
    private var hasValidLength: Bool {
        schedule.durationMinutes >= 15 && schedule.durationMinutes < 1440
    }

    private var timeFooter: String {
        if !hasValidLength {
            return "Ett schema måste vara minst 15 minuter och sluta en annan tid än det börjar."
        }
        if schedule.crossesMidnight {
            return "Schemat fortsätter över midnatt och slutar \(Format.clock(minute: schedule.endMinute)) dagen efter."
        }
        return "Blockerar i \(Format.minutes(schedule.durationMinutes))."
    }

    private func time(_ keyPath: WritableKeyPath<BlockSchedule, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minute = schedule[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                schedule[keyPath: keyPath] = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }
}

private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Weekday.mondayFirst, id: \.number) { day in
                let isSelected = selection.contains(day.number)
                Button {
                    if isSelected {
                        selection.remove(day.number)
                    } else {
                        selection.insert(day.number)
                    }
                } label: {
                    Text(day.letter)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 38, height: 38)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(isSelected ? AnyShapeStyle(Theme.glow) : AnyShapeStyle(Theme.cardRaised), in: Circle())
                }
                .buttonStyle(.borderless)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(day.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
