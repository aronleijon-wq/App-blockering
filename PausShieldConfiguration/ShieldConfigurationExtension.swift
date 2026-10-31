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

        let title = name.map { L("Pip säger nej till \($0)") } ?? L("Pip säger nej")
        var subtitle = engine.reason(at: now).map { Format.reason($0) + "." } ?? L("Den här appen är blockerad just nu.")
        if earnsXP {
            subtitle += L(" Stäng nu och få +\(PlayerProgress.XP.close) XP.")
        }
        if case .stepFocus = engine.reason(at: now) {
            subtitle += L(" Öppna Paus när du har gått klart.")
        }
        let stage = progress.healthStage
        if stage <= .down {
            subtitle += L("\n\nPip mår \(stage == .wrecked ? L("jättedåligt") : stage == .sick ? L("dåligt") : L("lite sådär")) (\(progress.health) %). En paus gör Pip ledsnare.")
        }

        // A pause is the gentle way out. Where there is none, SOS takes its place: one tap asks, the second unblocks.
        let secondary: ShieldConfiguration.Label?
        if canPause {
            secondary = ShieldConfiguration.Label(text: penalty == 0 ? L("Ta en paus (gratis)") : L("Ta en paus (−\(penalty) XP)"), color: pink)
        } else if engine.isSOSRequested(at: now) {
            let cost = progress.nextSOSPenalty(at: now, calendar: .current)
            secondary = ShieldConfiguration.Label(text: L("Tryck igen: lås upp allt (−\(cost) p)"), color: pink)
        } else {
            secondary = ShieldConfiguration.Label(text: L("SOS – lås upp"), color: UIColor.white.withAlphaComponent(0.6))
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: background,
            icon: UIImage(systemName: "face.smiling.inverse")?.withTintColor(pink, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor.white.withAlphaComponent(0.75)),
            primaryButtonLabel: ShieldConfiguration.Label(text: earnsXP ? L("Stäng (+\(PlayerProgress.XP.close) XP)") : L("Stäng"), color: .white),
            primaryButtonBackgroundColor: pink,
            secondaryButtonLabel: secondary
        )
    }
}
