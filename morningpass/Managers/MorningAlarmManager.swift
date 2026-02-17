import SwiftUI
import Combine
import UserNotifications
import AudioToolbox
#if canImport(AlarmKit)
import AlarmKit
import ActivityKit
#endif

@MainActor
final class MorningAlarmManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var error: String?
    @Published var ringingSession: RingingSession?

    private let notifications = UNUserNotificationCenter.current()
    private var ringTimer: Timer?

    #if canImport(AlarmKit)
    @available(iOS 26.0, *) private let alarmManager = AlarmManager.shared
    @available(iOS 26.0, *) private var updatesTask: Task<Void, Never>?
    @available(iOS 26.0, *) private var alarmKitAuthorized = false
    #endif

    override init() {
        super.init()
        notifications.delegate = self
        requestNotificationAuthorization()

        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            alarmKitAuthorized = (alarmManager.authorizationState == .authorized)
            observeAlarmUpdates()
            requestAlarmAuthorization()
        }
        #endif
    }

    deinit {
        ringTimer?.invalidate()
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            updatesTask?.cancel()
        }
        #endif
    }

    func sync(_ alarm: AlarmItem) async {
        if alarm.isEnabled {
            await schedule(alarm)
        } else {
            cancel(alarm)
        }
    }

    func solveAndStop(_ answerText: String, session: RingingSession) async -> Bool {
        guard Int(answerText.trimmingCharacters(in: .whitespacesAndNewlines)) == session.challenge.answer else {
            return false
        }

        stopAlarm(session.alarmID)
        ringingSession = nil
        return true
    }

    private func stopAlarm(_ alarmID: UUID) {
        stopAudibleRing()

        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), alarmKitAuthorized {
            // AlarmKit may already purge one-shot alarms by the time user solves math.
            // Ignore daemon errors and always allow local stop flow to complete.
            do {
                try alarmManager.stop(id: alarmID)
            } catch {
                do {
                    try alarmManager.cancel(id: alarmID)
                } catch {
                    // best effort only
                }
            }
        }
        #endif
    }

    private func schedule(_ alarm: AlarmItem) async {
        scheduleLocalNotification(for: alarm)

        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *), alarmKitAuthorized else { return }

        do {
            let time = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
            let recurrence: Alarm.Schedule.Relative.Recurrence = alarm.repeatDays.isEmpty
                ? .never
                : .weekly(Array(alarm.repeatDays))

            let schedule = Alarm.Schedule.relative(.init(time: time, repeats: recurrence))
            let title = alarm.label.isEmpty ? "Alarm" : alarm.label
            let presentation = AlarmPresentation(alert: .init(title: LocalizedStringResource(stringLiteral: title)))
            let attributes = AlarmAttributes<MorningAlarmMetadata>(
                presentation: presentation,
                metadata: MorningAlarmMetadata(iconRaw: alarm.icon.rawValue, title: title),
                tintColor: .alarmTint
            )

            let config = AlarmManager.AlarmConfiguration<MorningAlarmMetadata>.alarm(
                schedule: schedule,
                attributes: attributes,
                sound: .default
            )

            _ = try await alarmManager.schedule(id: alarm.id, configuration: config)
        } catch {
            // Keep local notification scheduling as the primary reliable path.
        }
        #endif
    }

    private func cancel(_ alarm: AlarmItem) {
        notifications.removePendingNotificationRequests(withIdentifiers: [notificationID(for: alarm.id)])
        let suffixIDs = alarm.repeatDays.map { notificationID(for: alarm.id, suffix: $0.rawValue) }
        notifications.removePendingNotificationRequests(withIdentifiers: suffixIDs)

        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *), alarmKitAuthorized else { return }
        do {
            try alarmManager.cancel(id: alarm.id)
        } catch {
            // best effort only
        }
        #endif
    }

    private func scheduleLocalNotification(for alarm: AlarmItem) {
        notifications.removePendingNotificationRequests(withIdentifiers: [notificationID(for: alarm.id)])
        let suffixIDs = alarm.repeatDays.map { notificationID(for: alarm.id, suffix: $0.rawValue) }
        notifications.removePendingNotificationRequests(withIdentifiers: suffixIDs)

        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "Alarm" : alarm.label
        content.body = "Solve the math question to stop the ringing."
        content.sound = .default

        if alarm.repeatDays.isEmpty {
            let next = nextOneShotDate(hour: alarm.hour, minute: alarm.minute, from: .now)
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: next)
            let request = UNNotificationRequest(
                identifier: notificationID(for: alarm.id),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            notifications.add(request)
            return
        }

        for day in alarm.repeatDays {
            var comps = DateComponents()
            comps.weekday = day.calendarWeekdayIndex
            comps.hour = alarm.hour
            comps.minute = alarm.minute

            let req = UNNotificationRequest(
                identifier: notificationID(for: alarm.id, suffix: day.rawValue),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            )
            notifications.add(req)
        }
    }

    private func notificationID(for id: UUID, suffix: String? = nil) -> String {
        if let suffix {
            return "alarm.\(id.uuidString).\(suffix)"
        }
        return "alarm.\(id.uuidString)"
    }

    private func alarmID(from notificationIdentifier: String) -> UUID? {
        let parts = notificationIdentifier.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        return UUID(uuidString: String(parts[1]))
    }

    private func requestNotificationAuthorization() {
        Task {
            do {
                _ = try await notifications.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                self.error = "Notification permission failed: \(error.localizedDescription)"
            }
        }
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func requestAlarmAuthorization() {
        Task {
            do {
                let state = try await alarmManager.requestAuthorization()
                alarmKitAuthorized = (state == .authorized)
            } catch {
                alarmKitAuthorized = false
            }
        }
    }

    @available(iOS 26.0, *)
    private func observeAlarmUpdates() {
        updatesTask = Task {
            for await alarms in alarmManager.alarmUpdates {
                if let alerting = alarms.first(where: { $0.state == .alerting }) {
                    triggerRinging(alarmID: alerting.id)
                }
            }
        }
    }
    #endif

    private func triggerRinging(alarmID: UUID) {
        if ringingSession?.alarmID != alarmID {
            ringingSession = RingingSession(alarmID: alarmID, challenge: .generate())
        }
        startAudibleRing()
    }

    private func startAudibleRing() {
        ringTimer?.invalidate()
        AudioServicesPlaySystemSound(1005)

        ringTimer = Timer.scheduledTimer(withTimeInterval: 1.25, repeats: true) { _ in
            AudioServicesPlaySystemSound(1005)
        }
    }

    private func stopAudibleRing() {
        ringTimer?.invalidate()
        ringTimer = nil
    }

    private func nextOneShotDate(hour: Int, minute: Int, from now: Date) -> Date {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0

        let todayTime = calendar.date(from: comps) ?? now
        if todayTime > now { return todayTime }

        return calendar.date(byAdding: .day, value: 1, to: todayTime) ?? now.addingTimeInterval(24 * 60 * 60)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        if let id = alarmID(from: notification.request.identifier) {
            triggerRinging(alarmID: id)
        }
        return [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let id = alarmID(from: response.notification.request.identifier) {
            triggerRinging(alarmID: id)
        }
    }
}
