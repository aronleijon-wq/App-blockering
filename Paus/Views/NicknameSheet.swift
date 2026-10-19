import SwiftUI

/// Picks the public nickname shown in the league, or leaves the league.
struct NicknameSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isLeaving = false

    private var problem: Nickname.Problem? { Nickname.problem(with: name) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Smeknamn", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text(footer)
                        .foregroundStyle(problem == nil || name.isEmpty ? Color.secondary : Theme.pink)
                }

                if model.league.nickname != nil {
                    Section {
                        Button("Lämna ligan och ta bort mitt namn", role: .destructive) {
                            Task {
                                isLeaving = true
                                do {
                                    try await model.league.leave()
                                    dismiss()
                                } catch {
                                    model.errorMessage = "Det gick inte att lämna ligan just nu. Försök igen."
                                }
                                isLeaving = false
                            }
                        }
                        .disabled(isLeaving)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Ditt smeknamn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        model.league.setNickname(name)
                        dismiss()
                        Task { await model.syncLeague(force: true) }
                    }
                    .disabled(problem != nil)
                }
            }
            .onAppear { name = model.league.nickname ?? "" }
        }
    }

    private var footer: String {
        switch problem {
        case .tooShort where !name.isEmpty:
            return "Minst \(Nickname.minLength) tecken."
        case .tooLong:
            return "Högst \(Nickname.maxLength) tecken."
        case .invalidCharacters:
            return "Använd bara bokstäver, siffror, punkt, bindestreck och understreck."
        case .notAllowed:
            return "Det namnet är inte tillåtet. Välj ett annat."
        default:
            return "Syns för alla i ligan. Använd inte ditt riktiga namn."
        }
    }
}
