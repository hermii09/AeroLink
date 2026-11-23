import SwiftUI
import WidgetKit

private struct ActivityEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let sleepMinutes: Int?

    static func current() -> ActivityEntry {
        let readings = ActivityDataStore.load()
        let today = readings.filter { $0.metric == .steps && Calendar.current.isDateInToday($0.end) }
        let sleep = readings.filter { $0.metric == .sleep }.max { $0.end < $1.end }
        return ActivityEntry(date: .now,
                             steps: Int(today.reduce(0) { $0 + $1.value }.rounded()),
                             sleepMinutes: sleep.map { Int($0.value.rounded()) })
    }
}

private struct ActivityProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActivityEntry { ActivityEntry(date: .now, steps: 4_286, sleepMinutes: nil) }
    func getSnapshot(in context: Context, completion: @escaping (ActivityEntry) -> Void) { completion(.current()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ActivityEntry>) -> Void) {
        completion(Timeline(entries: [.current()], policy: .after(.now.addingTimeInterval(15 * 60))))
    }
}

private struct ActivityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ActivityEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: min(Double(entry.steps), 10_000), in: 0...10_000) {
                Image(systemName: "figure.walk")
            } currentValueLabel: {
                Text(entry.steps.formatted())
            }
            .gaugeStyle(.accessoryCircular)
            .widgetURL(URL(string: "aerolink://activity"))
        case .accessoryInline:
            Label("\(entry.steps.formatted()) steps", systemImage: "figure.walk")
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Label("Activity", systemImage: "figure.walk")
                Text("\(entry.steps.formatted()) steps today").font(.headline)
            }
            .widgetURL(URL(string: "aerolink://activity"))
        default:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Activity", systemImage: "figure.walk").font(.headline).foregroundStyle(.cyan)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(entry.steps.formatted()).font(.system(size: family == .systemSmall ? 30 : 38, weight: .bold, design: .rounded))
                    Text("steps").font(.subheadline).foregroundStyle(.secondary)
                }
                ProgressView(value: min(Double(entry.steps), 10_000), total: 10_000).tint(.cyan)
                Text("Today").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .widgetURL(URL(string: "aerolink://activity"))
            .containerBackground(Color(uiColor: .secondarySystemGroupedBackground), for: .widget)
        }
    }
}

struct AeroLinkActivityWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AeroLinkActivityWidget", provider: ActivityProvider()) { entry in
            ActivityWidgetView(entry: entry)
        }
        .configurationDisplayName("AeroLink Activity")
        .description("See step totals received from your Galaxy Watch.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct SleepWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ActivityEntry

    private var titleValue: String {
        guard let minutes = entry.sleepMinutes else { return "No sleep data" }
        return "\(minutes / 60) hr \(minutes % 60) min"
    }

    var body: some View {
        if family == .accessoryInline {
            Label(entry.sleepMinutes == nil ? "Sleep unavailable" : titleValue, systemImage: "bed.double.fill")
        } else {
            VStack(alignment: .leading, spacing: 9) {
                Label("Sleep", systemImage: "bed.double.fill").font(.headline).foregroundStyle(.indigo)
                Text(titleValue).font(.system(size: 25, weight: .bold, design: .rounded))
                Text(entry.sleepMinutes == nil ? "Needs watch sleep sync" : "Latest session")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .widgetURL(URL(string: "aerolink://sleep"))
            .containerBackground(Color(uiColor: .secondarySystemGroupedBackground), for: .widget)
        }
    }
}

struct AeroLinkSleepWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AeroLinkSleepWidget", provider: ActivityProvider()) { entry in
            SleepWidgetView(entry: entry)
        }
        .configurationDisplayName("AeroLink Sleep")
        .description("See the latest sleep session synced to AeroLink.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct AeroLinkWidgetBundle: WidgetBundle {
    var body: some Widget {
        AeroLinkActivityWidget()
        AeroLinkSleepWidget()
    }
}
