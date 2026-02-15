import SwiftUI

struct WeekdayPicker: View {
    @Binding var selectedWeekdays: Set<Locale.Weekday>
    @Environment(\.dismiss) private var dismiss

    private let weekdays = Locale.autoupdatingCurrent.orderedWeekdays

    var body: some View {
        Form {
            ForEach(weekdays, id: \.self) { day in
                Button {
                    if selectedWeekdays.contains(day) {
                        selectedWeekdays.remove(day)
                    } else {
                        selectedWeekdays.insert(day)
                    }
                } label: {
                    HStack {
                        Text("Every \(day.fullSymbol)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if selectedWeekdays.contains(day) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.alarmTint)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
        }
        .buttonStyle(.plain)
        .navigationTitle("Repeat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(Color.alarmTint)
                }
            }
        }
    }
}
