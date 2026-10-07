import Testing
import Foundation
@testable import Coaches_Assistant

@MainActor
struct MatchLiveActivityTests {
    private func makeFixture() -> Fixture {
        Fixture(sport: .basketball, opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
    }

    @Test func stoppedClockReportsFrozenRemainingTime() {
        let fixture = makeFixture()
        fixture.elapsedSeconds = 135
        fixture.teamScore = 12
        fixture.opponentScore = 9

        let state = MatchLiveActivityController.state(for: fixture)
        #expect(state.remainingSeconds == 465)
        #expect(state.periodEndsAt == nil)
        #expect(state.teamScore == 12)
        #expect(state.opponentScore == 9)
        #expect(state.periodLabel == "1st Quarter")
        #expect(state.isEnded == false)
    }

    @Test func runningClockReportsWhenThePeriodEnds() {
        let fixture = makeFixture()
        let start = Date(timeIntervalSince1970: 1_000_000)
        fixture.elapsedSeconds = 60
        fixture.clockIsRunning = true
        fixture.clockStartedAt = start

        let state = MatchLiveActivityController.state(for: fixture)
        // 600s period, 60s already elapsed before this run started.
        #expect(state.periodEndsAt == start.addingTimeInterval(540))
    }

    /// The state must not depend on "now", so SwiftUI's onChange only fires when
    /// the match itself changes rather than every time it's evaluated.
    @Test func stateIsDeterministicForTheSameMatch() {
        let fixture = makeFixture()
        fixture.clockIsRunning = true
        fixture.clockStartedAt = Date()
        #expect(MatchLiveActivityController.state(for: fixture) == MatchLiveActivityController.state(for: fixture))
    }

    @Test func endedMatchHasNoCountdown() {
        let fixture = makeFixture()
        fixture.clockIsRunning = true
        fixture.clockStartedAt = Date()
        fixture.isEnded = true
        let state = MatchLiveActivityController.state(for: fixture)
        #expect(state.isEnded)
        #expect(state.periodEndsAt == nil)
    }

    @Test func attributesIdentifyTheMatchAndSport() {
        let fixture = makeFixture()
        let attributes = MatchLiveActivityController.attributes(for: fixture)
        #expect(attributes.matchID == fixture.fixtureID.uuidString)
        #expect(attributes.sportName == "Basketball")
        #expect(attributes.sportSymbol == "figure.basketball")
        #expect(attributes.opponentName == "Wildcats")
    }

    /// ActivityKit caps static + dynamic data at 4 KB.
    @Test func payloadStaysWellUnderTheActivityKitLimit() throws {
        let fixture = makeFixture()
        fixture.opponentName = String(repeating: "Long Opponent Name ", count: 5)
        let encoder = JSONEncoder()
        let size = try encoder.encode(MatchLiveActivityController.attributes(for: fixture)).count
            + encoder.encode(MatchLiveActivityController.state(for: fixture)).count
        #expect(size < 1024)
    }
}
