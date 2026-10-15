import Foundation

/// Season totals for one player, aggregated from their per-match scorecard lines.
struct CricketSeasonStats: Identifiable, Equatable {
    let playerID: UUID
    var playerName: String
    var matches = 0

    // Batting
    var innings = 0
    var notOuts = 0
    var runs = 0
    var ballsFaced = 0
    var highScore = 0
    var highScoreNotOut = false
    var fifties = 0
    var hundreds = 0
    var fours = 0
    var sixes = 0

    // Bowling
    var ballsBowled = 0
    var maidens = 0
    var runsConceded = 0
    var wickets = 0
    var bestWickets = 0
    var bestRuns = 0
    var hasBowlingFigures = false

    // Fielding
    var catches = 0
    var runOuts = 0
    var stumpings = 0

    var id: UUID { playerID }

    var dismissals: Int { innings - notOuts }

    /// Runs per dismissal; nil until the player has been dismissed at least once.
    var battingAverage: Double? {
        dismissals > 0 ? Double(runs) / Double(dismissals) : nil
    }

    var strikeRate: Double? {
        ballsFaced > 0 ? Double(runs) / Double(ballsFaced) * 100 : nil
    }

    var bowlingAverage: Double? {
        wickets > 0 ? Double(runsConceded) / Double(wickets) : nil
    }

    var economy: Double? {
        ballsBowled > 0 ? Double(runsConceded) / (Double(ballsBowled) / Double(CricketOvers.ballsPerOver)) : nil
    }

    var highScoreText: String { "\(highScore)\(highScoreNotOut ? "*" : "")" }

    var bestBowlingText: String { hasBowlingFigures ? "\(bestWickets)/\(bestRuns)" : "–" }

    var hasBatted: Bool { innings > 0 }
    var hasBowled: Bool { ballsBowled > 0 || wickets > 0 }

    /// Builds one row per player, sorted by runs then wickets.
    static func aggregate(_ lines: [CricketPlayerStats]) -> [CricketSeasonStats] {
        var byPlayer: [UUID: CricketSeasonStats] = [:]
        for line in lines {
            var stats = byPlayer[line.playerID] ?? CricketSeasonStats(playerID: line.playerID, playerName: line.playerName)
            stats.playerName = line.playerName
            stats.matches += 1

            if line.didBat {
                stats.innings += 1
                if !line.isOut { stats.notOuts += 1 }
                stats.runs += line.runs
                stats.ballsFaced += line.ballsFaced
                stats.fours += line.fours
                stats.sixes += line.sixes
                if line.runs >= 100 {
                    stats.hundreds += 1
                } else if line.runs >= 50 {
                    stats.fifties += 1
                }
                // A not-out score beats an equal dismissed score for "high score".
                if line.runs > stats.highScore || (line.runs == stats.highScore && !line.isOut) {
                    stats.highScore = line.runs
                    stats.highScoreNotOut = !line.isOut
                }
            }

            if line.didBowl {
                stats.ballsBowled += line.ballsBowled
                stats.maidens += line.maidens
                stats.runsConceded += line.runsConceded
                stats.wickets += line.wicketsTaken
                // Best figures: most wickets, then fewest runs.
                if !stats.hasBowlingFigures || line.wicketsTaken > stats.bestWickets || (line.wicketsTaken == stats.bestWickets && line.runsConceded < stats.bestRuns) {
                    stats.bestWickets = line.wicketsTaken
                    stats.bestRuns = line.runsConceded
                    stats.hasBowlingFigures = true
                }
            }

            stats.catches += line.catches
            stats.runOuts += line.runOuts
            stats.stumpings += line.stumpings
            byPlayer[line.playerID] = stats
        }
        return byPlayer.values.sorted {
            if $0.runs != $1.runs { return $0.runs > $1.runs }
            if $0.wickets != $1.wickets { return $0.wickets > $1.wickets }
            return $0.playerName < $1.playerName
        }
    }
}

extension Double {
    /// Two-decimal display used across cricket stats ("23.50").
    var cricketStatText: String { String(format: "%.2f", self) }
}
