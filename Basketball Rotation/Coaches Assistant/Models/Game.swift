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
    // Declared with a default so SwiftData's lightweight migration can populate it
    // on stores created before this property existed. Existing games migrate as
    // `false`; new games opt in via `init`.
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

    func currentElapsedSeconds() -> Int {
        if clockIsRunning, let startedAt = clockStartedAt {
            return elapsedSeconds + Int(Date().timeIntervalSince(startedAt))
        }
        return elapsedSeconds
    }

    func remainingSeconds(at elapsed: Int) -> Int {
        max(0, periodLengthSeconds - elapsed)
    }

    // MARK: - Lineup helpers

    func isOnCourt(_ player: Player) -> Bool {
        onCourtPlayerIDs.contains(player.playerID.uuidString)
    }

    func addToOnCourt(_ player: Player) {
        guard !isOnCourt(player) else { return }
        onCourtPlayerIDs.append(player.playerID.uuidString)
    }

    func removeFromOnCourt(_ player: Player) {
        onCourtPlayerIDs.removeAll { $0 == player.playerID.uuidString }
    }

    // MARK: - Playing time

    /// Total seconds each player has spent on court, reconstructed from the substitution
    /// event log rather than tracked live — so it stays correct even if events are edited
    /// or deleted after the fact.
    ///
    /// Cumulative "game seconds" (as opposed to per-period `elapsedSeconds`) are derived
    /// from `periodNumber`/`elapsedSeconds` on each event, assuming a fixed period length.
    func minutesPlayedSeconds() -> [UUID: Int] {
        var totals: [UUID: Int] = [:]
        var intervalStart: [UUID: Int] = [:]

        func gameSeconds(period: Int, elapsed: Int) -> Int {
            max(0, period - 1) * periodLengthSeconds + elapsed
        }

        for idString in startingLineupIDs {
            if let id = UUID(uuidString: idString) {
                intervalStart[id] = 0
            }
        }

        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            let g = gameSeconds(period: event.periodNumber, elapsed: event.elapsedSeconds)
            switch event.eventKind {
            case .substitutionIn:
                guard let playerID = event.playerID else { continue }
                intervalStart[playerID] = g
            case .substitutionOut:
                guard let playerID = event.playerID, let start = intervalStart.removeValue(forKey: playerID) else { continue }
                totals[playerID, default: 0] += max(0, g - start)
            case .gameEnd:
                for (playerID, start) in intervalStart {
                    totals[playerID, default: 0] += max(0, g - start)
                }
                intervalStart.removeAll()
            default:
                break
            }
        }

        if !isEnded {
            let liveGameSeconds = gameSeconds(period: currentPeriod, elapsed: currentElapsedSeconds())
            for (playerID, start) in intervalStart {
                totals[playerID, default: 0] += max(0, liveGameSeconds - start)
            }
        }

        return totals
    }
}
