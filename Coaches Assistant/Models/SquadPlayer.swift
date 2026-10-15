import Foundation
import SwiftData

/// A roster player for any sport. Basketball's original `Player` records are
/// copied into this model by `LegacyBasketballMigration`.
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
