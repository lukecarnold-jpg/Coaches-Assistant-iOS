import Foundation
import SwiftData

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

    /// Players required on court, from Basketball's sport rules.
    static var requiredOnCourtCount: Int { Sport.basketball.rules.onFieldCount }

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

    // MARK: - Event logging

    /// Creates, inserts and attaches an event stamped with the current period/clock.
    @discardableResult
    func logEvent(_ type: GameEventType, player: Player? = nil, detail: String = "", scoreDelta: Int = 0, in context: ModelContext) -> GameEvent {
        let event = GameEvent(
            game: self,
            eventType: type,
            playerID: player?.playerID,
            playerName: player?.name ?? "",
            detail: detail,
            periodNumber: currentPeriod,
            elapsedSeconds: currentElapsedSeconds(),
            scoreDelta: scoreDelta
        )
        context.insert(event)
        events.append(event)
        return event
    }

    /// Adds points for our team, optionally crediting a scorer.
    func logTeamScore(points: Int, player: Player?, in context: ModelContext) {
        let applied = applyScore(team: true, delta: points)
        guard applied != 0 else { return }
        logEvent(.teamScore, player: player, detail: "+\(applied)", scoreDelta: applied, in: context)
    }

    /// Manual score correction (e.g. the scoreboard "−" button). Logs nothing if the
    /// score was already 0.
    func adjustScore(team: Bool, delta: Int, in context: ModelContext) {
        let applied = applyScore(team: team, delta: delta)
        guard applied != 0 else { return }
        let detail = applied > 0 ? "+\(applied)" : "\(applied)"
        logEvent(team ? .teamScore : .opponentScore, detail: detail, scoreDelta: applied, in: context)
    }

    func resetClock(in context: ModelContext) {
        let previous = currentElapsedSeconds()
        resetClock()
        logEvent(.note, detail: "Clock reset (was \(formatClock(remainingSeconds(at: previous))) remaining)", in: context)
    }

    func advancePeriod(in context: ModelContext) {
        stopClock()
        logEvent(.periodAdvance, detail: "End of \(periodLabel)", in: context)
        moveToNextPeriod()
    }

    func endGame(in context: ModelContext) {
        stopClock()
        logEvent(.gameEnd, detail: "Final: \(teamScore) – \(opponentScore)", in: context)
        markEnded()
    }
}

extension Game: TimedMatch {
    var playingTimeEvents: [PlayingTimeEvent] {
        events.map { event in
            let kind: PlayingTimeEvent.Kind
            switch event.eventKind {
            case .substitutionIn: kind = .subIn
            case .substitutionOut: kind = .subOut
            case .gameEnd: kind = .matchEnd
            default: kind = .other
            }
            return PlayingTimeEvent(kind: kind, playerID: event.playerID, periodNumber: event.periodNumber, elapsedSeconds: event.elapsedSeconds, timestamp: event.timestamp)
        }
    }
}
