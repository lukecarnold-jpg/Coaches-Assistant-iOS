import Foundation
import SwiftData

/// One-time copy of Basketball's original `Player` / `Game` / `GameEvent` /
/// `GameAttendance` records into the shared `SquadPlayer` / `Fixture` models that
/// every other timed sport uses.
///
/// Safety properties:
/// - **Non-destructive.** Legacy rows are left in place, so nothing is lost if a
///   later step fails or the migration ever needs to be re-run.
/// - **Idempotent.** Records keep their original IDs (`playerID` → `playerID`,
///   `gameID` → `fixtureID`, `eventID` → `eventID`), and anything already present
///   in the new models is skipped — running it twice never duplicates data.
/// - **All-or-nothing.** Everything is inserted then saved once; on failure the
///   context is rolled back and the completion flag is left unset so the next
///   launch retries.
enum LegacyBasketballMigration {
    static let completedKey = "legacyBasketballMigration.v1.completed"

    struct Summary: Equatable {
        var players = 0
        var games = 0
        var events = 0
        var attendances = 0

        var isEmpty: Bool { players == 0 && games == 0 }
    }

    /// Runs the migration unless it has already completed on this device.
    @discardableResult
    static func migrateIfNeeded(context: ModelContext, defaults: UserDefaults = .standard) -> Summary {
        guard !defaults.bool(forKey: completedKey) else { return Summary() }
        do {
            let summary = try migrate(context: context)
            defaults.set(true, forKey: completedKey)
            if !summary.isEmpty {
                print("Migrated legacy Basketball data: \(summary)")
            }
            return summary
        } catch {
            context.rollback()
            print("Legacy Basketball migration failed; will retry next launch: \(error)")
            return Summary()
        }
    }

    /// Copies every legacy record that doesn't already exist in the shared models.
    static func migrate(context: ModelContext) throws -> Summary {
        var summary = Summary()
        let basketball = Sport.basketball.rawValue

        let existingPlayerIDs = Set(try context.fetch(FetchDescriptor<SquadPlayer>(
            predicate: #Predicate { $0.sport == basketball }
        )).map(\.playerID))
        for player in try context.fetch(FetchDescriptor<Player>()) where !existingPlayerIDs.contains(player.playerID) {
            let squadPlayer = SquadPlayer(sport: .basketball, name: player.name, jerseyNumber: player.jerseyNumber)
            squadPlayer.playerID = player.playerID
            squadPlayer.createdAt = player.createdAt
            context.insert(squadPlayer)
            summary.players += 1
        }

        let existingFixtureIDs = Set(try context.fetch(FetchDescriptor<Fixture>(
            predicate: #Predicate { $0.sport == basketball }
        )).map(\.fixtureID))
        for game in try context.fetch(FetchDescriptor<Game>()) where !existingFixtureIDs.contains(game.gameID) {
            let fixture = Fixture(sport: .basketball, opponentName: game.opponentName, periodFormat: game.periodFormat, periodLengthMinutes: game.periodLengthMinutes)
            fixture.fixtureID = game.gameID
            fixture.date = game.date
            fixture.currentPeriod = game.currentPeriod
            fixture.teamScore = game.teamScore
            fixture.opponentScore = game.opponentScore
            fixture.notes = game.notes
            fixture.isEnded = game.isEnded
            fixture.isGameDayModeActive = game.isGameDayModeActive
            fixture.elapsedSeconds = game.elapsedSeconds
            fixture.clockIsRunning = game.clockIsRunning
            fixture.clockStartedAt = game.clockStartedAt
            fixture.startingLineupIDs = game.startingLineupIDs
            fixture.onFieldPlayerIDs = game.onCourtPlayerIDs
            context.insert(fixture)

            for legacy in game.events {
                let mapped = mapEvent(legacy.eventKind)
                let event = FixtureEvent(
                    fixture: fixture,
                    eventType: mapped.type,
                    actionCode: mapped.actionCode,
                    playerID: legacy.playerID,
                    playerName: legacy.playerName,
                    detail: legacy.detail,
                    periodNumber: legacy.periodNumber,
                    elapsedSeconds: legacy.elapsedSeconds,
                    scoreDelta: legacy.scoreDelta
                )
                event.eventID = legacy.eventID
                event.timestamp = legacy.timestamp
                context.insert(event)
                fixture.events.append(event)
                summary.events += 1
            }

            for legacy in game.attendances {
                let attendance = FixtureAttendance(fixture: fixture, playerID: legacy.playerID, playerName: legacy.playerName)
                attendance.attendanceID = legacy.attendanceID
                attendance.isAbsent = legacy.isAbsent
                context.insert(attendance)
                fixture.attendances.append(attendance)
                summary.attendances += 1
            }
            summary.games += 1
        }

        if context.hasChanges {
            try context.save()
        }
        return summary
    }

    /// Basketball's event vocabulary → the shared one. Fouls become discipline
    /// events with Basketball's "foul" action code so they keep the right icon.
    static func mapEvent(_ kind: GameEventType) -> (type: FixtureEventType, actionCode: String) {
        switch kind {
        case .substitutionIn: return (.substitutionIn, "")
        case .substitutionOut: return (.substitutionOut, "")
        case .foul: return (.discipline, "foul")
        case .teamScore: return (.teamScore, "")
        case .opponentScore: return (.opponentScore, "")
        case .periodAdvance: return (.periodAdvance, "")
        case .gameEnd: return (.fixtureEnd, "")
        case .note: return (.note, "")
        case .mvpVote: return (.mvpVote, "")
        }
    }

    /// Deletes the legacy Basketball records. Called when the coach deletes
    /// Basketball data, so the untouched originals don't linger invisibly.
    static func deleteLegacyData(in context: ModelContext, players: Bool, games: Bool) throws {
        if games {
            // Deleting each game cascades to its events and attendance.
            try context.deleteEach(Game.self)
        }
        if players {
            try context.deleteEach(Player.self)
        }
    }
}

extension ModelContext {
    /// Deletes every instance of `type` one by one. Unlike the batch
    /// `delete(model:)`, this applies relationship delete rules, so it works for
    /// models with inverse relationships (a batch delete of e.g. `GameEvent` fails
    /// with "mandatory OTO nullify inverse").
    func deleteEach<T: PersistentModel>(_ type: T.Type) throws {
        for object in try fetch(FetchDescriptor<T>()) {
            delete(object)
        }
    }
}
