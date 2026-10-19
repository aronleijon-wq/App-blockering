import FamilyControls
import SwiftUI

struct SelectionView: View {
    @Environment(AppModel.self) private var model
    @State private var isPickerPresented = false
    @State private var draft = FamilyActivitySelection()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        draft = model.selection
                        isPickerPresented = true
                    } label: {
                        Label(model.hasSelection ? "Ändra urval" : "Välj appar och webbplatser", systemImage: "plus.circle.fill")
                    }
                    .disabled(model.isStrictFocusActive)
                } footer: {
                    Text(footer)
                }

                if !model.selection.categoryTokens.isEmpty {
                    Section("Kategorier") {
                        ForEach(Array(model.selection.categoryTokens), id: \.self) { token in
                            Label(token)
                        }
                    }
                }
                if !model.selection.applicationTokens.isEmpty {
                    Section("Appar") {
                        ForEach(Array(model.selection.applicationTokens), id: \.self) { token in
                            Label(token)
                        }
                    }
                }
                if !model.selection.webDomainTokens.isEmpty {
                    Section("Webbplatser") {
                        ForEach(Array(model.selection.webDomainTokens), id: \.self) { token in
                            Label(token)
                        }
                    }
                }
            }
            .navigationTitle("Appar")
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $draft)
            .onChange(of: isPickerPresented) { _, isPresented in
                if !isPresented { model.saveSelection(draft) }
            }
        }
    }

    private var footer: String {
        if model.isStrictFocusActive {
            return "Urvalet går inte att ändra under strikt fokus."
        }
        return "Tips: välj kategorin Socialt för att få med alla sociala medier på en gång. Paus ser bara anonyma symboler för det du väljer."
    }
}
