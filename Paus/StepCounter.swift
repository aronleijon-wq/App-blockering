import HealthKit

/// Reads step counts for step sessions from Health, which includes an Apple Watch, and from the phone's own
/// motion chip, which still works while the phone is locked. Paus only reads, and the count never leaves the phone.
enum StepCounter {
    private static let store = HKHealthStore()
    private static let stepCount = HKQuantityType(.stepCount)

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Shows Health's permission sheet the first time. iOS never tells an app whether reading was allowed;
    /// when it wasn't, Paus simply finds no steps.
    static func requestAccess() async {
        if isAvailable {
            try? await store.requestAuthorization(toShare: [], read: [stepCount])
        }
        // Asks for Motion & Fitness access.
        _ = await Pedometer.steps(since: Date.now.addingTimeInterval(-60))
    }

    /// Steps walked from `start` until now, the higher of the two counts, or nil when neither can be read.
    static func steps(since start: Date) async -> Int? {
        async let health = healthSteps(since: start)
        async let phone = Pedometer.steps(since: start)
        return [await health, await phone].compactMap { $0 }.max()
    }

    /// Health can't be read while the phone is locked, which is when the motion chip takes over.
    private static func healthSteps(since start: Date) async -> Int? {
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
