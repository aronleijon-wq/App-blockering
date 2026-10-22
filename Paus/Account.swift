import AuthenticationServices
import Foundation

/// The account from Sign in with Apple. Paus has no server, so it only lives on this phone:
/// it greets the user by name, and Apple tells Paus if the user stops using it.
struct PausAccount: Codable, Equatable {
    let userID: String
    var givenName: String?
    var email: String?

    init(userID: String, givenName: String?, email: String?) {
        self.userID = userID
        self.givenName = givenName
        self.email = email
    }

    init(credential: ASAuthorizationAppleIDCredential) {
        // Apple only shares the name and email the first time someone signs in.
        self.init(userID: credential.user, givenName: credential.fullName?.givenName, email: credential.email)
    }

    var displayName: String {
        if let givenName, !givenName.isEmpty { return givenName }
        return email ?? L("Apple-konto")
    }
}

/// The intro answers and the account, kept in the app's own defaults since the extensions never need them.
enum IntroStore {
    private static let finishedKey = "introFinished"
    private static let answersKey = "introAnswers"
    private static let accountKey = "account"
    private static let trialReminderKey = "trialReminderDays"

    static var isFinished: Bool {
        get { UserDefaults.standard.bool(forKey: finishedKey) }
        set { UserDefaults.standard.set(newValue, forKey: finishedKey) }
    }

    static var answers: IntroAnswers? {
        get { load(answersKey) }
        set { save(newValue, forKey: answersKey) }
    }

    static var account: PausAccount? {
        get { load(accountKey) }
        set { save(newValue, forKey: accountKey) }
    }

    /// How many days before a free trial ends the user wants to be reminded.
    static var trialReminderDays: Int {
        get {
            let days = UserDefaults.standard.integer(forKey: trialReminderKey)
            return TrialReminder.choices.contains(days) ? days : TrialReminder.defaultDaysBefore
        }
        set { UserDefaults.standard.set(newValue, forKey: trialReminderKey) }
    }

    private static func load<Value: Decodable>(_ key: String) -> Value? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    private static func save<Value: Encodable>(_ value: Value?, forKey key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}
