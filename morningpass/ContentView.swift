import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\AlarmItem.createdAt, order: .reverse)]) private var alarms: [AlarmItem]

    @StateObject private var manager = MorningAlarmManager()
    @State private var selectedTab = 0
    @State private var showAddSheet = false
    @State private var editingAlarm: AlarmItem?

    private var runningAlarms: [AlarmItem] {
        alarms.filter(\.isEnabled).sorted(by: sortForDisplay)
    }

    private var recentAlarms: [AlarmItem] {
        alarms.filter { !$0.isEnabled }.sorted(by: sortForDisplay)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                alarmList
            }
            .tabItem { Label("Alarms", systemImage: "alarm.fill") }
            .tag(0)
        }
        .tabBarMinimizeBehavior(.never)
        .background(.yellow.opacity(0.1))
        .task {
            await syncEnabledAlarmsOnLaunch()
        }
        .alert("Oops!", isPresented: Binding(
            get: { manager.error != nil },
            set: { _ in manager.error = nil }
        )) {
            Button("OK", role: .cancel) { manager.error = nil }
        } message: {
            Text(manager.error ?? "Unknown error")
        }
        .sheet(isPresented: $showAddSheet) {
            AlarmEditSheet(alarm: nil) { date, repeatDays, title, icon in
                addAlarm(date: date, repeatDays: repeatDays, title: title, icon: icon)
            }
        }
        .sheet(item: $editingAlarm) { alarm in
            AlarmEditSheet(alarm: alarm) { date, repeatDays, title, icon in
                editAlarm(alarm, date: date, repeatDays: repeatDays, title: title, icon: icon)
            } onDelete: {
                deleteAlarm(alarm)
            }
        }
        .fullScreenCover(item: $manager.ringingSession) { session in
            RingingChallengeView(session: session) { input, solvingSession in
                let solved = await manager.solveAndStop(input, session: solvingSession)
                if solved {
                    markOneShotAsRecentIfNeeded(alarmID: solvingSession.alarmID)
                }
                return solved
            }
        }
    }

    private var alarmList: some View {
        List {
            Section {
                ForEach(runningAlarms) { alarm in
                    Button {
                        editingAlarm = alarm
                    } label: {
                        AlarmCellView(alarm: alarm, enabled: true) {
                            toggleAlarm(alarm)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    let ids = indexSet.map { runningAlarms[$0].id }
                    for id in ids {
                        if let alarm = alarms.first(where: { $0.id == id }) {
                            deleteAlarm(alarm)
                        }
                    }
                }
            }

            Section(recentAlarms.isEmpty ? "" : "Recent") {
                ForEach(recentAlarms) { alarm in
                    Button {
                        editingAlarm = alarm
                    } label: {
                        AlarmCellView(alarm: alarm, enabled: false) {
                            toggleAlarm(alarm)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    let ids = indexSet.map { recentAlarms[$0].id }
                    for id in ids {
                        if let alarm = alarms.first(where: { $0.id == id }) {
                            deleteAlarm(alarm)
                        }
                    }
                }
            }
        }
        .navigationTitle("Alarms")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton().foregroundStyle(Color.alarmTint)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.alarmTint)
                }
            }
        }
        .overlay {
            if runningAlarms.isEmpty && recentAlarms.isEmpty {
                ContentUnavailableView("No Alarms", systemImage: "alarm.fill")
            }
        }
    }

    private func addAlarm(date: Date, repeatDays: Set<Locale.Weekday>, title: String, icon: AlarmIcon) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let alarm = AlarmItem(
            hour: comps.hour ?? 7,
            minute: comps.minute ?? 0,
            label: title.isEmpty ? "Alarm" : title,
            icon: icon,
            repeatDays: repeatDays,
            isEnabled: true
        )

        modelContext.insert(alarm)
        saveContext()

        Task {
            await manager.sync(alarm)
        }
    }

    private func editAlarm(_ alarm: AlarmItem, date: Date, repeatDays: Set<Locale.Weekday>, title: String, icon: AlarmIcon) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        alarm.hour = comps.hour ?? alarm.hour
        alarm.minute = comps.minute ?? alarm.minute
        alarm.label = title.isEmpty ? "Alarm" : title
        alarm.icon = icon
        alarm.repeatDays = repeatDays

        saveContext()

        Task {
            await manager.sync(alarm)
        }
    }

    private func toggleAlarm(_ alarm: AlarmItem) {
        alarm.isEnabled.toggle()
        saveContext()

        Task {
            await manager.sync(alarm)
        }
    }

    private func deleteAlarm(_ alarm: AlarmItem) {
        alarm.isEnabled = false
        Task {
            await manager.sync(alarm)
        }
        modelContext.delete(alarm)
        saveContext()
    }

    private func markOneShotAsRecentIfNeeded(alarmID: UUID) {
        guard let alarm = alarms.first(where: { $0.id == alarmID }) else { return }
        if alarm.isOneShot {
            alarm.isEnabled = false
            saveContext()
        }
    }

    private func syncEnabledAlarmsOnLaunch() async {
        for alarm in alarms where alarm.isEnabled {
            await manager.sync(alarm)
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            manager.error = "Database save failed: \(error.localizedDescription)"
        }
    }

    private func sortForDisplay(_ lhs: AlarmItem, _ rhs: AlarmItem) -> Bool {
        if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
        if lhs.minute != rhs.minute { return lhs.minute < rhs.minute }
        return lhs.createdAt > rhs.createdAt
    }
}

#Preview {
    ContentView()
        .modelContainer(for: AlarmItem.self, inMemory: true)
}
