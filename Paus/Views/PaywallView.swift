import StoreKit
import SwiftUI

/// Paus Pro, monthly or yearly after a free week. The yearly plan is chosen from the start since it is the
/// better deal, and the close button fades in after a few seconds so the offer gets read before it is closed.
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID = Store.yearlyProductID
    @State private var showsClose = false
    @State private var isPurchasing = false
    @State private var isPrivacyPresented = false
    @State private var errorMessage: String?
    /// True while the prices are being fetched, the automatic retries included.
    @State private var isLoadingPrices = true

    /// How long the offer shows before it can be closed.
    private static let closeDelay: Duration = .seconds(3)

    private var store: Store { model.store }
    private var selected: Product? { store.products.first { $0.id == selectedID } }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                MascotView(mood: .hyped, level: max(model.progress.level, 6), size: 120)
                    .padding(.top, 28)
                Text("Paus Pro")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.brand)
                Text(L("Ta tillbaka din tid på riktigt."))
                    .font(.title3.weight(.semibold))

                VStack(alignment: .leading, spacing: 12) {
                    Benefit(symbol: "calendar", text: L("Obegränsat antal scheman"))
                    Benefit(symbol: "hourglass", text: L("Daglig gräns för scrollandet"))
                    Benefit(symbol: "lock.fill", text: L("Strikt fokus som inte går att fuska bort"))
                    Benefit(symbol: "sparkles", text: L("Personliga tips och pepp från Pip, med AI"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

                if store.products.isEmpty, !store.canLoadProducts, !isLoadingPrices {
                    VStack(spacing: 12) {
                        Text(L("Priserna kunde inte hämtas från App Store just nu. Kontrollera internet och försök igen."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button(L("Försök igen")) {
                            Task {
                                isLoadingPrices = true
                                await store.loadProducts()
                                isLoadingPrices = false
                            }
                        }
                        .buttonStyle(ChipButtonStyle())
                    }
                    .padding(.vertical, 18)
                } else if store.products.isEmpty {
                    ProgressView(L("Laddar priser…"))
                        .padding(.vertical, 30)
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.products, id: \.id) { product in
                            PlanRow(
                                product: product,
                                isSelected: product.id == selectedID,
                                savingsPercent: product.id == Store.yearlyProductID ? store.yearlySavingsPercent : nil,
                                perMonth: product.id == Store.yearlyProductID ? store.yearlyPerMonth : nil
                            ) {
                                selectedID = product.id
                            }
                        }
                    }
                }

                Button {
                    Task { await buy() }
                } label: {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(buttonTitle)
                    }
                }
                .buttonStyle(GlowButtonStyle())
                .disabled(selected == nil || isPurchasing)

                if let selected {
                    Text(terms(for: selected))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 18) {
                    Button(L("Återställ köp")) { Task { await store.restore(); if store.isPro { dismiss() } } }
                    Link(L("Villkor"), destination: AppInfo.termsURL)
                    Button(L("Integritetspolicy")) { isPrivacyPresented = true }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.backdrop.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if showsClose {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .accessibilityLabel(L("Stäng"))
                .padding(16)
                .transition(.opacity)
            }
        }
        // Until the close button shows, the sheet can't be swiped away either.
        .interactiveDismissDisabled(!showsClose)
        .task {
            await store.refresh()
            // A slow or briefly unreachable App Store gets a few more tries before the user is asked to retry.
            for _ in 0..<3 where store.products.isEmpty {
                try? await Task.sleep(for: .seconds(3))
                await store.loadProducts()
            }
            isLoadingPrices = false
        }
        .task {
            try? await Task.sleep(for: Self.closeDelay)
            withAnimation(.easeIn(duration: 0.6)) { showsClose = true }
        }
        .sheet(isPresented: $isPrivacyPresented) {
            NavigationStack { PrivacyPolicyView() }
        }
        .alert(L("Något gick fel"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(L("Okej"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .tint(Theme.pink)
    }

    private var trialDays: Int? {
        guard store.isEligibleForTrial, let offer = selected?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else {
            return nil
        }
        switch offer.period.unit {
        case .day: return offer.period.value
        case .week: return offer.period.value * 7
        case .month: return offer.period.value * 30
        case .year: return offer.period.value * 365
        @unknown default: return nil
        }
    }

    private var buttonTitle: String {
        if let trialDays { return L("Starta \(trialDays) dagar gratis") }
        return L("Fortsätt")
    }

    /// What the subscription costs and how it renews, which Apple requires next to the buy button.
    private func terms(for product: Product) -> String {
        let price = product.id == Store.yearlyProductID ? L("\(product.displayPrice) per år") : L("\(product.displayPrice) per månad")
        if let trialDays {
            return L("\(trialDays) dagar gratis, sedan \(price). Förnyas automatiskt tills du säger upp minst 24 timmar innan perioden slutar. Säg upp när du vill i App Store-inställningarna.")
        }
        return L("\(price). Förnyas automatiskt tills du säger upp minst 24 timmar innan perioden slutar. Säg upp när du vill i App Store-inställningarna.")
    }

    private func buy() async {
        guard let selected else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if let transaction = try await store.purchase(selected) {
                Reminders.scheduleTrialEnd(for: transaction, daysBefore: IntroStore.trialReminderDays)
                dismiss()
            }
        } catch {
            errorMessage = L("Köpet gick inte igenom. Försök igen.")
        }
    }
}

/// One plan to choose; the yearly one carries the savings and its price per month.
private struct PlanRow: View {
    let product: Product
    let isSelected: Bool
    let savingsPercent: Int?
    let perMonth: String?
    let onSelect: () -> Void

    private var isYearly: Bool { product.id == Store.yearlyProductID }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.mint : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(isYearly ? L("Årsvis") : L("Månadsvis"))
                        .font(.headline)
                    Text(isYearly ? L("\(product.displayPrice) per år") : L("\(product.displayPrice) per månad"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let perMonth {
                    Text(L("\(perMonth)/mån"))
                        .font(.headline.monospacedDigit())
                }
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? AnyShapeStyle(Theme.glow) : AnyShapeStyle(Color.white.opacity(0.1)), lineWidth: isSelected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if let savingsPercent, savingsPercent > 0 {
                    Text(L("Spara \(savingsPercent) %"))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.glow, in: Capsule())
                        .offset(x: -12, y: -11)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
