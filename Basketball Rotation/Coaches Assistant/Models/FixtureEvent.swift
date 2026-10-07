import Foundation
import SwiftData

nonisolated enum FixtureEventType: String, CaseIterable {
    case substitutionIn  = "Sub In"
    case substitutionOut = "Sub Out"
    case discipline       = "Discipline"
    case teamScore       = "Team Score"
    case opponentScore   = "Opp Score"
    case periodAdvance   = "Period"
    case fixtureEnd      = "Fixture End"
    case note            = "Note"
    case mvpVote         = "MVP Vote"

    /// Sport-agnostic fallback icon. Per-sport discipline/scoring icons resolve
    /// through `FixtureEvent.symbolName(for:)` first.
    var systemImage: String {
        switch self {
        case .substitutionIn:  return "arrow.down.circle"
        case .substitutionOut: return "arrow.up.circle"
        case .discipline:      return "flag"
        case .teamScore:       return "plus.circle"
        case .opponentScore:   return "minus.circle"
        case .periodAdvance:   return "forward.end"
        case .fixtureEnd:      return "flag.checkered"
        case .note:            return "note.text"
        case .mvpVote:         return "star"
        }
    }
}

@Model
final class FixtureEvent {
    var eventID: UUID
    var eventType: String
    /// Stable key for the specific scoring/discipline action (e.g. "sinBin", "behind").
    /// Kept separate from `detail`, which the user can freely edit in event history —
    /// matching, so icon/removal lookups never break if a coach fixes a typo.
    var actionCode: String
    var timestamp: Date
    var playerID: UUID?
    var playerName: String
    var detail: String
    var periodNumber: Int
    var elapsedSeconds: Int
    var scoreDelta: Int = 0
    var fixture: Fixture?

    var eventKind: FixtureEventType {
        FixtureEventType(rawValue: eventType) ?? .note
    }

    func symbolName(for sport: Sport) -> String {
        sport.rules.disciplineAction(forCode: actionCode)?.systemImage ?? eventKind.systemImage
    }

    /// Row title: the specific discipline action ("Foul", "Yellow Card") rather
    /// than the generic "Discipline", and "<Opponent> Score" for opponent scores.
    func displayName(opponentName: String, sport: Sport) -> String {
        if eventKind == .discipline, let action = sport.rules.disciplineAction(forCode: actionCode) {
            return action.label
        }
        if eventKind == .fixtureEnd {
            return "\(sport.rules.matchTerm) End"
        }
        guard eventKind == .opponentScore, !opponentName.isEmpty else {
            return eventType
        }
        return "\(opponentName) Score"
    }

    init(fixture: Fixture?, eventType: FixtureEventType, actionCode: String = "", playerID: UUID? = nil, playerName: String = "", detail: String = "", periodNumber: Int = 1, elapsedSeconds: Int = 0, scoreDelta: Int = 0) {
        self.eventID = UUID()
        self.eventType = eventType.rawValue
        self.actionCode = actionCode
        self.timestamp = Date()
        self.playerID = playerID
        self.playerName = playerName
        self.detail = detail
        self.periodNumber = periodNumber
        self.elapsedSeconds = elapsedSeconds
        self.scoreDelta = scoreDelta
        self.fixture = fixture
    }
}
