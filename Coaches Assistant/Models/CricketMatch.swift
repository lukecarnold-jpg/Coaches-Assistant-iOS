import Foundation
import SwiftData

/// How a batter was dismissed. Persisted by raw value — never rename cases.
nonisolated enum CricketDismissal: String, CaseIterable, Identifiable {
    case bowled
    case caught
    case lbw
    case runOut
    case stumped
    case hitWicket
    case retiredOut
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bowled: return "Bowled"
        case .caught: return "Caught"
        case .lbw: return "LBW"
        case .runOut: return "Run Out"
        case .stumped: return "Stumped"
        case .hitWicket: return "Hit Wicket"
        case .retiredOut: return "Retired Out"
        case .other: return "Other"
        }
    }
}

/// Cricket overs are written "overs.balls" (e.g. 12.3 = 12 overs and 3 balls),
/// so they're stored as legal balls and converted for display.
nonisolated enum CricketOvers {
    static let ballsPerOver = 6

    static func format(balls: Int) -> String {
        let safe = max(0, balls)
        let remainder = safe % ballsPerOver
        return remainder == 0 ? "\(safe / ballsPerOver)" : "\(safe / ballsPerOver).\(remainder)"
    }

    static func balls(overs: Int, extraBalls: Int) -> Int {
        max(0, overs) * ballsPerOver + min(max(0, extraBalls), ballsPerOver - 1)
    }
}

/// A stats-only cricket match: team totals for both innings plus a scorecard line
/// for each of our selected players. No clock, rotations or event log.
@Model
final class CricketMatch {
    var matchID: UUID = UUID()
    var date: Date = Date()
    var opponentName: String = ""
    var venue: String = ""
    /// 0 means unlimited overs (e.g. a multi-day or timed game).
    var oversPerInnings: Int = 20
    var weBattedFirst: Bool = true
    var notes: String = ""
    var isCompleted: Bool = false

    // Our innings — runs and wickets derive from the batting card; extras and
    // overs are entered separately because they aren't credited to a batter.
    var ourExtras: Int = 0
    var ourBallsFaced: Int = 0

    // Opposition innings — entered as totals, since we don't track their roster.
    var theirRuns: Int = 0
    var theirWickets: Int = 0
    var theirBallsFaced: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \CricketPlayerStats.match)
    var playerStats: [CricketPlayerStats] = []

    init(opponentName: String, date: Date = Date(), venue: String = "", oversPerInnings: Int = 20, weBattedFirst: Bool = true) {
        self.matchID = UUID()
        self.date = date
        self.opponentName = opponentName
        self.venue = venue
        self.oversPerInnings = oversPerInnings
        self.weBattedFirst = weBattedFirst
    }

    // MARK: - Our innings

    var ourRuns: Int {
        playerStats.reduce(0) { $0 + $1.runs } + ourExtras
    }

    var ourWickets: Int {
        playerStats.filter { $0.didBat && $0.isOut }.count
    }

    var battingCard: [CricketPlayerStats] {
        playerStats.filter(\.didBat).sorted { ($0.battingPosition ?? .max) < ($1.battingPosition ?? .max) }
    }

    var bowlingCard: [CricketPlayerStats] {
        playerStats.filter(\.didBowl).sorted { $0.ballsBowled > $1.ballsBowled }
    }

    /// Next free slot in the batting order (1-based).
    var nextBattingPosition: Int {
        (playerStats.compactMap(\.battingPosition).max() ?? 0) + 1
    }

    // MARK: - Summary

    var ourScoreLine: String {
        CricketMatch.scoreLine(runs: ourRuns, wickets: ourWickets, balls: ourBallsFaced)
    }

    var theirScoreLine: String {
        CricketMatch.scoreLine(runs: theirRuns, wickets: theirWickets, balls: theirBallsFaced)
    }

    /// "142/6 (19.4)" — runs/wickets, with overs shown once any have been entered.
    static func scoreLine(runs: Int, wickets: Int, balls: Int) -> String {
        let overs = balls > 0 ? " (\(CricketOvers.format(balls: balls)))" : ""
        return "\(runs)/\(wickets)\(overs)"
    }

    var result: CricketResult? {
        guard isCompleted else { return nil }
        return CricketResult(
            ourRuns: ourRuns,
            ourWickets: ourWickets,
            theirRuns: theirRuns,
            theirWickets: theirWickets,
            weBattedFirst: weBattedFirst,
            playersPerSide: max(playerStats.count, 2)
        )
    }
}

