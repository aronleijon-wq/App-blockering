import AuthenticationServices
import SwiftUI

/// The user's own details: name, nickname, age, starting screen time, Apple account and deletion.
struct AccountView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var isNicknamePresented = false
    @State private var isDeletePresented = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    MascotView(mood: model.mood, level: model.progress.level, size: 100)
                    Text(model.firstName ?? L("Ditt konto"))
                        .font(.title2.bold())
                    Text(L("Nivå \(model.progress.level) · \(Level.title(for: model.progress.level))"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                SettingsGroup(title: L("Om dig")) {
                    HStack(spacing: 14) {
                        Image(systemName: "person.fill")
                            .font(.title3)
                            .frame(width: 30)
                            .accessibilityHidden(true)
                        TextField(L("Ditt förnamn"), text: $name)
                            .font(.body.weight(.semibold))
                            .textContentType(.givenName)
                            .submitLabel(.done)
                            .onSubmit(saveName)
                    }
                    .padding(.vertical, 14)
                    SettingsDivider()
                    Button {
                        isNicknamePresented = true
                    } label: {
                        SettingsRow(
                            symbol: "at",
                            title: L("Smeknamn"),
                            detail: model.league.nickname ?? L("Inte med i ligan än"),
                            accessory: .chevron
                        )
                    }
                    SettingsDivider()
                    Picker(selection: Binding(
                        get: { model.introAnswers?.ageGroup ?? .from18 },
                        set: { group in model.updateAnswers { $0.ageGroup = group } }
                    )) {
                        ForEach(AgeGroup.allCases) { Text($0.label).tag($0) }
                    } label: {
                        SettingsRow(symbol: "birthday.cake.fill", title: L("Ålder"))
                    }
                    .tint(.secondary)
                    SettingsDivider()
                    Picker(selection: Binding(
                        get: { model.introAnswers?.hoursPerDay ?? 4 },
                        set: { hours in model.updateAnswers { $0.hoursPerDay = hours } }
                    )) {
                        ForEach(Array(stride(from: 0.5, through: 12, by: 0.5)), id: \.self) { hours in
                            Text(IntroView.hours(hours)).tag(hours)
                        }
                    } label: {
                        SettingsRow(symbol: "hourglass", title: L("Skärmtid innan Paus"), detail: L("Per dag, som du uppgav"))
                    }
                    .tint(.secondary)
                }

                SettingsGroup(title: L("Apple-konto")) {
                    if let account = model.account {
                        SettingsRow(symbol: "apple.logo", title: L("Inloggad"), detail: account.email ?? account.displayName)
                        SettingsDivider()
                        Button(role: .destructive) {
                            model.signOut()
                        } label: {
                            SettingsRow(symbol: "rectangle.portrait.and.arrow.right", title: L("Logga ut"))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L("Skapa ett konto så kommer Pip ihåg dig. Allt fungerar även utan."))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                model.signIn(result)
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 50)
                            .clipShape(Capsule())
                        }
                        .padding(.vertical, 12)
                    }
                }

                Button {
                    isDeletePresented = true
                } label: {
                    Label(L("Radera konto och all data"), systemImage: "trash.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.pink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.pink.opacity(0.12), in: Capsule())
                }
                .disabled(model.isStrictFocusActive)

                if model.isStrictFocusActive {
                    Text(L("Kontot kan inte raderas under strikt fokus."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .screenBackground()
        .navigationTitle(L("Mitt konto"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = model.firstName ?? "" }
        .onDisappear(perform: saveName)
        .sheet(isPresented: $isNicknamePresented) {
            NicknameSheet()
        }
        .sheet(isPresented: $isDeletePresented) {
            DeleteAccountSheet()
                .presentationDetents([.medium])
                .presentationCornerRadius(36)
        }
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (model.introAnswers?.name ?? "") else { return }
        model.updateAnswers { $0.name = trimmed }
    }
}

/// A last, clear check before everything is erased.
private struct DeleteAccountSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "trash")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.pink)
                .frame(width: 84, height: 84)
                .overlay(Circle().strokeBorder(Theme.pink.opacity(0.4), lineWidth: 1.5))
                .padding(.top, 28)
            Text(L("Radera kontot?"))
                .font(.title2.bold())
            Text(L("XP, nivå, streak, troféer, regler, dina svar, ditt konto och ditt ligakonto raderas, och alla blockeringar tas bort. Det går inte att ångra. En prenumeration sägs upp separat i Inställningar."))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button {
                Task {
                    isDeleting = true
                    await model.deleteAllData()
                    isDeleting = false
                    dismiss()
                }
            } label: {
                Label(L("Radera allt"), systemImage: "checkmark")
                    .font(.headline)
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white, in: Capsule())
            }
            .disabled(isDeleting)
            Button(L("Avbryt")) { dismiss() }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Theme.pink.opacity(0.45), Theme.card, Theme.card], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }
}
