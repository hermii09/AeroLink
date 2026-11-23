import Combine
import Foundation
import HealthKit
import WidgetKit

@MainActor
final class CompanionModel: ObservableObject {
    @Published private(set) var healthReady = false
    @Published private(set) var receiverRunning = false
    @Published private(set) var status = "Health access has not been requested."
    @Published private(set) var readings: [HealthReading]
    @Published private(set) var healthSnapshot: HealthSnapshot?

    private let health = HealthKitWriter()
    private var receiver: HealthPeripheral?
    private var savedEventIDs = Set(UserDefaults.standard.stringArray(forKey: "saved-health-event-ids") ?? [])

    init() {
        readings = ActivityDataStore.load()
        healthReady = UserDefaults.standard.bool(forKey: "health-access-requested")
        healthSnapshot = ActivityDataStore.loadHealthSnapshot()
    }

    var todaySteps: Int {
        let calendar = Calendar.current
        if let total = healthSnapshot?.steps.first(where: { calendar.isDateInToday($0.date) }) {
            return Int(total.steps.rounded())
        }
        return Int(readings.filter { $0.metric == .steps && calendar.isDateInToday($0.end) }
            .reduce(0) { $0 + $1.value }.rounded())
    }

    var recentStepDays: [HealthDaySummary] {
        if let days = healthSnapshot?.steps, !days.isEmpty { return days.sorted { $0.date > $1.date } }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: readings.filter { $0.metric == .steps }) {
            calendar.startOfDay(for: $0.end)
        }
        return grouped.map { entry in
            HealthDaySummary(date: entry.key, steps: entry.value.reduce(0) { $0 + $1.value })
        }.sorted { $0.date > $1.date }
    }

    var stepHistorySource: String {
        healthSnapshot?.steps.isEmpty == false ? "Daily totals from Apple Health" : "Step data received from your watch"
    }

    var recentSleepSessions: [SleepSessionSummary] {
        if let sessions = healthSnapshot?.sleep, !sessions.isEmpty { return sessions.sorted { $0.end > $1.end } }
        return readings.filter { $0.metric == .sleep }.map {
            SleepSessionSummary(id: $0.eventID, start: $0.start, end: $0.end, asleepMinutes: $0.value)
        }.sorted { $0.end > $1.end }
    }

    var latestSleep: SleepSessionSummary? { recentSleepSessions.first }

    var sleepHistorySource: String {
        healthSnapshot?.sleep.isEmpty == false ? "Sleep sessions from Apple Health" : "Sleep sessions received from your watch"
    }

    func enableHealthSync() async {
        do {
            try await health.requestAccess()
            healthReady = true
            UserDefaults.standard.set(true, forKey: "health-access-requested")
            status = "Health access request finished. Loading steps and sleep from Apple Health."
            await refreshHealthData()
        } catch {
            status = "Health permission setup failed: \(error.localizedDescription)"
        }
    }

    func refreshHealthData() async {
        guard healthReady else {
            status = "Set up Apple Health to load steps and sleep records."
            return
        }
        do {
            let snapshot = try await health.readRecentSnapshot()
            healthSnapshot = snapshot
            ActivityDataStore.saveHealthSnapshot(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
            if snapshot.steps.isEmpty && snapshot.sleep.isEmpty {
                status = "Apple Health returned no readable step or sleep samples. Check AeroLink Health under Health → Data Access & Devices."
            } else {
                status = "Loaded \(snapshot.steps.count) days of step data and \(snapshot.sleep.count) sleep sessions from Apple Health."
            }
        } catch {
            status = "Could not read Apple Health: \(error.localizedDescription)"
        }
    }

    func startReceiver() {
        guard receiver == nil else { return }
        let peripheral = HealthPeripheral { [weak self] reading, completion in
            Task { @MainActor in
                guard let self else { completion(false); return }
                guard reading.isValid else {
                    self.status = "The watch sent an invalid activity sample."
                    completion(false)
                    return
                }
                if !self.savedEventIDs.contains(reading.eventID) {
                    self.readings.append(reading)
                    self.readings = Array(self.readings.suffix(5_000))
                    ActivityDataStore.save(self.readings)
                    self.savedEventIDs.insert(reading.eventID)
                    if self.savedEventIDs.count > 2_000 {
                        self.savedEventIDs = Set(self.savedEventIDs.suffix(1_000))
                    }
                    UserDefaults.standard.set(Array(self.savedEventIDs), forKey: "saved-health-event-ids")
                }

                if self.healthReady {
                    do {
                        try await self.health.save(reading)
                        self.status = "Received \(reading.metric.displayName); saved to Apple Health."
                        await self.refreshHealthData()
                    } catch {
                        self.status = "Received \(reading.metric.displayName) on this phone. Apple Health save failed: \(error.localizedDescription)"
                    }
                } else {
                    self.status = "Received \(reading.metric.displayName) and saved it in AeroLink."
                }
                WidgetCenter.shared.reloadAllTimelines()
                completion(true)
            }
        }
        peripheral.onState = { [weak self] (running: Bool, message: String) in
            Task { @MainActor in
                self?.receiverRunning = running
                self?.status = message
            }
        }
        receiver = peripheral
        peripheral.start()
    }

    func stopReceiver() {
        receiver?.stop()
        receiver = nil
        receiverRunning = false
        status = "Watch receiver stopped."
    }
}

