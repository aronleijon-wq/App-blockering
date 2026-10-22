import StoreKit
import SwiftUI

/// Account, protection, support and legal, opened from the profile button on the home screen.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isManagingSubscription = false
    @State private var isPaywallPresented = false
    @State private var didReload = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    planCard

                    SettingsGroup(title: "Konto") {
                        NavigationLink {
                            AccountView()
                        } label: {
                            SettingsRow(
                                symbol: "person.crop.circle.fill",
                                title: model.firstName ?? "Mitt konto",
                                detail: model.account == nil ? "Skapa konto eller logga in" : "Inloggad med Apple",
                                accessory: .chevron
                            )
                        }
                    }

                    SettingsGroup(title: "Skydd") {
                        Toggle(isOn: Binding(
                            get: { model.effectiveRules.preventUninstall },
                            set: { newValue in
                                if model.isPro {
                                    model.updateRules { $0.preventUninstall = newValue }
                                } else {
                                    isPaywallPresented = true
                                }
                            }
                        )) {
                            SettingsRow(
                                symbol: "lock.shield.fill",
                                title: "Avinstallationsskydd",
                                detail: "Appar, även Paus, går inte att radera medan något är blockerat.",
                                badge: model.isPro ? nil : "PRO"
                            )
                        }
                        .disabled(model.isStrictFocusActive && model.effectiveRules.preventUninstall)
                        SettingsDivider()
                        Toggle(isOn: Binding(
                            get: { model.rules.adultFilter },
                            set: { newValue in model.updateRules { $0.adultFilter = newValue } }
                        )) {
                            SettingsRow(
                                symbol: "18.circle.fill",
                                title: "Vuxenfilter",
                                detail: "Apples filter mot vuxensajter i Safari, alltid på."
                            )
                        }
                        SettingsDivider()
                        NavigationLink {
                            VacationView()
                        } label: {
                            SettingsRow(
                                symbol: "beach.umbrella.fill",
                                title: "Semesterläge",
                                detail: vacationDetail,
                                accessory: .chevron
                            )
                        }
                    }

                    SettingsGroup(title: "Support") {
                        if let mail = AppInfo.supportMailURL {
                            Link(destination: mail) {
                                SettingsRow(symbol: "bubble.left.and.bubble.right.fill", title: "Kontakta support", accessory: .external)
                            }
                            SettingsDivider()
                        }
                        Link(destination: AppInfo.helpURL) {
                            SettingsRow(symbol: "book.fill", title: "Hjälpcenter", accessory: .external)
                        }
                        SettingsDivider()
                        Button {
                            model.reapplyEverything()
                            didReload = true
                        } label: {
                            SettingsRow(
                                symbol: "arrow.clockwise",
                                title: "Ladda om Paus",
                                detail: didReload ? "Klart! Regler och blockeringar är på plats igen." : "Lägger på dina regler och blockeringar igen om något inte fungerar."
                            )
                        }
                        .sensoryFeedback(.success, trigger: didReload)
                    }

                    SettingsGroup(title: "Dela") {
                        ShareLink(
                            item: AppInfo.websiteURL,
                            subject: Text("Paus"),
                            message: Text("Jag använder Paus för att scrolla mindre. Häng med och tävla mot mig i ligan!")
                        ) {
                            SettingsRow(symbol: "square.and.arrow.up", title: "Dela Paus med en vän", accessory: .chevron)
                        }
                    }

                    SettingsGroup(title: "Övrigt") {
                        Button {
                            Task { await model.restorePurchases() }
                        } label: {
                            SettingsRow(symbol: "arrow.uturn.backward.circle.fill", title: "Återställ köp")
                        }
                        SettingsDivider()
                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            SettingsRow(symbol: "hand.raised.fill", title: "Integritetspolicy", accessory: .chevron)
                        }
                        SettingsDivider()
                        Link(destination: AppInfo.termsURL) {
                            SettingsRow(symbol: "doc.text.fill", title: "Användarvillkor", accessory: .external)
                        }
                    }

                    Text("Paus \(AppInfo.version)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .screenBackground()
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Theme.background)
                            .frame(width: 34, height: 34)
                            .background(Theme.mint, in: Circle())
                    }
                    .accessibilityLabel("Klar")
                }
            }
            .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
            // Presented from here, since the root can't show a second sheet on top of this one.
            .sheet(isPresented: $isPaywallPresented) {
                PaywallView()
            }
        }
    }

    private var vacationDetail: String {
        guard let end = model.rules.vacationUntil, end > .now else { return "Vila scheman och daglig gräns när du är ledig." }
        return "På till \(end.formatted(.dateTime.day().month(.wide)))"
    }

    @ViewBuilder
    private var planCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.isPro {
                Label("Du har Paus Pro", systemImage: "checkmark.seal.fill")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.mint)
                Button("Hantera prenumeration") { isManagingSubscription = true }
                    .buttonStyle(ChipButtonStyle())
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Du har gratisversionen")
                        .font(.title3.bold())
                    HStack(spacing: 4) {
                        Text("Fokusera ännu bättre med")
                        Text("Paus Pro").foregroundStyle(Theme.brand).bold()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 10) {
                    ProPerk(symbol: "lock.fill", text: "Strikt fokus och avinstallationsskydd")
                    ProPerk(symbol: "calendar", text: "Obegränsat antal scheman")
                    ProPerk(symbol: "hourglass", text: "Daglig gräns")
                    ProPerk(symbol: "sparkles", text: "Pip pratar personligt med dig")
                }
                Button(model.store.yearlyPerMonth.map { "Prova gratis, sedan \($0)/mån" } ?? "Prova gratis i 7 dagar") {
                    isPaywallPresented = true
                }
                .buttonStyle(GlowButtonStyle())
            }
        }
        .card(highlighted: !model.isPro)
    }
}

