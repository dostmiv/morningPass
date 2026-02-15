import SwiftUI

extension Color {
    static var alarmTint: Color { .orange }
}

extension Locale {
    var orderedWeekdays: [Locale.Weekday] {
        let all: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        if let idx = all.firstIndex(of: firstDayOfWeek), idx != 0 {
            return Array(all[idx...] + all[..<idx])
        }
        return all
    }
}

extension Locale.Weekday {
    var fullSymbol: String {
        let symbols = Calendar.autoupdatingCurrent.weekdaySymbols
        return symbols.first(where: { $0.localizedCaseInsensitiveContains(rawValue) }) ?? rawValue.localizedCapitalized
    }

    var calendarWeekdayIndex: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        @unknown default: return 1
        }
    }
}

extension Set where Element == Locale.Weekday {
    var stringRepresentation: String {
        if isEmpty { return "Never" }
        if count == 7 { return "Every day" }
        if count == 1, let one = first { return "Every \(one.fullSymbol)" }
        if self == Set([.sunday, .saturday]) { return "Weekends" }
        if self == Set([.monday, .tuesday, .wednesday, .thursday, .friday]) { return "Weekdays" }
        return map { $0.rawValue.localizedCapitalized }.sorted().joined(separator: ", ")
    }
}
