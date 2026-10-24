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
    /// The products from the App Store, yearly first, once loaded.
    private(set) var products: [Product] = []
    /// Whether this Apple ID can still get the free week.
    private(set) var isEligibleForTrial = true
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
        if products.isEmpty, let loaded = try? await Product.products(for: Self.proProductIDs) {
            products = Self.proProductIDs.compactMap { id in loaded.first { $0.id == id } }
            loadPrices(from: loaded)
        }
        if let subscription = products.first?.subscription {
            isEligibleForTrial = await subscription.isEligibleForIntroOffer
        }
        guard active != isPro else { return }
        isPro = active
        SharedStore.isPro = active
        onChange?(active)
    }

    /// Buys `product` and returns the verified transaction, or nil if the user cancelled or it awaits approval.
    func purchase(_ product: Product) async throws -> Transaction? {
        switch try await product.purchase() {
        case .success(.verified(let transaction)):
            await transaction.finish()
            await refresh()
            return transaction
        case .success(.unverified), .pending, .userCancelled:
            return nil
        @unknown default:
            return nil
        }
    }

    /// Asks the App Store for the purchases on this Apple ID, for someone who bought Pro on another phone.
    func restore() async {
        try? await AppStore.sync()
        await refresh()
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
