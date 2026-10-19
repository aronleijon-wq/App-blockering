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
    /// The yearly price per month, rounded down so it never overstates the deal, such as "18 kr".
    private(set) var yearlyPerMonth: String?
    /// How much cheaper the yearly plan is than twelve months, in whole percent.
    private(set) var yearlySavingsPercent: Int?
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
            loadPrices(from: products)
        }
        guard active != isPro else { return }
        isPro = active
        SharedStore.isPro = active
        onChange?(active)
    }

    private func loadPrices(from products: [Product]) {
        let monthly = products.first { $0.id == Self.monthlyProductID }
        let yearly = products.first { $0.id == Self.yearlyProductID }
        monthlyPrice = monthly?.displayPrice
        yearlyPrice = yearly?.displayPrice
        guard let yearly else { return }

        let perMonth = NSDecimalNumber(decimal: yearly.price / 12).rounding(accordingToBehavior: Self.roundDown).decimalValue
        yearlyPerMonth = perMonth.formatted(yearly.priceFormatStyle.precision(.fractionLength(0)))
        if let monthly, monthly.price > 0 {
            let ratio = NSDecimalNumber(decimal: yearly.price / (monthly.price * 12)).doubleValue
            yearlySavingsPercent = Int(((1 - ratio) * 100).rounded(.down))
        }
    }

    private static let roundDown = NSDecimalNumberHandler(
        roundingMode: .down, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false
    )
}
