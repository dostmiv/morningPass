import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

enum AlarmIcon: String, CaseIterable, Codable {
    case sun = "sun.max.fill"
    case moonStar = "moon.stars.fill"
    case sparkles = "sparkles"
    case rainbow = "rainbow"
    case drop = "drop.degreesign.fill"
    case flame = "flame"

    var title: String {
        switch self {
        case .sun: return "Sun"
        case .moonStar: return "Moon"
        case .sparkles: return "Sparkles"
        case .rainbow: return "Rainbow"
        case .drop: return "Drop"
        case .flame: return "Flame"
        }
    }
}

struct MathChallenge: Sendable {
    enum Operation: String, Sendable {
        case add = "+"
        case subtract = "-"
    }

    let left: Int
    let right: Int
    let operation: Operation

    var prompt: String { "\(left) \(operation.rawValue) \(right) = ?" }

    var answer: Int {
        switch operation {
        case .add: return left + right
        case .subtract: return left - right
        }
    }

    static func generate() -> MathChallenge {
        if Bool.random() {
            return MathChallenge(left: Int.random(in: 3...30), right: Int.random(in: 2...20), operation: .add)
        }
        let left = Int.random(in: 10...40)
        return MathChallenge(left: left, right: Int.random(in: 1...left), operation: .subtract)
    }
}

struct RingingSession: Identifiable, Sendable {
    let id = UUID()
    let alarmID: UUID
    let challenge: MathChallenge
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct MorningAlarmMetadata: AlarmMetadata {
    var iconRaw: String
    var title: String
    var createdAt: Date = .now
}
#endif
