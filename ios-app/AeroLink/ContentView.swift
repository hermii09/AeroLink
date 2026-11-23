import Charts
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: CompanionModel

    var body: some View {
        TabView {
            activityPage
                .tabItem { Label("Activity", systemImage: "flame.fill") }
            sleepPage
                .tabItem { Label("Sleep", systemImage: "bed.double.fill") }
            settingsPage
                .tabItem { Label("AeroLink", systemImage: "applewatch") }
        }
        .tint(Color(red: 0.98, green: 0.34, blue: 0.18))
    }

    private var activityPage: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summaryCard
                    chartCard
                    sectionHeader("Recent activity", detail: "Steps received from your watch")
                    let stepReadings = model.readings.filter { $0.metric == .steps }.sorted { $0.end > $1.end }
                    if stepReadings.isEmpty {
                        emptyCard(icon: "figure.walk", title: "No activity yet", message: "Start the receiver and keep your watch nearby. Step intervals will appear here.")
                    } else {
                        ForEach(stepReadings.prefix(24)) { reading in
                            sampleRow(reading, symbol: "figure.walk", tint: Color(red: 0.98, green: 0.34, blue: 0.18))
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().stroke(Color.orange.opacity(0.14), lineWidth: 12)
                Circle().trim(from: 0, to: min(Double(model.todaySteps) / 10_000, 1))
                    .stroke(AngularGradient(colors: [.orange, .pink], center: .center), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "figure.walk").font(.system(size: 25, weight: .semibold)).foregroundStyle(.orange)
            }
            .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text("STEPS TODAY").font(.caption.weight(.bold)).tracking(0.7).foregroundStyle(.secondary)
                Text(model.todaySteps.formatted()).font(.system(size: 32, weight: .bold, design: .rounded)).contentTransition(.numericText())
                Text("of 10,000 goal").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Today", detail: "Synced step intervals")
            let points = todayPoints
            if points.isEmpty {
                Text("Your movement will build here as the watch syncs.")
                    .font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 88, alignment: .center)
            } else {
                Chart(points) { point in
                    BarMark(x: .value("Time", point.date), y: .value("Steps", point.value))
                        .foregroundStyle(LinearGradient(colors: [.orange, .pink], startPoint: .bottom, endPoint: .top))
                        .cornerRadius(5)
                }
                .frame(height: 110)
                .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 6)) { _ in AxisValueLabel(format: .dateTime.hour()) } }
                .chartYAxis(.hidden)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var todayPoints: [StepPoint] {
        let calendar = Calendar.current
        return model.readings.filter { $0.metric == .steps && calendar.isDateInToday($0.end) }
            .map { StepPoint(date: $0.end, value: $0.value) }.sorted { $0.date < $1.date }
    }

    private var sleepPage: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sleepSummary
                    sectionHeader("Sleep history", detail: "Sleep sessions from your watch")
                    let sleepReadings = model.readings.filter { $0.metric == .sleep }.sorted { $0.end > $1.end }
                    if sleepReadings.isEmpty {
                        emptyCard(icon: "bed.double", title: "Sleep sync isn’t available yet", message: "The current watch app sends steps only. Sleep sessions need a watch-side sleep data source before they can appear here.")
                    } else {
                        ForEach(sleepReadings.prefix(14)) { reading in
                            sampleRow(reading, symbol: "bed.double.fill", tint: Color(red: 0.40, green: 0.35, blue: 0.91))
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var sleepSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "moon.zzz.fill").font(.title2).foregroundStyle(.indigo)
                Text("TIME ASLEEP").font(.caption.weight(.bold)).tracking(0.7).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "moon.stars.fill").foregroundStyle(.indigo.opacity(0.6))
            }
            if let sleep = model.latestSleep {
                Text(duration(sleep.value)).font(.system(size: 38, weight: .bold, design: .rounded))
                Text(sleep.start.formatted(date: .abbreviated, time: .shortened) + " – " + sleep.end.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("—").font(.system(size: 38, weight: .bold, design: .rounded))
                Text("No sleep session received").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color.indigo.opacity(0.12), Color.purple.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var settingsPage: some View {
        NavigationStack {
            Form {
                Section("Watch connection") {
                    Label(model.receiverRunning ? "Receiver is on" : "Receiver is off", systemImage: model.receiverRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    Button(model.receiverRunning ? "Stop receiver" : "Start watch receiver") {
                        model.receiverRunning ? model.stopReceiver() : model.startReceiver()
                    }
                }
                Section("Apple Health") {
                    Label(model.healthReady ? "Health access requested" : "Health access not set up", systemImage: "heart.fill")
                    Button(model.healthReady ? "Health setup complete" : "Set up Apple Health") {
                        Task { await model.enableHealthSync() }
                    }
                    .disabled(model.healthReady)
                    Text("AeroLink stores received step data on this iPhone even if Apple Health access is unavailable.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Status") { Text(model.status).font(.footnote).foregroundStyle(.secondary) }
                Section { Text("Your activity data stays on your devices. AeroLink does not use a cloud account.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("AeroLink")
        }
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.bold())
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func emptyCard(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 27)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(22)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func sampleRow(_ reading: HealthReading, symbol: String, tint: Color) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 40, height: 40).background(tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(reading.metric == .steps ? "Steps" : "Sleep session").font(.headline)
                Text(reading.start.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(reading.metric == .steps ? "\(Int(reading.value).formatted())" : duration(reading.value))
                .font(.headline.monospacedDigit())
        }
        .padding(13).background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func duration(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        return "\(total / 60) hr \(total % 60) min"
    }
}
