import StoreKit
import SwiftUI

/// Paus Pro, monthly or yearly after a free week. Apple's subscription view handles prices, trial and terms.
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: Store.proProductIDs) {
            VStack(spacing: 16) {
                MascotView(mood: .hyped, level: max(model.progress.level, 6), size: 130)
                Text("Paus Pro")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.brand)
                Text(L("Ta tillbaka din tid på riktigt."))
                    .font(.title3.weight(.semibold))
                if let perMonth = model.store.yearlyPerMonth {
                    Text(yearlyDeal(perMonth: perMonth))
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.glow, in: Capsule())
                }
                VStack(alignment: .leading, spacing: 12) {
                    Benefit(symbol: "calendar", text: L("Obegränsat antal scheman"))
                    Benefit(symbol: "hourglass", text: L("Daglig gräns för scrollandet"))
                    Benefit(symbol: "lock.fill", text: L("Strikt fokus som inte går att fuska bort"))
                    Benefit(symbol: "sparkles", text: L("Personliga tips och pepp från Pip, med AI"))
                }
                .padding(.top, 4)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Theme.backdrop)
        }
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStorePolicyDestination(url: AppInfo.termsURL, for: .termsOfService)
        .subscriptionStorePolicyDestination(for: .privacyPolicy) {
            NavigationStack { PrivacyPolicyView() }
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success(let verification)) = result {
                if case .verified(let transaction) = verification {
                    Reminders.scheduleTrialEnd(for: transaction, daysBefore: IntroStore.trialReminderDays)
                }
                await model.store.refresh()
                dismiss()
            }
        }
        .tint(Theme.pink)
    }

    private func yearlyDeal(perMonth: String) -> String {
        guard let savings = model.store.yearlySavingsPercent, savings > 0 else {
            return L("Årspris: bara \(perMonth)/mån")
        }
        return L("Årspris: bara \(perMonth)/mån · spara \(savings) %")
    }
}

private struct Benefit: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 34, height: 34)
                .background(Theme.glow, in: Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(.body.weight(.medium))
        }
    }
}
