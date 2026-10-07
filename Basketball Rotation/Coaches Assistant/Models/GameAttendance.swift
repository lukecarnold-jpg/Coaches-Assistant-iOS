import Foundation
import SwiftData

/// **Legacy, read-only.** See `Game`. Do not change stored properties.
@Model
final class GameAttendance {
    var attendanceID: UUID
    var playerID: UUID
    var playerName: String
    var isAbsent: Bool
    var game: Game?

    init(game: Game?, playerID: UUID, playerName: String) {
        self.attendanceID = UUID()
        self.playerID = playerID
        self.playerName = playerName
        self.isAbsent = false
        self.game = game
    }
}
