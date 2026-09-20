import Testing
import Foundation
@testable import Coaches_Assistant

struct GameClockTests {
    @Test func remainingSecondsClampsAtZero() {
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        #expect(game.remainingSeconds(at: 700) == 0)
        #expect(game.remainingSeconds(at: 100) == 500)
    }

    @Test func periodLabelForQuartersIncludingOvertime() {
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        game.currentPeriod = 1
        #expect(game.periodLabel == "1st Quarter")
        game.currentPeriod = 4
        #expect(game.periodLabel == "4th Quarter")
        game.currentPeriod = 5
        #expect(game.periodLabel == "OT 1")
        #expect(game.totalPeriods == 4)
    }

    @Test func periodLabelForHalvesIncludingOvertime() {
        let game = Game(opponentName: "Wildcats", periodFormat: "halves", periodLengthMinutes: 20)
        game.currentPeriod = 2
        #expect(game.periodLabel == "2nd Half")
        game.currentPeriod = 3
        #expect(game.periodLabel == "OT 1")
        #expect(game.totalPeriods == 2)
    }

    @Test func currentElapsedSecondsWhileStopped() {
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        game.elapsedSeconds = 42
        game.clockIsRunning = false
        #expect(game.currentElapsedSeconds() == 42)
    }

    @Test func currentElapsedSecondsWhileRunningAddsWallClockDelta() {
        let game = Game(opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        game.elapsedSeconds = 30
        game.clockIsRunning = true
        game.clockStartedAt = Date().addingTimeInterval(-5)
        let elapsed = game.currentElapsedSeconds()
        #expect(elapsed >= 34 && elapsed <= 36)
    }
}