private struct ProPerk: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.mint)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline.weight(.medium))
        }
    }
}

// MARK: - Building blocks

/// A titled, rounded group of rows.
struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
    }
}

struct SettingsRow: View {
    enum Accessory {
        case none, chevron, external
    }

    let symbol: String
    let title: String
    var detail: String?
    var badge: String?
    var accessory: Accessory = .none

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    if badge != nil {
                        ProBadge()
                    }
                }
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            switch accessory {
            case .none:
                EmptyView()
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            case .external:
                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.white.opacity(0.06))
            .padding(.leading, 44)
    }
}

// MARK: - Vacation

/// Rests schedules and the daily limit while the user is away.
private struct VacationView: View {
    @Environment(AppModel.self) private var model

    private let lengths = [1, 3, 7, 14]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "beach.umbrella.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.brand)
                    .symbolEffect(.bounce, value: model.rules.vacationUntil)
                    .padding(.top, 20)
                if let end = model.rules.vacationUntil, end > .now {
                    Text("Semesterläget är på")
                        .font(.title2.bold())
                    Text("Scheman och daglig gräns vilar till \(end.formatted(date: .complete, time: .shortened)). Fokuspass fungerar som vanligt, och Pip bryr sig inte om scrollandet.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Avsluta semestern nu") { model.endVacation() }
                        .buttonStyle(GlowButtonStyle())
                } else {
                    Text("Ta ledigt från reglerna")
                        .font(.title2.bold())
                    Text("Scheman och daglig gräns vilar medan du är borta. Fokuspass fungerar som vanligt, och allt slås på igen av sig självt.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    ForEach(lengths, id: \.self) { days in
                        Button(days == 1 ? "1 dag" : "\(days) dagar") { model.startVacation(days: days) }
                            .buttonStyle(ChipButtonStyle())
                    }
                }
            }
            .padding(20)
        }
        .screenBackground()
        .navigationTitle("Semesterläge")
        .navigationBarTitleDisplayMode(.inline)
    }
}
