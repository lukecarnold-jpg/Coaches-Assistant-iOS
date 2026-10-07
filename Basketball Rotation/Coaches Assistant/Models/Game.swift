import Foundation
import SwiftData

/// **Legacy, read-only.** Basketball games from before Basketball moved onto the
/// shared `Fixture` model. Kept in the schema only so `LegacyBasketballMigration`
/// can read existing stores; nothing creates or edits these any more.
///
/// Do not add, remove, rename or retype stored properties — that would change the
/// schema and risk the store failing to open.
@Model
final class Game {
    var gameID: UUID
    var date: Date
    var opponentName: String
    var periodFormat: String  // PeriodFormat raw value
    var periodLengthMinutes: Int
    var currentPeriod: Int
    var teamScore: Int
    var opponentScore: Int
    var notes: String
    var isEnded: Bool
    // Declared with a default so SwiftData's lightweight migration can populate it
    // on stores created before this property existed.
    var isGameDayModeActive: Bool = false

    // Clock state
    var elapsedSeconds: Int
    var clockIsRunning: Bool
    var clockStartedAt: Date?

    // Stored as UUIDString arrays — SwiftData does not reliably persist [UUID]
    var startingLineupIDs: [String] = []
    var onCourtPlayerIDs: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \GameEvent.game)
    var events: [GameEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \GameAttendance.game)
    var attendances: [GameAttendance] = []

    /// Used by migration tests to build legacy records.
    init(opponentName: String, periodFormat: String, periodLengthMinutes: Int) {
        self.gameID = UUID()
        self.date = Date()
        self.opponentName = opponentName
        self.periodFormat = periodFormat
        self.periodLengthMinutes = periodLengthMinutes
        self.currentPeriod = 1
        self.teamScore = 0
        self.opponentScore = 0
        self.notes = ""
        self.isEnded = false
        self.isGameDayModeActive = true
        self.elapsedSeconds = 0
        self.clockIsRunning = false
        self.clockStartedAt = nil
    }
}
