import Combine
import Foundation
import HealthKit

@MainActor
final class CompanionModel: ObservableObject {
    @Published private(set) var healthReady = false
    @Published private(set) var receiverRunning = false
    @Published private(set) var status = "Health access has not been requested."

    private let health = HealthKitWriter()
    private var receiver: HealthPeripheral?
    private var savedEventIDs = Set(UserDefaults.standard.stringArray(forKey: "saved-health-event-ids") ?? [])

    func enableHealthSync() async {
        do {
            try await health.requestWriteAccess()
            healthReady = true
            status = "Health permission request finished. Start the watch receiver when nearby."
        } catch {
            status = "Health permission setup failed: \(error.localizedDescription)"
        }
    }

    func startReceiver() {
        guard healthReady else {
            status = "Allow Health access before starting sync."
            return
        }
        guard receiver == nil else { return }
        let peripheral = HealthPeripheral { [weak self] reading, completion in
            Task { @MainActor in
                do {
                    guard let self else { completion(false); return }
                    if !self.savedEventIDs.contains(reading.eventID) {
                        try await self.health.save(reading)
                        self.savedEventIDs.insert(reading.eventID)
                        if self.savedEventIDs.count > 2_000 {
                            self.savedEventIDs = Set(self.savedEventIDs.suffix(1_000))
                        }
                        UserDefaults.standard.set(Array(self.savedEventIDs), forKey: "saved-health-event-ids")
                    }
                    self.status = "Saved a \(reading.metric.displayName) sample to Apple Health."
                    completion(true)
                } catch {
                    self?.status = "Could not save sample: \(error.localizedDescription)"
                    completion(false)
                }
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
        status = "Health receiver stopped."
    }
}

enum HealthMetric: String, Decodable {
    case steps
    case heartRate

    var displayName: String { self == .steps ? "steps" : "heart-rate" }

    var quantityType: HKQuantityTypeIdentifier {
        self == .steps ? .stepCount : .heartRate
    }
}

struct HealthReading: Decodable {
    let eventID: String
    let metric: HealthMetric
    let value: Double
    let unit: String
    let start: Date
    let end: Date
}

private final class HealthKitWriter {
    private let store = HKHealthStore()

    func requestWriteAccess() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw CompanionError.healthUnavailable
        }
        let types: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
        ]
        try await store.requestAuthorization(toShare: types, read: [])
    }

    func save(_ reading: HealthReading) async throws {
        guard reading.value.isFinite, reading.value >= 0,
              reading.start <= reading.end,
              reading.end.timeIntervalSince(reading.start) <= 90 * 86_400,
              UUID(uuidString: reading.eventID) != nil,
              (reading.metric == .steps && reading.unit == "count") ||
                (reading.metric == .heartRate && reading.unit == "countPerMinute") else {
            throw CompanionError.invalidReading
        }
        let identifier = reading.metric.quantityType
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw CompanionError.invalidReading
        }
        let unit: HKUnit = reading.metric == .steps
            ? HKUnit.count()
            : HKUnit.count().unitDivided(by: HKUnit.minute())
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: unit, doubleValue: reading.value),
            start: reading.start,
            end: reading.end,
            metadata: [HKMetadataKeySyncIdentifier: reading.eventID, HKMetadataKeySyncVersion: 1]
        )
        try await store.save(sample)
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