/// Outcome of a completed limited-overs style match, using the usual conventions:
/// the side batting first wins "by N runs"; the side chasing wins "by N wickets".
nonisolated struct CricketResult: Equatable {
    enum Outcome: Equatable {
        case won
        case lost
        case tied
    }

    let outcome: Outcome
    let summary: String

    init(ourRuns: Int, ourWickets: Int, theirRuns: Int, theirWickets: Int, weBattedFirst: Bool, playersPerSide: Int) {
        let maxWickets = max(1, playersPerSide - 1)
        if ourRuns == theirRuns {
            outcome = .tied
            summary = "Match tied"
        } else if ourRuns > theirRuns {
            outcome = .won
            if weBattedFirst {
                let margin = ourRuns - theirRuns
                summary = "Won by \(margin) run\(margin == 1 ? "" : "s")"
            } else {
                let margin = max(0, maxWickets - ourWickets)
                summary = "Won by \(margin) wicket\(margin == 1 ? "" : "s")"
            }
        } else {
            outcome = .lost
            if weBattedFirst {
                let margin = max(0, maxWickets - theirWickets)
                summary = "Lost by \(margin) wicket\(margin == 1 ? "" : "s")"
            } else {
                let margin = theirRuns - ourRuns
                summary = "Lost by \(margin) run\(margin == 1 ? "" : "s")"
            }
        }
    }
}

/// One of our players' contributions in one match.
@Model
final class CricketPlayerStats {
    var statsID: UUID = UUID()
    var playerID: UUID = UUID()
    var playerName: String = ""

    // Batting — `battingPosition == nil` means the player didn't bat.
    var battingPosition: Int?
    var runs: Int = 0
    var ballsFaced: Int = 0
    var fours: Int = 0
    var sixes: Int = 0
    var isOut: Bool = false
    var dismissalCode: String = ""

    // Bowling
    var ballsBowled: Int = 0
    var maidens: Int = 0
    var runsConceded: Int = 0
    var wicketsTaken: Int = 0
    var wides: Int = 0
    var noBalls: Int = 0

    // Fielding
    var catches: Int = 0
    var runOuts: Int = 0
    var stumpings: Int = 0

    var match: CricketMatch?

    init(match: CricketMatch?, playerID: UUID, playerName: String) {
        self.statsID = UUID()
        self.playerID = playerID
        self.playerName = playerName
        self.match = match
    }

    var didBat: Bool { battingPosition != nil }
    var didBowl: Bool { ballsBowled > 0 || wicketsTaken > 0 || runsConceded > 0 }

    var dismissal: CricketDismissal? {
        isOut ? CricketDismissal(rawValue: dismissalCode) : nil
    }

    /// e.g. "45* (32)" — the asterisk marks not out.
    var battingLine: String {
        "\(runs)\(isOut ? "" : "*") (\(ballsFaced))"
    }

    /// e.g. "4-0-28-2" (overs-maidens-runs-wickets).
    var bowlingLine: String {
        "\(CricketOvers.format(balls: ballsBowled))-\(maidens)-\(runsConceded)-\(wicketsTaken)"
    }

    var strikeRate: Double? {
        ballsFaced > 0 ? Double(runs) / Double(ballsFaced) * 100 : nil
    }

    var economy: Double? {
        ballsBowled > 0 ? Double(runsConceded) / (Double(ballsBowled) / Double(CricketOvers.ballsPerOver)) : nil
    }
}
