import Testing
import Foundation
@testable import Coaches_Assistant

@MainActor
struct CricketTests {
    private func line(_ name: String, id: UUID = UUID(), batAt: Int? = nil, runs: Int = 0, balls: Int = 0, out: Bool = false,
                      bowled: Int = 0, conceded: Int = 0, wickets: Int = 0, catches: Int = 0) -> CricketPlayerStats {
        let stats = CricketPlayerStats(match: nil, playerID: id, playerName: name)
        stats.battingPosition = batAt
        stats.runs = runs
        stats.ballsFaced = balls
        stats.isOut = out
        stats.ballsBowled = bowled
        stats.runsConceded = conceded
        stats.wicketsTaken = wickets
        stats.catches = catches
        return stats
    }

    // MARK: - Sport

    @Test func cricketIsAStatsOnlySport() {
        let rules = Sport.cricket.rules
        #expect(Sport.cricket.rawValue == "cricket")
        #expect(rules.isStatsOnly)
        #expect(rules.onFieldCount == 11)
        #expect(rules.position(forCode: "WK")?.name == "Wicketkeeper")
        #expect(Sport.allCases.filter { $0.rules.isStatsOnly } == [.cricket])
    }

    // MARK: - Overs

    @Test func oversFormatting() {
        #expect(CricketOvers.format(balls: 0) == "0")
        #expect(CricketOvers.format(balls: 6) == "1")
        #expect(CricketOvers.format(balls: 117) == "19.3")
        #expect(CricketOvers.balls(overs: 19, extraBalls: 3) == 117)
        #expect(CricketOvers.balls(overs: 2, extraBalls: 9) == 17) // balls capped at 5
    }

    // MARK: - Match totals

    @Test func ourTotalComesFromBattingCardPlusExtras() {
        let match = CricketMatch(opponentName: "Rovers")
        match.playerStats = [
            line("A", batAt: 1, runs: 40, out: true),
            line("B", batAt: 2, runs: 25),
            line("C"), // didn't bat
        ]
        match.ourExtras = 7
        match.ourBallsFaced = 120
        #expect(match.ourRuns == 72)
        #expect(match.ourWickets == 1)
        #expect(match.ourScoreLine == "72/1 (20)")
        #expect(match.battingCard.map(\.playerName) == ["A", "B"])
        #expect(match.nextBattingPosition == 3)
    }

    @Test func battingAndBowlingLines() {
        let batter = line("A", batAt: 1, runs: 45, balls: 30)
        #expect(batter.battingLine == "45* (30)")
        #expect(batter.strikeRate == 150)

        let bowler = line("B", bowled: 24, conceded: 28, wickets: 2)
        bowler.maidens = 1
        #expect(bowler.bowlingLine == "4-1-28-2")
        #expect(bowler.economy == 7)
    }

    // MARK: - Results

    @Test func resultSummaries() {
        #expect(CricketResult(ourRuns: 150, ourWickets: 6, theirRuns: 130, theirWickets: 10, weBattedFirst: true, playersPerSide: 11).summary == "Won by 20 runs")
        #expect(CricketResult(ourRuns: 131, ourWickets: 4, theirRuns: 130, theirWickets: 8, weBattedFirst: false, playersPerSide: 11).summary == "Won by 6 wickets")
        #expect(CricketResult(ourRuns: 120, ourWickets: 10, theirRuns: 121, theirWickets: 3, weBattedFirst: true, playersPerSide: 11).summary == "Lost by 7 wickets")
        #expect(CricketResult(ourRuns: 100, ourWickets: 10, theirRuns: 101, theirWickets: 9, weBattedFirst: false, playersPerSide: 11).summary == "Lost by 1 run")
        let tie = CricketResult(ourRuns: 99, ourWickets: 5, theirRuns: 99, theirWickets: 5, weBattedFirst: true, playersPerSide: 11)
        #expect(tie.outcome == .tied)
    }

    @Test func resultOnlyShownOnceCompleted() {
        let match = CricketMatch(opponentName: "Rovers")
        match.theirRuns = 10
        #expect(match.result == nil)
        match.isCompleted = true
        #expect(match.result?.outcome == .lost)
    }

    // MARK: - Season

    @Test func seasonAggregatesAcrossMatches() throws {
        let id = UUID()
        let season = CricketSeasonStats.aggregate([
            line("Sam", id: id, batAt: 1, runs: 55, balls: 40, out: true, bowled: 18, conceded: 20, wickets: 1, catches: 1),
            line("Sam", id: id, batAt: 2, runs: 30, balls: 20, out: false, bowled: 24, conceded: 15, wickets: 3),
            line("Sam", id: id, batAt: 1, runs: 102, balls: 80, out: true),
        ])
        let sam = try #require(season.first)
        #expect(season.count == 1)
        #expect(sam.matches == 3)
        #expect(sam.innings == 3)
        #expect(sam.notOuts == 1)
        #expect(sam.runs == 187)
        #expect(sam.battingAverage == 93.5)
        #expect(sam.highScoreText == "102")
        #expect(sam.fifties == 1)
        #expect(sam.hundreds == 1)
        #expect(sam.wickets == 4)
        #expect(sam.bestBowlingText == "3/15")
        #expect(sam.catches == 1)
    }

    @Test func averageIsNilWithoutDismissals() {
        let season = CricketSeasonStats.aggregate([line("Al", batAt: 1, runs: 12, balls: 10, out: false)])
        #expect(season.first?.battingAverage == nil)
        #expect(season.first?.highScoreText == "12*")
    }

    @Test func bestFiguresPreferMoreWicketsThenFewerRuns() {
        let id = UUID()
        let season = CricketSeasonStats.aggregate([
            line("B", id: id, bowled: 6, conceded: 0, wickets: 0),
            line("B", id: id, bowled: 12, conceded: 30, wickets: 0),
            line("B", id: id, bowled: 12, conceded: 25, wickets: 2),
            line("B", id: id, bowled: 12, conceded: 10, wickets: 2),
        ])
        #expect(season.first?.bestBowlingText == "2/10")
    }
}
