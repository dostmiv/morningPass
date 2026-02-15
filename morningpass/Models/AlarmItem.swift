import SwiftUI
import SwiftData

@Model
final class AlarmItem {
    @Attribute(.unique) var id: UUID
    var hour: Int
    var minute: Int
    var label: String
    var iconRaw: String
    var repeatDaysRaw: String
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        label: String,
        icon: AlarmIcon = .sun,
        repeatDays: Set<Locale.Weekday> = [],
        isEnabled: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.label = label
        self.iconRaw = icon.rawValue
        self.repeatDaysRaw = Self.encodeWeekdays(repeatDays)
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    var icon: AlarmIcon {
        get { AlarmIcon(rawValue: iconRaw) ?? .sun }
        set { iconRaw = newValue.rawValue }
    }

    var repeatDays: Set<Locale.Weekday> {
        get { Self.decodeWeekdays(repeatDaysRaw) }
        set { repeatDaysRaw = Self.encodeWeekdays(newValue) }
    }

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var displayDate: Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return Calendar.current.date(from: comps) ?? .now
    }

    var isOneShot: Bool {
        repeatDays.isEmpty
    }

    static func encodeWeekdays(_ weekdays: Set<Locale.Weekday>) -> String {
        weekdays.map(\.rawValue).sorted().joined(separator: ",")
    }

    static func decodeWeekdays(_ raw: String) -> Set<Locale.Weekday> {
        guard !raw.isEmpty else { return [] }
        let values = raw.split(separator: ",").map(String.init)
        let weekdays = values.compactMap(Locale.Weekday.init(rawValue:))
        return Set(weekdays)
    }
}
