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
        let engine = BlockEngine(rules: SharedStore.effectiveRules, runtime: SharedStore.runtime)
        let canPause = engine.canPause(at: now)
        let progress = SharedStore.progress
        let closesToday = progress.counts(at: now, calendar: .current).closes
        let penalty = progress.nextPausePenalty(at: now, calendar: .current)
        let earnsXP = closesToday < PlayerProgress.XP.closeDailyCap
        let pink = UIColor(red: 1.0, green: 0.31, blue: 0.64, alpha: 1)
        let background = UIColor(red: 0.055, green: 0.043, blue: 0.122, alpha: 1)

        let title = name.map { "Pip säger nej till \($0)" } ?? "Pip säger nej"
        var subtitle = engine.reason(at: now).map { Format.reason($0) + "." } ?? "Den här appen är blockerad just nu."
        if earnsXP {
            subtitle += " Stäng nu och få +\(PlayerProgress.XP.close) XP."
        }
        let stage = progress.healthStage
        if stage <= .down {
            subtitle += "\n\nPip mår \(stage == .wrecked ? "jättedåligt" : stage == .sick ? "dåligt" : "lite sådär") (\(progress.health) %). En paus gör Pip ledsnare."
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: background,
            icon: UIImage(systemName: "face.smiling.inverse")?.withTintColor(pink, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor.white.withAlphaComponent(0.75)),
            primaryButtonLabel: ShieldConfiguration.Label(text: earnsXP ? "Stäng (+\(PlayerProgress.XP.close) XP)" : "Stäng", color: .white),
            primaryButtonBackgroundColor: pink,
            secondaryButtonLabel: canPause
                ? ShieldConfiguration.Label(text: penalty == 0 ? "Ta en paus (gratis)" : "Ta en paus (−\(penalty) poäng)", color: pink)
                : nil
        )
    }
}
