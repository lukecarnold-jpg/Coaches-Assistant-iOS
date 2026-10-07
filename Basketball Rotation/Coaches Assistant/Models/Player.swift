import Foundation
import SwiftData

/// **Legacy, read-only.** Basketball players from before Basketball moved onto
/// `SquadPlayer`. Kept only so `LegacyBasketballMigration` can read existing
/// stores. Do not change stored properties.
@Model
final class Player {
    var playerID: UUID
    var name: String
    var jerseyNumber: Int?
    var createdAt: Date

    init(name: String, jerseyNumber: Int? = nil) {
        self.playerID = UUID()
        self.name = name
        self.jerseyNumber = jerseyNumber
        self.createdAt = Date()
    }
}
