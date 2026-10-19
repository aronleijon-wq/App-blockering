import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen iOS shows instead of a blocked app or website.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(name: webDomain.domain)
    }

    private func makeConfiguration(name: String?) -> ShieldConfiguration {
        let now = Date.now
        let engine = BlockEngine(rules: SharedStore.rules, runtime: SharedStore.runtime)
        let canPause = engine.canPause(at: now)
        let tint = UIColor(red: 0.13, green: 0.55, blue: 0.53, alpha: 1)

        let title = name.map { "\($0) är pausad" } ?? "Det här är pausat"
        var subtitle = engine.reason(at: now).map { Format.reason($0) + "." } ?? "Den här appen är blockerad just nu."
        if canPause {
            subtitle += " Behöver du ändå in? Ta en paus – först andas du en stund."
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: nil,
            icon: UIImage(systemName: "pause.circle.fill")?.withTintColor(tint, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: title, color: .label),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Stäng", color: .white),
            primaryButtonBackgroundColor: tint,
            secondaryButtonLabel: canPause ? ShieldConfiguration.Label(text: "Ta en paus", color: tint) : nil
        )
    }
}
