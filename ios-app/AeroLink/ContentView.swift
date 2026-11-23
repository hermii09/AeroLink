import Charts
import SwiftUI

private let AeroCyan = Color(red: 0.04, green: 0.65, blue: 0.78)
private let AeroBlue = Color(red: 0.10, green: 0.50, blue: 0.82)

struct ContentView: View {
    @ObservedObject var model: CompanionModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            activityPage
                .tabItem { Label("Activity", systemImage: "flame.fill") }
            sleepPage
                .tabItem { Label("Sleep", systemImage: "bed.double.fill") }
            settingsPage
                .tabItem { Label("Health", systemImage: "heart.fill") }
        }
        .tint(AeroCyan)
        .task {
            if model.healthReady { await model.refreshHealthData() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && model.healthReady {
                Task { await model.refreshHealthData() }
            }
        }
    }

    private var activityPage: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summaryCard
                    chartCard
                    sectionHeader("Recent activity", detail: model.stepHistorySource)
                    let stepDays = model.recentStepDays
                    if stepDays.isEmpty {
                        emptyCard(icon: "figure.walk", title: "No step data yet", message: "Set up Apple Health to load your step history, or start the receiver to get new steps from your watch.")
                    } else {
                        ForEach(stepDays.prefix(14)) { day in
                            stepRow(day)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await model.refreshHealthData() }
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().stroke(AeroCyan.opacity(0.14), lineWidth: 12)
                Circle().trim(from: 0, to: min(Double(model.todaySteps) / 10_000, 1))
                    .stroke(AngularGradient(colors: [AeroCyan, AeroBlue], center: .center), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "figure.walk").font(.system(size: 25, weight: .semibold)).foregroundStyle(AeroCyan)
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
                        .foregroundStyle(LinearGradient(colors: [AeroCyan, AeroBlue], startPoint: .bottom, endPoint: .top))
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
        let watchPoints = model.readings.filter { $0.metric == .steps && calendar.isDateInToday($0.end) }
            .map { StepPoint(date: $0.end, value: $0.value) }.sorted { $0.date < $1.date }
        if !watchPoints.isEmpty { return watchPoints }
        if let healthDay = model.recentStepDays.first(where: { calendar.isDateInToday($0.date) }) {
            return [StepPoint(date: .now, value: healthDay.steps)]
        }
        return []
    }

    private var sleepPage: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sleepSummary
                    sectionHeader("Sleep history", detail: model.sleepHistorySource)
                    let sleepSessions = model.recentSleepSessions
                    if sleepSessions.isEmpty {
                        emptyCard(icon: "bed.double", title: "No sleep data yet", message: "Set up Apple Health to load sleep records. The current watch APK does not send sleep sessions yet.")
                    } else {
                        ForEach(sleepSessions.prefix(14)) { session in
                            sleepRow(session)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await model.refreshHealthData() }
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
                Text(duration(sleep.asleepMinutes)).font(.system(size: 38, weight: .bold, design: .rounded))
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
                    Label(model.healthReady ? "Health access set up" : "Health access not set up", systemImage: "heart.fill")
                    if model.healthReady {
                        Button("Refresh Health Data") { Task { await model.refreshHealthData() } }
                    } else {
                        Button("Set up Apple Health") { Task { await model.enableHealthSync() } }
                    }
                    Text("AeroLink reads steps and sleep from Apple Health when you allow access. It can also save readings received from your Galaxy Watch.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("If the report is empty, check Settings → Health → Data Access & Devices → AeroLink Health. iOS doesn’t tell apps whether read access was denied.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Status") { Text(model.status).font(.footnote).foregroundStyle(.secondary) }
                Section { Text("Your activity data stays on your devices. AeroLink does not use a cloud account.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("AeroLink Health")
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

    private func stepRow(_ day: HealthDaySummary) -> some View {
        HStack(spacing: 13) {
            Image(systemName: "figure.walk").font(.system(size: 17, weight: .semibold)).foregroundStyle(AeroCyan)
                .frame(width: 40, height: 40).background(AeroCyan.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(Calendar.current.isDateInToday(day.date) ? "Today" : day.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                Text("Daily step total").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Int(day.steps.rounded()).formatted()).font(.headline.monospacedDigit())
        }
        .padding(13).background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sleepRow(_ session: SleepSessionSummary) -> some View {
        HStack(spacing: 13) {
            Image(systemName: "bed.double.fill").font(.system(size: 17, weight: .semibold)).foregroundStyle(.indigo)
                .frame(width: 40, height: 40).background(Color.indigo.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(session.end.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                Text(session.start.formatted(date: .omitted, time: .shortened) + " – " + session.end.formatted(date: .omitted, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(duration(session.asleepMinutes)).font(.headline.monospacedDigit())
        }
        .padding(13).background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func duration(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        return "\(total / 60) hr \(total % 60) min"
    }
}
