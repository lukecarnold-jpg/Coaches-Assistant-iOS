import Testing
import Foundation
@testable import Basketball_Rotation

struct PlayingTimeTests {
    /// Builds a game and appends a substitution/game-state event without needing a
    /// persisted ModelContext — GameEvent/Game behave as plain objects until inserted.
    private func makeEvent(
        game: Game,
        type: GameEventType,
        playerID: UUID? = nil,
        period: Int,
        elapsed: Int
    ) {
        let event = GameEvent(game: game, eventType: type, playerID: playerID, periodNumber: period, elapsedSeconds: elapsed)
        game.events.append(event)
    }

    @Test func tracksSubstitutionsAcrossPeriodsAndLiveClock() {
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10) // 600s/period
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID(), f = UUID()
        game.startingLineupIDs = [a, b, c, d, e].map(\.uuidString)
        game.onCourtPlayerIDs = game.startingLineupIDs

        // Q1 3:00 in: B comes off, F comes on.
        makeEvent(game: game, type: .substitutionOut, playerID: b, period: 1, elapsed: 180)
        makeEvent(game: game, type: .substitutionIn, playerID: f, period: 1, elapsed: 180)

        // Q2 1:00 in (global 660s): A comes off, B returns.
        makeEvent(game: game, type: .substitutionOut, playerID: a, period: 2, elapsed: 60)
        makeEvent(game: game, type: .substitutionIn, playerID: b, period: 2, elapsed: 60)

        // Game still in progress: clock stopped at Q2 5:00 (global 900s).
        game.isEnded = false
        game.currentPeriod = 2
        game.elapsedSeconds = 300
        game.clockIsRunning = false

        let totals = game.minutesPlayedSeconds()

        #expect(totals[a] == 660)   // played 0..660, then subbed out for good
        #expect(totals[b] == 420)   // 0..180 (180s) + 660..900 (240s)
        #expect(totals[c] == 900)   // never subbed, full time so far
        #expect(totals[d] == 900)
        #expect(totals[e] == 900)
        #expect(totals[f] == 720)   // came on at 180, still on at 900
    }

    @Test func gameEndClosesOutRemainingIntervalsAndIgnoresLiveClock() {
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        let a = UUID(), b = UUID()
        game.startingLineupIDs = [a, b].map(\.uuidString)
        game.onCourtPlayerIDs = game.startingLineupIDs

        makeEvent(game: game, type: .gameEnd, period: 4, elapsed: 600) // global 2400s

        game.isEnded = true
        game.currentPeriod = 4
        game.elapsedSeconds = 600

        let totals = game.minutesPlayedSeconds()

        #expect(totals[a] == 2400)
        #expect(totals[b] == 2400)
    }

    @Test func playerNeverOnCourtHasNoRecordedTime() {
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        let benchOnly = UUID()
        game.startingLineupIDs = []
        game.onCourtPlayerIDs = []
        game.isEnded = false
        game.currentPeriod = 1
        game.elapsedSeconds = 300

        let totals = game.minutesPlayedSeconds()
        #expect(totals[benchOnly] == nil)
    }
}
