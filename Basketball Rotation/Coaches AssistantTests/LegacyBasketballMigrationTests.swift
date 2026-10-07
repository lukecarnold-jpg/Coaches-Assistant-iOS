import Testing
import Foundation
import SwiftData
@testable import Coaches_Assistant

@MainActor
struct LegacyBasketballMigrationTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Player.self, Game.self, GameEvent.self, GameAttendance.self,
            SquadPlayer.self, Fixture.self, FixtureEvent.self, FixtureAttendance.self, FixtureLineupSlot.self,
            CricketMatch.self, CricketPlayerStats.self,
        ])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    /// A legacy store: two players, one in-progress game with a sub, foul, score and attendance.
    private func seedLegacyData(in context: ModelContext) throws -> (jordan: Player, pippen: Player, game: Game) {
        let jordan = Player(name: "Jordan", jerseyNumber: 23)
        let pippen = Player(name: "Pippen", jerseyNumber: 33)
        context.insert(jordan)
        context.insert(pippen)

        let game = Game(opponentName: "Pistons", periodFormat: "quarters", periodLengthMinutes: 12)
        context.insert(game)
        game.currentPeriod = 3
        game.teamScore = 58
        game.opponentScore = 51
        game.notes = "Switch on screens"
        game.elapsedSeconds = 240
        game.startingLineupIDs = [jordan.playerID.uuidString]
        game.onCourtPlayerIDs = [pippen.playerID.uuidString]

        let events: [GameEvent] = [
            GameEvent(game: game, eventType: .substitutionOut, playerID: jordan.playerID, playerName: "Jordan", detail: "Out → Pippen", periodNumber: 2, elapsedSeconds: 300),
            GameEvent(game: game, eventType: .substitutionIn, playerID: pippen.playerID, playerName: "Pippen", detail: "In for Jordan", periodNumber: 2, elapsedSeconds: 300),
            GameEvent(game: game, eventType: .foul, playerID: pippen.playerID, playerName: "Pippen", detail: "Foul", periodNumber: 3, elapsedSeconds: 60),
            GameEvent(game: game, eventType: .teamScore, playerID: pippen.playerID, playerName: "Pippen", detail: "+3", periodNumber: 3, elapsedSeconds: 120, scoreDelta: 3),
        ]
        for event in events {
            context.insert(event)
            game.events.append(event)
        }

        let absent = GameAttendance(game: game, playerID: jordan.playerID, playerName: "Jordan")
        absent.isAbsent = true
        context.insert(absent)
        game.attendances.append(absent)

        try context.save()
        return (jordan, pippen, game)
    }

    @Test func copiesPlayersGamesEventsAndAttendanceWithOriginalIDs() throws {
        let context = try makeContext()
        let legacy = try seedLegacyData(in: context)

        let summary = try LegacyBasketballMigration.migrate(context: context)
        #expect(summary == .init(players: 2, games: 1, events: 4, attendances: 1))

        let squad = try context.fetch(FetchDescriptor<SquadPlayer>())
        #expect(squad.count == 2)
        #expect(squad.allSatisfy { $0.sport == Sport.basketball.rawValue })
        let jordan = try #require(squad.first { $0.playerID == legacy.jordan.playerID })
        #expect(jordan.name == "Jordan")
        #expect(jordan.jerseyNumber == 23)
        #expect(jordan.createdAt == legacy.jordan.createdAt)

        let fixture = try #require(try context.fetch(FetchDescriptor<Fixture>()).first)
        #expect(fixture.fixtureID == legacy.game.gameID)
        #expect(fixture.sportValue == .basketball)
        #expect(fixture.opponentName == "Pistons")
        #expect(fixture.periodLengthMinutes == 12)
        #expect(fixture.currentPeriod == 3)
        #expect(fixture.teamScore == 58)
        #expect(fixture.opponentScore == 51)
        #expect(fixture.notes == "Switch on screens")
        #expect(fixture.elapsedSeconds == 240)
        #expect(fixture.date == legacy.game.date)
        #expect(fixture.startingLineupIDs == [legacy.jordan.playerID.uuidString])
        #expect(fixture.onFieldPlayerIDs == [legacy.pippen.playerID.uuidString])

        #expect(fixture.events.count == 4)
        let foul = try #require(fixture.events.first { $0.eventKind == .discipline })
        #expect(foul.actionCode == "foul")
        #expect(foul.symbolName(for: .basketball) == "hand.raised")
        let score = try #require(fixture.events.first { $0.eventKind == .teamScore })
        #expect(score.scoreDelta == 3)
        let legacyIDs = Set(legacy.game.events.map(\.eventID))
        #expect(Set(fixture.events.map(\.eventID)) == legacyIDs)

        #expect(fixture.attendances.count == 1)
        #expect(fixture.attendances.first?.isAbsent == true)
    }

    @Test func playingTimeMatchesAfterMigration() throws {
        let context = try makeContext()
        let legacy = try seedLegacyData(in: context)
        _ = try LegacyBasketballMigration.migrate(context: context)

        let fixture = try #require(try context.fetch(FetchDescriptor<Fixture>()).first)
        let totals = fixture.minutesPlayedSeconds()
        // Jordan: started, subbed off at Q2 5:00 → 12*60 + 300 = 1020s.
        #expect(totals[legacy.jordan.playerID] == 1020)
        // Pippen: on at 1020s, still on at Q3 4:00 (2*720 + 240 = 1680s) → 660s.
        #expect(totals[legacy.pippen.playerID] == 660)
    }

    @Test func runningTwiceNeverDuplicates() throws {
        let context = try makeContext()
        _ = try seedLegacyData(in: context)

        _ = try LegacyBasketballMigration.migrate(context: context)
        let second = try LegacyBasketballMigration.migrate(context: context)

        #expect(second.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<SquadPlayer>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Fixture>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<FixtureEvent>()) == 4)
    }

    @Test func leavesLegacyRecordsInPlace() throws {
        let context = try makeContext()
        _ = try seedLegacyData(in: context)
        _ = try LegacyBasketballMigration.migrate(context: context)

        #expect(try context.fetchCount(FetchDescriptor<Player>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<Game>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<GameEvent>()) == 4)
    }

    @Test func completionFlagSkipsLaterRuns() throws {
        let context = try makeContext()
        _ = try seedLegacyData(in: context)
        let defaults = try #require(UserDefaults(suiteName: "LegacyBasketballMigrationTests.\(UUID().uuidString)"))

        let first = LegacyBasketballMigration.migrateIfNeeded(context: context, defaults: defaults)
        #expect(first.games == 1)
        #expect(defaults.bool(forKey: LegacyBasketballMigration.completedKey))

        context.insert(Player(name: "Late Addition"))
        let second = LegacyBasketballMigration.migrateIfNeeded(context: context, defaults: defaults)
        #expect(second.isEmpty)
    }

    @Test func emptyStoreMigratesNothing() throws {
        let context = try makeContext()
        let summary = try LegacyBasketballMigration.migrate(context: context)
        #expect(summary.isEmpty)
    }

    @Test func deletingBasketballDataRemovesLegacyCopies() throws {
        let context = try makeContext()
        _ = try seedLegacyData(in: context)
        try LegacyBasketballMigration.deleteLegacyData(in: context, players: true, games: true)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Player>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Game>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<GameEvent>()) == 0)
    }

    /// Guards "Delete All Data": deleting parents must cascade to children rather
    /// than failing the way a batch delete of events does.
    @Test func deleteEachCascadesToEventsAndAttendance() throws {
        let context = try makeContext()
        _ = try seedLegacyData(in: context)
        _ = try LegacyBasketballMigration.migrate(context: context)

        try context.deleteEach(Fixture.self)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Fixture>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<FixtureEvent>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<FixtureAttendance>()) == 0)
    }

    @Test func everyLegacyEventTypeHasAMapping() {
        for kind in GameEventType.allCases {
            let mapped = LegacyBasketballMigration.mapEvent(kind)
            if kind == .foul {
                #expect(mapped.type == .discipline)
                #expect(Sport.basketball.rules.disciplineAction(forCode: mapped.actionCode) != nil)
            } else {
                #expect(mapped.type.rawValue == kind.rawValue || (kind == .gameEnd && mapped.type == .fixtureEnd))
            }
        }
    }
}
