import Testing
import Foundation
import SwiftData
@testable import Coaches_Assistant

/// Covers the clock/period/score logic shared by `Game` and `Fixture` via `TimedMatch`.
@MainActor
struct TimedMatchTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Player.self, Game.self, GameEvent.self, GameAttendance.self,
            SquadPlayer.self, Fixture.self, FixtureEvent.self, FixtureAttendance.self, FixtureLineupSlot.self,
            CricketMatch.self, CricketPlayerStats.self,
        ])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    // MARK: - Clock

    @Test func runningClockIsCappedAtPeriodLength() {
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        game.clockIsRunning = true
        game.clockStartedAt = Date().addingTimeInterval(-900) // 15 min ago, 10 min period
        #expect(game.currentElapsedSeconds() == 600)
        #expect(game.clockHasExpired())
    }

    @Test func stopClockPersistsCappedElapsed() {
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        game.clockIsRunning = true
        game.clockStartedAt = Date().addingTimeInterval(-900)
        game.stopClock()
        #expect(game.elapsedSeconds == 600)
        #expect(game.clockIsRunning == false)
        #expect(game.clockStartedAt == nil)
    }

    @Test func startClockRefusesOnceExpired() {
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        game.elapsedSeconds = 600
        game.startClock()
        #expect(game.clockIsRunning == false)
    }

    @Test func manualTimeIsValidatedAndClamped() {
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        #expect(game.isValidRemainingTime(minutes: 5, seconds: 30))
        #expect(!game.isValidRemainingTime(minutes: 5, seconds: 75))
        #expect(!game.isValidRemainingTime(minutes: 11, seconds: 0))
        #expect(!game.isValidRemainingTime(minutes: -1, seconds: 0))

        game.setRemainingTime(minutes: 4, seconds: 15)
        #expect(game.elapsedSeconds == 600 - 255)

        game.setRemainingTime(minutes: 99, seconds: 99)
        #expect(game.elapsedSeconds == 0)
    }

    @Test func playingTimeIgnoresClockOverrun() {
        // Clock left running 5 minutes past the end of Q1 must not credit extra time.
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        let a = UUID()
        game.startingLineupIDs = [a.uuidString]
        game.clockIsRunning = true
        game.clockStartedAt = Date().addingTimeInterval(-900)
        #expect(game.minutesPlayedSeconds()[a] == 600)
    }

    @Test func storedEventElapsedBeyondPeriodIsClamped() {
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        let a = UUID()
        game.startingLineupIDs = [a.uuidString]
        game.events.append(GameEvent(game: game, eventType: .substitutionOut, playerID: a, periodNumber: 1, elapsedSeconds: 750))
        #expect(game.minutesPlayedSeconds()[a] == 600)
    }

    // MARK: - Periods

    @Test func overtimeLabels() {
        let quarters = Game(opponentName: "A", periodFormat: "quarters", periodLengthMinutes: 10)
        #expect(quarters.periodLabel(forPeriod: 5) == "OT 1")
        #expect(quarters.periodLabel(forPeriod: 6) == "OT 2")
        #expect(quarters.shortPeriodLabel(forPeriod: 3) == "Q3")
        #expect(quarters.shortPeriodLabel(forPeriod: 5) == "OT1")

        let halves = Fixture(sport: .soccer, opponentName: "B", periodFormat: "halves", periodLengthMinutes: 45)
        #expect(halves.periodLabel(forPeriod: 2) == "2nd Half")
        #expect(halves.periodLabel(forPeriod: 3) == "OT 1")
        #expect(halves.shortPeriodLabel(forPeriod: 2) == "H2")
        #expect(halves.shortPeriodLabel(forPeriod: 4) == "OT2")
    }

    @Test func advancingPastRegulationEntersOvertime() throws {
        let context = try makeContext()
        let game = Game(opponentName: "Wildcats", periodFormat: "halves", periodLengthMinutes: 20)
        context.insert(game)
        game.currentPeriod = 2
        game.elapsedSeconds = 1200
        game.advancePeriod(in: context)
        #expect(game.currentPeriod == 3)
        #expect(game.isInOvertime)
        #expect(game.periodLabel == "OT 1")
        #expect(game.elapsedSeconds == 0)
        #expect(game.events.last?.eventKind == .periodAdvance)
    }

    @Test func endGameStopsClockAndClearsGameDayMode() throws {
        let context = try makeContext()
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        context.insert(game)
        game.clockIsRunning = true
        game.clockStartedAt = Date().addingTimeInterval(-30)
        game.endGame(in: context)
        #expect(game.isEnded)
        #expect(game.isGameDayModeActive == false)
        #expect(game.clockIsRunning == false)
        #expect(game.events.last?.eventKind == .gameEnd)
    }

    // MARK: - Score

    @Test func decrementAtZeroLogsNothing() throws {
        let context = try makeContext()
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        context.insert(game)
        game.adjustScore(team: true, delta: -1, in: context)
        game.adjustScore(team: false, delta: -1, in: context)
        #expect(game.teamScore == 0)
        #expect(game.opponentScore == 0)
        #expect(game.events.isEmpty)
    }

    @Test func opponentScoreAcceptsMultiPointBaskets() throws {
        let context = try makeContext()
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        context.insert(game)
        game.adjustScore(team: false, delta: 3, in: context)
        #expect(game.opponentScore == 3)
        #expect(game.events.last?.scoreDelta == 3)
    }

    @Test func resetClockIsRecordedInHistory() throws {
        let context = try makeContext()
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        context.insert(game)
        game.elapsedSeconds = 300
        game.resetClock(in: context)
        #expect(game.elapsedSeconds == 0)
        #expect(game.events.last?.eventKind == .note)
        #expect(game.events.last?.detail.contains("Clock reset") == true)
    }

    // MARK: - Discipline

    @Test func everyPermanentRemovalCountsAsSentOff() {
        let fixture = Fixture(sport: .soccer, opponentName: "United", periodFormat: "halves", periodLengthMinutes: 45)
        let red = UUID(), yellow = UUID()
        fixture.events.append(FixtureEvent(fixture: fixture, eventType: .discipline, actionCode: "redCard", playerID: red))
        fixture.events.append(FixtureEvent(fixture: fixture, eventType: .discipline, actionCode: "yellowCard", playerID: yellow))
        #expect(fixture.sentOffPlayerIDs == [red])
    }

    @Test func gameDayModeDefaultsOnForNewMatches() {
        #expect(Game(opponentName: "A", periodFormat: "quarters", periodLengthMinutes: 10).isGameDayModeActive)
        #expect(Fixture(sport: .netball, opponentName: "B", periodFormat: "quarters", periodLengthMinutes: 15).isGameDayModeActive)
    }

    @Test func allModelsBuildIntoOneContainer() throws {
        _ = try makeContext()
    }
}
