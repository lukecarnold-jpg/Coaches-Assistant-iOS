import Foundation
import SwiftData

enum GameEventType: String, CaseIterable {
    case substitutionIn  = "Sub In"
    case substitutionOut = "Sub Out"
    case foul            = "Foul"
    case teamScore       = "Team Score"
    case opponentScore   = "Opp Score"
    case periodAdvance   = "Period"
    case gameEnd         = "Game End"
    case note            = "Note"
    case mvpVote         = "MVP Vote"

    var systemImage: String {
        switch self {
        case .substitutionIn:  return "arrow.down.circle"
        case .substitutionOut: return "arrow.up.circle"
        case .foul:            return "hand.raised"
        case .teamScore:       return "basketball"
        case .opponentScore:   return "basketball.fill"
        case .periodAdvance:   return "forward.end"
        case .gameEnd:         return "flag.checkered"
        case .note:            return "note.text"
        case .mvpVote:         return "star"
        }
    }
}

@Model
final class GameEvent {
    var eventID: UUID
    // Stored as raw String value — SwiftData doesn't reliably persist custom Codable enums
    var eventType: String
    var timestamp: Date
    var playerID: UUID?
    var playerName: String
    var detail: String
    var periodNumber: Int
    var elapsedSeconds: Int
    // Signed score change this event applied to teamScore/opponentScore (0 for non-scoring events).
    // Stored explicitly rather than re-parsed from `detail` so reverting a deletion is exact.
    var scoreDelta: Int = 0
    var game: Game?

    // Computed, never persisted
    var eventKind: GameEventType {
        GameEventType(rawValue: eventType) ?? .note
    }

    func displayName(opponentName: String) -> String {
        guard eventKind == .opponentScore, !opponentName.isEmpty else {
            return eventType
        }
        return "\(opponentName) Score"
    }

    init(game: Game?, eventType: GameEventType, playerID: UUID? = nil, playerName: String = "", detail: String = "", periodNumber: Int = 1, elapsedSeconds: Int = 0, scoreDelta: Int = 0) {
        self.eventID = UUID()
        self.eventType = eventType.rawValue
        self.timestamp = Date()
        self.playerID = playerID
        self.playerName = playerName
        self.detail = detail
        self.periodNumber = periodNumber
        self.elapsedSeconds = elapsedSeconds
        self.scoreDelta = scoreDelta
        self.game = game
    }
}
