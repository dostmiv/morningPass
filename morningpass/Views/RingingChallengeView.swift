import SwiftUI

struct RingingChallengeView: View {
    let session: RingingSession
    let onSubmit: (String, RingingSession) async -> Bool

    @State private var answer = ""
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Text("Alarm is ringing")
                .font(.largeTitle.weight(.bold))

            Text("Solve this to stop")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(session.challenge.prompt)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .padding(.top, 10)

            TextField("Enter answer", text: $answer)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .font(.title3)
                .frame(maxWidth: 220)

            Button("Stop Alarm") {
                Task {
                    let solved = await onSubmit(answer, session)
                    if solved {
                        errorText = nil
                    } else {
                        errorText = "Wrong answer. Keep trying."
                        answer = ""
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let errorText {
                Text(errorText).foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(24)
        .interactiveDismissDisabled(true)
    }
}
