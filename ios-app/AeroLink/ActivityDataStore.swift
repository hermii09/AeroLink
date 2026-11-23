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

enum ActivityDataStore {
    static let appGroup = "group.app.aerolink.ios"
    private static let key = "aerolink.activity-readings.v1"

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
}
