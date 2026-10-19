import Foundation
import Observation
import StoreKit

/// The Paus Pro subscription. The price (19 kr/month) and the free trial are set in App Store Connect,
/// and in `Config/Paus.storekit` for testing in Xcode.
@MainActor
@Observable
final class Store {
    static let proProductID = "paus.pro.monthly"

    private(set) var isPro = SharedStore.isPro
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
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                active = true
            }
        }
        guard active != isPro else { return }
        isPro = active
        SharedStore.isPro = active
        onChange?(active)
    }
}
