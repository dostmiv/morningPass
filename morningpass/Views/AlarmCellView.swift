import SwiftUI

struct AlarmCellView: View {
    let alarm: AlarmItem
    let enabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeString)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .font(.system(size: 40, design: .rounded))

                HStack(spacing: 0) {
                    Text("\(Image(systemName: alarm.icon.rawValue)) \(alarm.label)")
                        .padding(.leading, 8)

                    if !alarm.repeatDays.isEmpty {
                        Text(", \(alarm.repeatDays.stringRepresentation)")
                    }
                }
                .font(.system(size: 16))
            }
            .foregroundStyle(enabled ? Color.primary : .gray)
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: .constant(enabled))
                .labelsHidden()
                .onTapGesture(perform: onToggle)
        }
    }
}
