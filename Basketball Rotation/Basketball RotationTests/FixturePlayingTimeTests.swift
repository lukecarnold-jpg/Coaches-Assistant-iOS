import Testing
import Foundation
@testable import Basketball_Rotation

/// Ports `PlayingTimeTests`' three scenarios onto `Fixture`, guarding the
/// duplicated `minutesPlayedSeconds()` algorithm, plus sin-bin/send-off
/// scenarios specific to the new sports — proving discipline removals need no
/// special case because they're logged as an ordinary paired `.substitutionOut`.
struct FixturePlayingTimeTests {
    private func makeEvent(
        fixture: Fixture,
        type: FixtureEventType,
        actionCode: String = "",
        playerID: UUID? = nil,
        period: Int,
        elapsed: Int
    ) {
        let event = FixtureEvent(fixture: fixture, eventType: type, actionCode: actionCode, playerID: playerID, periodNumber: period, elapsedSeconds: elapsed)
        fixture.events.append(event)
    }

    @Test func tracksSubstitutionsAcrossPeriodsAndLiveClock() {
        let fixture = Fixture(sport: .basketball, opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10) // 600s/period
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID(), f = UUID()
        fixture.startingLineupIDs = [a, b, c, d, e].map(\.uuidString)
        fixture.onFieldPlayerIDs = fixture.startingLineupIDs

        // Q1 3:00 in: B comes off, F comes on.
        makeEvent(fixture: fixture, type: .substitutionOut, playerID: b, period: 1, elapsed: 180)
        makeEvent(fixture: fixture, type: .substitutionIn, playerID: f, period: 1, elapsed: 180)

        // Q2 1:00 in (global 660s): A comes off, B returns.
        makeEvent(fixture: fixture, type: .substitutionOut, playerID: a, period: 2, elapsed: 60)
        makeEvent(fixture: fixture, type: .substitutionIn, playerID: b, period: 2, elapsed: 60)

        // Fixture still in progress: clock stopped at Q2 5:00 (global 900s).
        fixture.isEnded = false
        fixture.currentPeriod = 2
        fixture.elapsedSeconds = 300
        fixture.clockIsRunning = false

        let totals = fixture.minutesPlayedSeconds()

        #expect(totals[a] == 660)
        #expect(totals[b] == 420)
        #expect(totals[c] == 900)
        #expect(totals[d] == 900)
        #expect(totals[e] == 900)
        #expect(totals[f] == 720)
    }

    @Test func fixtureEndClosesOutRemainingIntervalsAndIgnoresLiveClock() {
        let fixture = Fixture(sport: .basketball, opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        let a = UUID(), b = UUID()
        fixture.startingLineupIDs = [a, b].map(\.uuidString)
        fixture.onFieldPlayerIDs = fixture.startingLineupIDs

        makeEvent(fixture: fixture, type: .fixtureEnd, period: 4, elapsed: 600) // global 2400s

        fixture.isEnded = true
        fixture.currentPeriod = 4
        fixture.elapsedSeconds = 600

        let totals = fixture.minutesPlayedSeconds()

        #expect(totals[a] == 2400)
        #expect(totals[b] == 2400)
    }

    @Test func playerNeverOnFieldHasNoRecordedTime() {
        let fixture = Fixture(sport: .basketball, opponentName: "Wildcats", periodFormat: "quarters", periodLengthMinutes: 10)
        let benchOnly = UUID()
        fixture.startingLineupIDs = []
        fixture.onFieldPlayerIDs = []
        fixture.isEnded = false
        fixture.currentPeriod = 1
        fixture.elapsedSeconds = 300

        let totals = fixture.minutesPlayedSeconds()
        #expect(totals[benchOnly] == nil)
    }

    // MARK: - Sin bin / send off

    @Test func sinBinExcludesTheBinnedMinutesAndResumesOnReturn() {
        let fixture = Fixture(sport: .rugbyUnion, opponentName: "Lions", periodFormat: "halves", periodLengthMinutes: 40)
        let a = UUID()
        fixture.startingLineupIDs = [a.uuidString]
        fixture.onFieldPlayerIDs = fixture.startingLineupIDs

        // Sin-binned at 10:00 (600s) — the discipline event itself is a no-op
        // for playing time; the paired substitutionOut is what stops the clock.
        makeEvent(fixture: fixture, type: .discipline, actionCode: "sinBin", playerID: a, period: 1, elapsed: 600)
        makeEvent(fixture: fixture, type: .substitutionOut, playerID: a, period: 1, elapsed: 600)

        // Returns 10 minutes later, at 20:00 (1200s).
        makeEvent(fixture: fixture, type: .substitutionIn, playerID: a, period: 1, elapsed: 1200)

        fixture.isEnded = true
        fixture.currentPeriod = 1
        fixture.elapsedSeconds = 1200
        makeEvent(fixture: fixture, type: .fixtureEnd, period: 1, elapsed: 1200)

        let totals = fixture.minutesPlayedSeconds()
        // 0..600 (600s) + 1200..1200 (0s, fixture ends the instant they return) = 600s.
        #expect(totals[a] == 600)
    }

    @Test func sendOffEndsAccrualPermanently() {
        let fixture = Fixture(sport: .rugbyLeague, opponentName: "Sharks", periodFormat: "halves", periodLengthMinutes: 40)
        let a = UUID()
        fixture.startingLineupIDs = [a.uuidString]
        fixture.onFieldPlayerIDs = fixture.startingLineupIDs

        // Sent off at 15:00 (900s) — never returns.
        makeEvent(fixture: fixture, type: .discipline, actionCode: "sendOff", playerID: a, period: 1, elapsed: 900)
        makeEvent(fixture: fixture, type: .substitutionOut, playerID: a, period: 1, elapsed: 900)

        fixture.isEnded = true
        fixture.currentPeriod = 2
        fixture.elapsedSeconds = 2400
        makeEvent(fixture: fixture, type: .fixtureEnd, period: 2, elapsed: 2400)

        let totals = fixture.minutesPlayedSeconds()
        #expect(totals[a] == 900)
        #expect(fixture.sentOffPlayerIDs.contains(a))
    }
}
