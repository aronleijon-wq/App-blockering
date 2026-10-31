import SwiftUI

/// Adds a friend to the league by the code they shared.
struct AddFriendSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isAdding = false
    @State private var problem: String?
    /// Uploads the new friends list and reloads the friends tab.
    let onAdded: () async -> Void

    private var normalized: String { FriendCode.normalized(code) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("Vänkod"), text: $code)
                        .font(.title3.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: code) { problem = nil }
                } footer: {
                    Text(problem ?? L("Be din vän om koden under Liga > Vänner."))
                        .foregroundStyle(problem == nil ? Color.secondary : Theme.pink)
                }

                Section {
                    HStack {
                        Text(L("Din kod"))
                        Spacer()
                        Text(model.league.friendCode)
                            .font(.body.monospaced().weight(.semibold))
                            .textSelection(.enabled)
                    }
                    ShareLink(
                        item: AppInfo.inviteURL,
                        subject: Text(L("Utmana mig i Paus")),
                        message: Text(AppInfo.inviteMessage(nickname: model.league.nickname, code: model.league.friendCode))
                    ) {
                        Label(L("Skicka din kod"), systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text(L("Ni ser varandra i Vänner så fort en av er har lagt till den andra."))
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(L("Lägg till vän"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Avbryt")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Lägg till")) { add() }
                        .disabled(normalized.count != FriendCode.length || isAdding)
                }
            }
        }
    }

    private func add() {
        isAdding = true
        Task {
            do {
                try await model.league.addFriend(code: normalized)
                dismiss()
                await onAdded()
            } catch LeagueService.FriendError.ownCode {
                problem = L("Det där är din egen kod.")
            } catch LeagueService.FriendError.notFound {
                problem = L("Ingen spelare har den koden. Kolla att den är rätt skriven och att din vän har valt ett smeknamn i ligan.")
            } catch {
                problem = L("Det gick inte att lägga till vännen just nu. Kontrollera internet och försök igen.")
            }
            isAdding = false
        }
    }
}
