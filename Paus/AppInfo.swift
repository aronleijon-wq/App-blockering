import Foundation

/// Contact details and legal links shown in the app and the privacy policy.
enum AppInfo {
    /// Who is responsible for the data (personuppgiftsansvarig) under GDPR.
    static let developerName = "Aron Leijon"
    static let supportEmail = "aron@pausapp.net"

    /// Apple's standard license agreement, which App Store subscriptions may use as their terms of use.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static let websiteURL = URL(string: "https://pausewebb.lovable.app")!
    static let helpURL = URL(string: "https://pausewebb.lovable.app/support")!
    /// Where invited friends land.
    static let inviteURL = URL(string: "https://apps.apple.com/app/id6825835642")!

    /// The text that goes with an invite, with the player's friend code so the friend can add them in the league.
    static func inviteMessage(nickname: String?, code: String) -> String {
        let name = nickname.map { L(" Mitt smeknamn är \($0).") } ?? ""
        return L("Jag kör Paus för att scrolla mindre 📵 Utmana mig i ligan – den som scrollar minst vinner veckan!\(name) Lägg till mig med koden \(code) under Liga > Vänner.")
    }

    /// "0.1.0 (1)", from the bundle.
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    static var supportMailURL: URL? {
        URL(string: "mailto:\(supportEmail)?subject=Paus")
    }
}
