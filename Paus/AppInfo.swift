import Foundation

/// Contact details and legal links shown in the app and the privacy policy.
enum AppInfo {
    #warning("Fyll i ditt namn och din supportadress innan appen skickas till App Store.")
    /// Who is responsible for the data (personuppgiftsansvarig) under GDPR.
    static let developerName = "Paus utvecklare"
    static let supportEmail = "support@example.com"

    /// Apple's standard license agreement, which App Store subscriptions may use as their terms of use.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static var supportMailURL: URL? {
        URL(string: "mailto:\(supportEmail)?subject=Paus")
    }
}
