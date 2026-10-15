import Foundation
import SwiftData

/// A match for any timed sport, Basketball included. Clock, period, scoring and
/// playing-time logic comes from `TimedMatch`, with `sport`-driven rules layered
/// on top. Basketball's original `Game` records are copied into this model by
/// `LegacyBasketballMigration`.
@Model
final class Fixture {
    var fixtureID: UUID
    var sport: String
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
    // on stores created before this property existed. Existing fixtures migrate as
    // `false`; new fixtures opt in via `init`.
    var isGameDayModeActive: Bool = false

    // Clock state
    var elapsedSeconds: Int
    var clockIsRunning: Bool
    var clockStartedAt: Date?

    // Stored as UUIDString arrays — SwiftData does not reliably persist [UUID]
    var startingLineupIDs: [String] = []
    var onFieldPlayerIDs: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \FixtureEvent.fixture)
    var events: [FixtureEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \FixtureAttendance.fixture)
    var attendances: [FixtureAttendance] = []

    @Relationship(deleteRule: .cascade, inverse: \FixtureLineupSlot.fixture)
    var lineupSlots: [FixtureLineupSlot] = []

    init(sport: Sport, opponentName: String, periodFormat: String, periodLengthMinutes: Int) {
        self.fixtureID = UUID()
        self.sport = sport.rawValue
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

    /// Falls back to soccer if the stored value is unrecognised (e.g. data from a
    /// newer app version) — and flags it loudly in debug builds.
    var sportValue: Sport {
        if let value = Sport(rawValue: sport) { return value }
        assertionFailure("Fixture has unknown sport '\(sport)'")
        return .soccer
    }
    var rules: SportRules { sportValue.rules }

    // MARK: - Lineup helpers

    func isOnField(_ player: SquadPlayer) -> Bool {
        onFieldPlayerIDs.contains(player.playerID.uuidString)
    }

    func addToOnField(_ player: SquadPlayer) {
        guard !isOnField(player) else { return }
        onFieldPlayerIDs.append(player.playerID.uuidString)
    }

    func removeFromOnField(_ player: SquadPlayer) {
        onFieldPlayerIDs.removeAll { $0 == player.playerID.uuidString }
    }

    // MARK: - Positions

    func lineupSlot(for playerID: UUID) -> FixtureLineupSlot? {
        lineupSlots.first { $0.playerID == playerID }
    }

    func position(for playerID: UUID) -> Position? {
        guard let code = lineupSlot(for: playerID)?.positionCode, !code.isEmpty else {
            return nil
        }
        return rules.position(forCode: code)
    }

    // MARK: - Discipline

    /// Send-offs are derived from the event log rather than stored on the player,
    /// so deleting the event in history restores eligibility for free. Covers every
    /// permanent removal in the sport's rules (send-off, red card, misconduct, …).
    var sentOffPlayerIDs: Set<UUID> {
        let rules = rules
        return Set(events.filter { event in
            event.eventKind == .discipline && rules.disciplineAction(forCode: event.actionCode)?.removal == .permanent
        }.compactMap(\.playerID))
    }

    // MARK: - Event logging

    /// Creates, inserts and attaches an event stamped with the current period/clock.
    @discardableResult
    func logEvent(_ type: FixtureEventType, player: SquadPlayer? = nil, detail: String = "", actionCode: String = "", scoreDelta: Int = 0, in context: ModelContext) -> FixtureEvent {
        let event = FixtureEvent(
            fixture: self,
            eventType: type,
            actionCode: actionCode,
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

    func logScore(team: Bool, action: ScoringAction, player: SquadPlayer?, in context: ModelContext) {
        let applied = applyScore(team: team, delta: action.points)
        guard applied != 0 else { return }
        logEvent(team ? .teamScore : .opponentScore, player: team ? player : nil, detail: action.label, actionCode: action.code, scoreDelta: applied, in: context)
    }

    /// Manual score correction. Logs nothing if the score was already 0.
    func adjustScore(team: Bool, delta: Int, in context: ModelContext) {
        let applied = applyScore(team: team, delta: delta)
        guard applied != 0 else { return }
        let detail = applied > 0 ? "+\(applied)" : "\(applied)"
        logEvent(team ? .teamScore : .opponentScore, detail: detail, scoreDelta: applied, in: context)
    }

    /// Sin bin / send off: log the discipline event, then — if the player is on
    /// the field — remove them and log a paired `.substitutionOut` at the same
    /// time, so `minutesPlayedSeconds()` needs no special case.
    func logDiscipline(_ action: DisciplineAction, player: SquadPlayer?, in context: ModelContext) {
        logEvent(.discipline, player: player, detail: action.label, actionCode: action.code, in: context)
        guard let player, action.removal != .none, isOnField(player) else { return }
        removeFromOnField(player)
        logEvent(.substitutionOut, player: player, detail: "Off — \(action.label)", in: context)
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

    func endFixture(in context: ModelContext) {
        stopClock()
        logEvent(.fixtureEnd, detail: "Final: \(teamScore) – \(opponentScore)", in: context)
        markEnded()
    }
}

extension Fixture: nonisolated TimedMatch {
    var playingTimeEvents: [PlayingTimeEvent] {
        events.map { event in
            let kind: PlayingTimeEvent.Kind
            switch event.eventKind {
            case .substitutionIn: kind = .subIn
            case .substitutionOut: kind = .subOut
            case .fixtureEnd: kind = .matchEnd
            default: kind = .other
            }
            return PlayingTimeEvent(kind: kind, playerID: event.playerID, periodNumber: event.periodNumber, elapsedSeconds: event.elapsedSeconds, timestamp: event.timestamp)
        }
    }
}
