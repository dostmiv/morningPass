import SwiftUI

struct MetadataEntryView: View {
    @Binding var title: String
    @Binding var icon: AlarmIcon

    var body: some View {
        HStack(spacing: 8) {
            Text("Label")
            TextField("Title", text: $title)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.gray)
        }

        HStack(spacing: 8) {
            Text("Icon")
            Picker("Icon", selection: $icon) {
                ForEach(AlarmIcon.allCases, id: \.self) { item in
                    Label(item.title, systemImage: item.rawValue).tag(item)
                }
            }
        }
    }
}
