import Foundation
import Observation
import StoreKit

/// Paus Pro, sold monthly (29 kr) or yearly (219 kr), both after a free week. Prices and the trial are set
/// in App Store Connect, and in `Config/Paus.storekit` for testing in Xcode.
@MainActor
@Observable
final class Store {
    static let monthlyProductID = "paus.pro.monthly"
    static let yearlyProductID = "paus.pro.yearly"
    /// Yearly first, so the subscription view leads with the better deal.
    static let proProductIDs = [yearlyProductID, monthlyProductID]

    private(set) var isPro = SharedStore.isPro
    /// Localized prices from the App Store, such as "29,00 kr", once loaded.
    private(set) var monthlyPrice: String?
    private(set) var yearlyPrice: String?
    /// Called when the entitlement changes, so rules can be re-applied.
    @ObservationIgnored var onChange: (@MainActor (Bool) -> Void)?
    @ObservationIgnored private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.proProductIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        if monthlyPrice == nil, let products = try? await Product.products(for: Self.proProductIDs) {
            monthlyPrice = products.first { $0.id == Self.monthlyProductID }?.displayPrice
            yearlyPrice = products.first { $0.id == Self.yearlyProductID }?.displayPrice
        }
        guard active != isPro else { return }
        isPro = active
        SharedStore.isPro = active
        onChange?(active)
    }
}
