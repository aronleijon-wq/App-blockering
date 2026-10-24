import Foundation
import Security

/// Email accounts through Firebase Authentication's REST API, so Paus needs no SDK. Firebase keeps the
/// address and checks the password; the phone keeps a refresh token in the keychain, which is all it needs
/// to delete the account later. The API key is set in `Paus-Info.plist`; without it email sign-in is hidden.
enum EmailAuth {
    struct Session {
        let userID: String
        let email: String
    }

    enum Failure: LocalizedError {
        case emailTaken, wrongPassword, weakPassword, invalidEmail, tooManyAttempts, offline, unknown

        var errorDescription: String? {
            switch self {
            case .emailTaken: return L("Det finns redan ett konto med den e-postadressen. Logga in i stället.")
            case .wrongPassword: return L("Fel e-post eller lösenord.")
            case .weakPassword: return L("Lösenordet måste vara minst 6 tecken.")
            case .invalidEmail: return L("Det ser inte ut som en e-postadress.")
            case .tooManyAttempts: return L("För många försök. Vänta en stund och försök igen.")
            case .offline: return L("Ingen kontakt med servern. Kontrollera internet och försök igen.")
            case .unknown: return L("Något gick fel. Försök igen.")
            }
        }
    }

    static var isAvailable: Bool { apiKey != nil }

    private static var apiKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "PausFirebaseAPIKey") as? String, !key.isEmpty else { return nil }
        return key
    }

    static func signUp(email: String, password: String) async throws -> Session {
        let response = try await call("accounts:signUp", ["email": email, "password": password, "returnSecureToken": true])
        let session = try store(response)
        // Lets the user prove the address is theirs; signing in doesn't wait for it.
        if let idToken = response["idToken"] as? String {
            _ = try? await call("accounts:sendOobCode", ["requestType": "VERIFY_EMAIL", "idToken": idToken])
        }
        return session
    }

    static func signIn(email: String, password: String) async throws -> Session {
        try store(try await call("accounts:signInWithPassword", ["email": email, "password": password, "returnSecureToken": true]))
    }

    static func sendPasswordReset(email: String) async throws {
        _ = try await call("accounts:sendOobCode", ["requestType": "PASSWORD_RESET", "email": email])
    }

    /// Deletes the account at Firebase. Signing in again would be needed if the refresh token is gone.
    static func deleteAccount() async throws {
        guard let refreshToken = Keychain.refreshToken else { return }
        let idToken = try await freshIDToken(refreshToken: refreshToken)
        _ = try await call("accounts:delete", ["idToken": idToken])
        Keychain.refreshToken = nil
    }

    static func forget() {
        Keychain.refreshToken = nil
    }

    // MARK: Requests

    private static func store(_ response: [String: Any]) throws -> Session {
        guard let userID = response["localId"] as? String,
              let email = response["email"] as? String,
              let refreshToken = response["refreshToken"] as? String else { throw Failure.unknown }
        Keychain.refreshToken = refreshToken
        return Session(userID: userID, email: email)
    }

    private static func freshIDToken(refreshToken: String) async throws -> String {
        guard let apiKey, let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(apiKey)") else { throw Failure.unknown }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let token = refreshToken.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? refreshToken
        request.httpBody = Data("grant_type=refresh_token&refresh_token=\(token)".utf8)
        let response = try await send(request)
        guard let idToken = response["id_token"] as? String else { throw Failure.unknown }
        return idToken
    }

    private static func call(_ method: String, _ body: [String: Any]) async throws -> [String: Any] {
        guard let apiKey, let url = URL(string: "https://identitytoolkit.googleapis.com/v1/\(method)?key=\(apiKey)") else {
            throw Failure.unknown
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request)
    }

    private static func send(_ request: URLRequest) async throws -> [String: Any] {
        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            throw Failure.offline
        }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if let error = json["error"] as? [String: Any] {
            throw failure(for: error["message"] as? String ?? "")
        }
        return json
    }

    /// Firebase's error codes, which sometimes carry an explanation after the code.
    static func failure(for message: String) -> Failure {
        let code = message.split(separator: " ").first.map(String.init) ?? message
        switch code {
        case "EMAIL_EXISTS": return .emailTaken
        case "INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD", "EMAIL_NOT_FOUND", "USER_DISABLED": return .wrongPassword
        case "WEAK_PASSWORD": return .weakPassword
        case "INVALID_EMAIL", "MISSING_EMAIL": return .invalidEmail
        case "TOO_MANY_ATTEMPTS_TRY_LATER": return .tooManyAttempts
        default: return .unknown
        }
    }

    /// The refresh token, kept on this phone only.
    private enum Keychain {
        private static let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "paus.email-account",
            kSecAttrAccount as String: "refreshToken",
        ]

        static var refreshToken: String? {
            get {
                var lookup = query
                lookup[kSecReturnData as String] = true
                var result: AnyObject?
                guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
                return String(data: data, encoding: .utf8)
            }
            set {
                SecItemDelete(query as CFDictionary)
                guard let newValue else { return }
                var item = query
                item[kSecValueData as String] = Data(newValue.utf8)
                item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                SecItemAdd(item as CFDictionary, nil)
            }
        }
    }
}
