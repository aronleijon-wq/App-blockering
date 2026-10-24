import SwiftUI

/// Creating an account or signing in with an email address and a password.
struct EmailSignInView: View {
    enum Mode: Hashable {
        case signUp, signIn
    }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// The name from the intro, so it isn't asked for twice.
    var suggestedName = ""
    var onSignedIn: () -> Void = {}

    @State private var mode: Mode = .signUp
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var notice: String?
    @FocusState private var focused: Field?

    private enum Field {
        case name, email, password
    }

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSubmit: Bool { trimmedEmail.contains("@") && password.count >= 6 && !isWorking }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker(L("Konto"), selection: $mode) {
                        Text(L("Skapa konto")).tag(Mode.signUp)
                        Text(L("Logga in")).tag(Mode.signIn)
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 12) {
                        if mode == .signUp {
                            field(L("Förnamn"), text: $name)
                                .textContentType(.givenName)
                                .focused($focused, equals: .name)
                                .submitLabel(.next)
                                .onSubmit { focused = .email }
                        }
                        field(L("E-post"), text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focused, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focused = .password }
                        SecureField(L("Lösenord (minst 6 tecken)"), text: $password)
                            .textContentType(mode == .signUp ? .newPassword : .password)
                            .focused($focused, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await submit() } }
                            .modifier(FieldStyle())
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.pink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let notice {
                        Label(notice, systemImage: "envelope.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.mint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if isWorking {
                            ProgressView().tint(.white)
                        } else {
                            Text(mode == .signUp ? L("Skapa konto") : L("Logga in"))
                        }
                    }
                    .buttonStyle(GlowButtonStyle())
                    .disabled(!canSubmit)

                    if mode == .signIn {
                        Button(L("Glömt lösenordet?")) { Task { await resetPassword() } }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .screenBackground()
            .navigationTitle(L("E-post"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Avbryt")) { dismiss() }
                }
            }
            .onAppear {
                if name.isEmpty { name = suggestedName }
                focused = mode == .signUp && name.isEmpty ? .name : .email
            }
            .onChange(of: mode) {
                errorMessage = nil
                notice = nil
            }
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .modifier(FieldStyle())
    }

    private func submit() async {
        guard canSubmit else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let session = mode == .signUp
                ? try await EmailAuth.signUp(email: trimmedEmail, password: password)
                : try await EmailAuth.signIn(email: trimmedEmail, password: password)
            model.signIn(session, name: mode == .signUp ? name : nil)
            dismiss()
            onSignedIn()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? L("Något gick fel. Försök igen.")
        }
    }

    private func resetPassword() async {
        guard trimmedEmail.contains("@") else {
            errorMessage = L("Skriv din e-post först, så skickar jag en länk.")
            return
        }
        errorMessage = nil
        do {
            try await EmailAuth.sendPasswordReset(email: trimmedEmail)
            notice = L("Kolla din mejl, där finns en länk för att välja ett nytt lösenord.")
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? L("Något gick fel. Försök igen.")
        }
    }
}

private struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body.weight(.semibold))
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            }
    }
}

/// "or", between Sign in with Apple and the email button.
struct OrDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            Text(L("eller"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

/// The button that opens email sign-in, styled to sit under Sign in with Apple.
struct EmailSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(L("Fortsätt med e-post"), systemImage: "envelope.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.white.opacity(0.1), in: Capsule())
        }
    }
}
