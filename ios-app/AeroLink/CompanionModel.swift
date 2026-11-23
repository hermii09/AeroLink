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

    private let health = HealthKitWriter()
    private var receiver: HealthPeripheral?
    private var savedEventIDs = Set(UserDefaults.standard.stringArray(forKey: "saved-health-event-ids") ?? [])

    init() { readings = ActivityDataStore.load() }

    var todaySteps: Int {
        let calendar = Calendar.current
        return Int(readings.filter { $0.metric == .steps && calendar.isDateInToday($0.end) }
            .reduce(0) { $0 + $1.value }.rounded())
    }

    var latestSleep: HealthReading? {
        readings.filter { $0.metric == .sleep }.max { $0.end < $1.end }
    }

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

    func requestWriteAccess() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw CompanionError.healthUnavailable
        }
        let types: Set<HKSampleType> = [HKObjectType.quantityType(forIdentifier: .stepCount)!]
        try await store.requestAuthorization(toShare: types, read: [])
    }

    func save(_ reading: HealthReading) async throws {
        guard reading.isValid, reading.metric == .steps,
              let type = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw CompanionError.invalidReading
        }
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: .count(), doubleValue: reading.value),
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
