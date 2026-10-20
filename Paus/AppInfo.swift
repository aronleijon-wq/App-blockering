import Foundation

/// Contact details and legal links shown in the app and the privacy policy.
enum AppInfo {
    /// Who is responsible for the data (personuppgiftsansvarig) under GDPR.
    static let developerName = "Aron Leijon"
    static let supportEmail = "aronleijon@icloud.com"

    /// Apple's standard license agreement, which App Store subscriptions may use as their terms of use.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static var supportMailURL: URL? {
        URL(string: "mailto:\(supportEmail)?subject=Paus")
    }
}
