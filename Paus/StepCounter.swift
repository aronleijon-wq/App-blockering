import HealthKit

/// Reads step counts from Health for step sessions. Paus only reads, and the count never leaves the phone.
enum StepCounter {
    private static let store = HKHealthStore()
    private static let stepCount = HKQuantityType(.stepCount)

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Shows Health's permission sheet the first time. iOS never tells an app whether reading was allowed;
    /// when it wasn't, Paus simply finds no steps.
    static func requestAccess() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: [], read: [stepCount])
    }

    /// Steps walked from `start` until now, or nil when Health can't be read at all.
    static func steps(since start: Date) async -> Int? {
        guard isAvailable else { return nil }
        let since = HKQuery.predicateForSamples(withStart: start, end: .now)
        let query = HKStatisticsQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: stepCount, predicate: since),
            options: .cumulativeSum
        )
        do {
            let statistics = try await query.result(for: store)
            return Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
        } catch let error as HKError where error.code == .errorNoData {
            return 0
        } catch {
            return nil
        }
    }
}
