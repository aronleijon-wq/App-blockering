import CloudKit
import Foundation

/// Finds out whether a newer Paus is in the App Store, and whether this one is still allowed in.
/// The newest version comes from the App Store's lookup; the oldest allowed from the `AppConfig` record
/// "app-config" in CloudKit's public database (field `minimumVersion`, a string such as "2.6"), which can be
/// raised at any time without a new release. Without that record, nobody is ever locked out.
enum AppUpdateChecker {
    static let appStoreID = "6825835642"
    static var storeURL: URL { URL(string: "itms-apps://apps.apple.com/app/id\(appStoreID)")! }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static func check() async -> AppVersion.Need {
        async let latest = latestInStore()
        async let minimum = minimumAllowed()
        return await AppVersion.need(current: currentVersion, latest: latest, minimum: minimum)
    }

    private static func latestInStore() async -> String? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let country = Locale.current.region?.identifier.lowercased() ?? "us"
        // The time keeps a cached answer from hiding a release.
        let stamp = Int(Date.now.timeIntervalSince1970 / 3600)
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)&country=\(country)&t=\(stamp)") else { return nil }
        struct Lookup: Decodable {
            struct Result: Decodable { let version: String }
            let results: [Result]
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let lookup = try? JSONDecoder().decode(Lookup.self, from: data) else { return nil }
        return lookup.results.first?.version
    }

    private static func minimumAllowed() async -> String? {
        let identifier = Bundle.main.object(forInfoDictionaryKey: "PausCloudContainer") as? String ?? "iCloud.se.aronleijon.paus"
        let database = CKContainer(identifier: identifier).publicCloudDatabase
        guard let record = try? await database.record(for: CKRecord.ID(recordName: "app-config")) else { return nil }
        return record["minimumVersion"] as? String
    }
}
