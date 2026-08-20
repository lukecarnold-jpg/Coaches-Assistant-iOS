import Foundation
import SwiftData

@Model
final class Game {
    var gameID: UUID
    var date: Date
    var opponentName: String
    var periodFormat: String  // "quarters" or "halves"
    var periodLengthMinutes: Int
    var currentPeriod: Int
    var teamScore: Int
    var opponentScore: Int
    var notes: String
    var isEnded: Bool

    // Clock state
    var elapsedSeconds: Int       // persisted snapshot
    var clockIsRunning: Bool
    var clockStartedAt: Date?     // when the current running session began

    // Lineup state (stored as UUID arrays)
    var startingLineupIDs: [UUID]
    var onCourtPlayerIDs: [UUID]

    @Relationship(deleteRule: .cascade) var events: [GameEvent] = []
    @Relationship(deleteRule: .cascade) var attendances: [GameAttendance] = []

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
        self.elapsedSeconds = 0
        self.clockIsRunning = false
        self.clockStartedAt = nil
        self.startingLineupIDs = []
        self.onCourtPlayerIDs = []
    }

    var totalPeriods: Int {
        periodFormat == "quarters" ? 4 : 2
    }

    var periodLengthSeconds: Int {
        periodLengthMinutes * 60
    }

    var periodLabel: String {
        if periodFormat == "quarters" {
            switch currentPeriod {
            case 1: return "1st Quarter"
            case 2: return "2nd Quarter"
            case 3: return "3rd Quarter"
            case 4: return "4th Quarter"
            default: return "OT \(currentPeriod - 4)"
            }
        } else {
            switch currentPeriod {
            case 1: return "1st Half"
            case 2: return "2nd Half"
            default: return "OT \(currentPeriod - 2)"
            }
        }
    }

    /// Real-time elapsed seconds accounting for a running clock.
    func currentElapsedSeconds() -> Int {
        if clockIsRunning, let startedAt = clockStartedAt {
            return elapsedSeconds + Int(Date().timeIntervalSince(startedAt))
        }
        return elapsedSeconds
    }

    func remainingSeconds(at elapsed: Int) -> Int {
        max(0, periodLengthSeconds - elapsed)
    }
}