private final class HealthKitWriter {
    private let store = HKHealthStore()

    func requestAccess() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw CompanionError.healthUnavailable
        }
        guard let steps = HKObjectType.quantityType(forIdentifier: .stepCount),
              let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw CompanionError.healthUnavailable
        }
        try await store.requestAuthorization(toShare: [steps, sleep], read: [steps, sleep])
    }

    func save(_ reading: HealthReading) async throws {
        guard reading.isValid else { throw CompanionError.invalidReading }
        let metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: reading.eventID,
            HKMetadataKeySyncVersion: 1
        ]
        switch reading.metric {
        case .steps:
            guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else {
                throw CompanionError.healthUnavailable
            }
            let sample = HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: .count(), doubleValue: reading.value),
                start: reading.start,
                end: reading.end,
                metadata: metadata
            )
            try await store.save(sample)
        case .sleep:
            guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
                throw CompanionError.healthUnavailable
            }
            let sample = HKCategorySample(
                type: type,
                value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                start: reading.start,
                end: reading.end,
                metadata: metadata
            )
            try await store.save(sample)
        }
    }

    func readRecentSnapshot() async throws -> HealthSnapshot {
        guard HKHealthStore.isHealthDataAvailable() else { throw CompanionError.healthUnavailable }
        let steps = try await readDailySteps(days: 30)
        let sleep = try await readSleepSessions(days: 30)
        return HealthSnapshot(updatedAt: .now, steps: steps, sleep: sleep)
    }

    private func readDailySteps(days: Int) async throws -> [HealthDaySummary] {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw CompanionError.healthUnavailable
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }
        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate),
            options: .cumulativeSum,
            anchorDate: today,
            intervalComponents: DateComponents(day: 1)
        )
        return try await withCheckedThrowingContinuation { continuation in
            query.initialResultsHandler = { _, collection, error in
                if let error { continuation.resume(throwing: error); return }
                var results: [HealthDaySummary] = []
                collection?.enumerateStatistics(from: start, to: .now) { statistics, _ in
                    guard let sum = statistics.sumQuantity()?.doubleValue(for: .count()) else { return }
                    results.append(HealthDaySummary(date: statistics.startDate, steps: sum))
                }
                continuation.resume(returning: results)
            }
            store.execute(query)
        }
    }

    private func readSleepSessions(days: Int) async throws -> [SleepSessionSummary] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw CompanionError.healthUnavailable
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleep.rawValue
                ]
                let categories = (samples as? [HKCategorySample] ?? []).filter {
                    asleepValues.contains($0.value) && $0.endDate > $0.startDate
                }
                let nights = Dictionary(grouping: categories) { sample in
                    let shifted = calendar.date(byAdding: .hour, value: -12, to: sample.endDate) ?? sample.endDate
                    return calendar.startOfDay(for: shifted)
                }
                let sessions = nights.values.compactMap { samples -> SleepSessionSummary? in
                    let sorted = samples.sorted { $0.startDate < $1.startDate }
                    guard let first = sorted.first else { return nil }
                    var intervalStart = first.startDate
                    var intervalEnd = first.endDate
                    var total: TimeInterval = 0
                    for sample in sorted.dropFirst() {
                        if sample.startDate <= intervalEnd {
                            intervalEnd = max(intervalEnd, sample.endDate)
                        } else {
                            total += intervalEnd.timeIntervalSince(intervalStart)
                            intervalStart = sample.startDate
                            intervalEnd = sample.endDate
                        }
                    }
                    total += intervalEnd.timeIntervalSince(intervalStart)
                    let sessionStart = sorted.map(\.startDate).min() ?? first.startDate
                    let sessionEnd = sorted.map(\.endDate).max() ?? first.endDate
                    return SleepSessionSummary(
                        id: String(Int(sessionStart.timeIntervalSince1970)),
                        start: sessionStart,
                        end: sessionEnd,
                        asleepMinutes: total / 60
                    )
                }
                continuation.resume(returning: sessions.sorted { $0.end > $1.end })
            }
            store.execute(query)
        }
    }
}

private enum CompanionError: LocalizedError {
    case healthUnavailable
    case invalidReading

    var errorDescription: String? {
        switch self {
        case .healthUnavailable: return "Apple Health is unavailable on this device."
        case .invalidReading: return "The watch sent an invalid health sample."
        }
    }
}
