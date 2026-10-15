import Foundation
import SwiftData

/// **Legacy.** Basketball's original event vocabulary, read only by
/// `LegacyBasketballMigration`. Raw values are persisted — never change them.
nonisolated enum GameEventType: String, CaseIterable {
    case substitutionIn  = "Sub In"
    case substitutionOut = "Sub Out"
    case foul            = "Foul"
    case teamScore       = "Team Score"
    case opponentScore   = "Opp Score"
    case periodAdvance   = "Period"
    case gameEnd         = "Game End"
    case note            = "Note"
    case mvpVote         = "MVP Vote"
}

/// **Legacy, read-only.** See `Game`. Do not change stored properties.
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
