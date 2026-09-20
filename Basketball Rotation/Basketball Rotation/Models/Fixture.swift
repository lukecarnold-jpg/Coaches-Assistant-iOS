import Foundation
import SwiftData

/// The non-Basketball equivalent of `Game`. Kept as a separate model so Basketball's
/// `Game`/`GameEvent`/`GameAttendance` and every view built on them are untouched by
/// this change; the port duplicates `Game`'s clock/lineup/playing-time logic exactly,
/// with `sport`-driven rules layered on top.
@Model
final class Fixture {
    var fixtureID: UUID
    var sport: String
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
        self.elapsedSeconds = 0
        self.clockIsRunning = false
        self.clockStartedAt = nil
    }

    var sportValue: Sport { Sport(rawValue: sport) ?? .basketball }
    var rules: SportRules { sportValue.rules }

    var totalPeriods: Int {
        periodFormat == "quarters" ? 4 : 2
    }

    var periodLengthSeconds: Int {
        periodLengthMinutes * 60
    }

    var periodLabel: String { periodLabel(forPeriod: currentPeriod) }

    /// Generalized so callers needing the *next* period's label (e.g. an "Advance
    /// to 2nd Half" confirmation) don't need their own copy of this switch.
    func periodLabel(forPeriod period: Int) -> String {
        if periodFormat == "quarters" {
            switch period {
            case 1: return "1st Quarter"
            case 2: return "2nd Quarter"
            case 3: return "3rd Quarter"
            case 4: return "4th Quarter"
            default: return "OT \(period - 4)"
            }
        } else {
            switch period {
            case 1: return "1st Half"
            case 2: return "2nd Half"
            default: return "OT \(period - 2)"
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
    /// so deleting the event in history restores eligibility for free.
    var sentOffPlayerIDs: Set<UUID> {
        Set(events.filter { $0.actionCode == "sendOff" }.compactMap(\.playerID))
    }

    // MARK: - Playing time

    /// Ported line-for-line from `Game.minutesPlayedSeconds()`. Sin-bin/send-off
    /// removals need no special cases here because they're logged as an ordinary
    /// paired `.substitutionOut` alongside the discipline event.
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
            case .fixtureEnd:
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
