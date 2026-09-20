import Foundation
import SwiftData

/// A roster player for one of the non-Basketball sports. Kept as a separate model
/// (rather than adding a `sport` field to `Player`) so Basketball's roster and its
/// screens are never touched by this change.
@Model
final class SquadPlayer {
    var playerID: UUID
    var sport: String
    var name: String
    var jerseyNumber: Int?
    var preferredPositionCode: String
    var createdAt: Date

    init(sport: Sport, name: String, jerseyNumber: Int? = nil, preferredPositionCode: String = "") {
        self.playerID = UUID()
        self.sport = sport.rawValue
        self.name = name
        self.jerseyNumber = jerseyNumber
        self.preferredPositionCode = preferredPositionCode
        self.createdAt = Date()
    }

    var sportValue: Sport { Sport(rawValue: sport) ?? .basketball }

    var preferredPosition: Position? {
        sportValue.rules.position(forCode: preferredPositionCode)
    }

    var displayName: String {
        if let num = jerseyNumber {
            return "#\(num) \(name)"
        }
        return name
    }
}
