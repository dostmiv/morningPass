import SwiftUI

struct AlarmEditSheet: View {
    let alarm: AlarmItem?
    let onSave: (Date, Set<Locale.Weekday>, String, AlarmIcon) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var selectedWeekdays: Set<Locale.Weekday>
    @State private var title: String
    @State private var icon: AlarmIcon

    init(alarm: AlarmItem?, onSave: @escaping (Date, Set<Locale.Weekday>, String, AlarmIcon) -> Void, onDelete: (() -> Void)? = nil) {
        self.alarm = alarm
        self.onSave = onSave
        self.onDelete = onDelete

        _date = State(initialValue: alarm?.displayDate ?? .now)
        _selectedWeekdays = State(initialValue: alarm?.repeatDays ?? [])
        _title = State(initialValue: alarm?.label ?? "Alarm")
        _icon = State(initialValue: alarm?.icon ?? .sun)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    RelativeSchedulePicker(date: $date)
                        .datePickerStyle(.wheel)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.all, 0)

                Section {
                    NavigationLink {
                        WeekdayPicker(selectedWeekdays: $selectedWeekdays)
                    } label: {
                        HStack {
                            Text("Repeat")
                            Spacer()
                            Text(selectedWeekdays.stringRepresentation)
                                .foregroundStyle(.gray)
                        }
                    }

                    MetadataEntryView(title: $title, icon: $icon)
                }

                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Text("Delete Alarm")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(alarm == nil ? "Add Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.alarmTint)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(date, selectedWeekdays, title, icon)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.alarmTint)
                }
            }
        }
    }
}
