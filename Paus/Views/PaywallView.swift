import StoreKit
import SwiftUI

/// Paus Pro: 19 kr per month after a free week. Apple's subscription view handles price, trial and terms.
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: [Store.proProductID]) {
            VStack(spacing: 16) {
                MascotView(mood: .hyped, level: max(model.progress.level, 6), size: 130)
                Text("Paus Pro")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.brand)
                Text("Ta tillbaka din tid på riktigt.")
                    .font(.title3.weight(.semibold))
                VStack(alignment: .leading, spacing: 12) {
                    Benefit(symbol: "calendar", text: "Obegränsat antal scheman")
                    Benefit(symbol: "hourglass", text: "Daglig gräns för scrollandet")
                    Benefit(symbol: "lock.fill", text: "Strikt fokus som inte går att fuska bort")
                    Benefit(symbol: "sparkles", text: "Pip pratar personligt med dig med AI")
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
        .subscriptionStoreControlStyle(.prominentPicker)
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success) = result {
                await model.store.refresh()
                dismiss()
            }
        }
        .tint(Theme.pink)
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
