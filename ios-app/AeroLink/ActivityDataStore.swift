import Foundation

enum HealthMetric: String, Codable {
    case steps
    case sleep

    var displayName: String { self == .steps ? "steps" : "sleep" }
}

struct HealthReading: Codable, Identifiable {
    var id: String { eventID }
    let eventID: String
    let metric: HealthMetric
    let value: Double
    let unit: String
    let start: Date
    let end: Date

    var isValid: Bool {
        guard value.isFinite, value >= 0, start <= end,
              end.timeIntervalSince(start) <= 90 * 86_400,
              UUID(uuidString: eventID) != nil else { return false }
        switch metric {
        case .steps: return unit == "count"
        case .sleep: return unit == "minutes" && value <= 24 * 60
        }
    }
}

struct StepPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct HealthDaySummary: Codable, Identifiable {
    let date: Date
    let steps: Double
    var id: String { String(Int(date.timeIntervalSince1970)) }
}

struct SleepSessionSummary: Codable, Identifiable {
    let id: String
    let start: Date
    let end: Date
    let asleepMinutes: Double
}

struct HealthSnapshot: Codable {
    let updatedAt: Date
    let steps: [HealthDaySummary]
    let sleep: [SleepSessionSummary]
}

enum ActivityDataStore {
    static let appGroup = "group.app.aerolink.ios"
    private static let key = "aerolink.activity-readings.v1"
    private static let healthSnapshotKey = "aerolink.health-snapshot.v1"

    private static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static func load() -> [HealthReading] {
        guard let data = defaults.data(forKey: key),
              let result = try? JSONDecoder().decode([HealthReading].self, from: data) else { return [] }
        return result
    }

    static func save(_ readings: [HealthReading]) {
        guard let data = try? JSONEncoder().encode(readings) else { return }
        defaults.set(data, forKey: key)
    }

    static func loadHealthSnapshot() -> HealthSnapshot? {
        guard let data = defaults.data(forKey: healthSnapshotKey) else { return nil }
        return try? JSONDecoder().decode(HealthSnapshot.self, from: data)
    }

    static func saveHealthSnapshot(_ snapshot: HealthSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: healthSnapshotKey)
    }
}
