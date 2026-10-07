import SwiftUI
import SwiftData

/// Season leaderboard across every recorded cricket match.
struct CricketSeasonStatsView: View {
    @Query private var allLines: [CricketPlayerStats]
    @State private var category: Category = .batting
    @State private var completedOnly = false

    enum Category: String, CaseIterable, Identifiable {
        case batting = "Batting"
        case bowling = "Bowling"
        case fielding = "Fielding"
        var id: String { rawValue }
    }

    private var season: [CricketSeasonStats] {
        let lines = allLines.filter { $0.match != nil && (!completedOnly || $0.match?.isCompleted == true) }
        return CricketSeasonStats.aggregate(lines)
    }

    private var rows: [CricketSeasonStats] {
        switch category {
        case .batting:
            return season.filter(\.hasBatted)
        case .bowling:
            return season.filter(\.hasBowled).sorted {
                $0.wickets != $1.wickets ? $0.wickets > $1.wickets : ($0.bowlingAverage ?? .infinity) < ($1.bowlingAverage ?? .infinity)
            }
        case .fielding:
            return season.filter { $0.catches + $0.runOuts + $0.stumpings > 0 }.sorted {
                ($0.catches + $0.runOuts + $0.stumpings) > ($1.catches + $1.runOuts + $1.stumpings)
            }
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Category", selection: $category) {
                    ForEach(Category.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Completed Matches Only", isOn: $completedOnly)
            }

            if rows.isEmpty {
                ContentUnavailableView("No \(category.rawValue) Stats", systemImage: "chart.bar", description: Text("Stats appear here once you record them on a match scorecard."))
            } else {
                Section {
                    ForEach(rows) { stats in
                        row(for: stats)
                    }
                }
            }
        }
        .navigationTitle("Season Stats")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: seasonExport, preview: SharePreview(seasonExport.filename, image: Image(systemName: "tablecells"))) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export season stats CSV")
            }
        }
    }

    @ViewBuilder
    private func row(for stats: CricketSeasonStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(stats.playerName)
                    .font(.headline)
                Spacer()
                Text(headline(for: stats))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Sport.cricket.tint)
            }
            Text(detail(for: stats))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func headline(for stats: CricketSeasonStats) -> String {
        switch category {
        case .batting: return "\(stats.runs) runs"
        case .bowling: return "\(stats.wickets) wkts"
        case .fielding: return "\(stats.catches + stats.runOuts + stats.stumpings) dismissals"
        }
    }

    private func detail(for stats: CricketSeasonStats) -> String {
        switch category {
        case .batting:
            return [
                "M \(stats.matches)",
                "Inn \(stats.innings)",
                "NO \(stats.notOuts)",
                "HS \(stats.highScoreText)",
                "Avg \(stats.battingAverage?.cricketStatText ?? "–")",
                "SR \(stats.strikeRate?.cricketStatText ?? "–")",
                "50s \(stats.fifties)",
                "100s \(stats.hundreds)",
            ].joined(separator: " · ")
        case .bowling:
            return [
                "Overs \(CricketOvers.format(balls: stats.ballsBowled))",
                "Runs \(stats.runsConceded)",
                "Best \(stats.bestBowlingText)",
                "Avg \(stats.bowlingAverage?.cricketStatText ?? "–")",
                "Econ \(stats.economy?.cricketStatText ?? "–")",
            ].joined(separator: " · ")
        case .fielding:
            return "Catches \(stats.catches) · Run Outs \(stats.runOuts) · Stumpings \(stats.stumpings)"
        }
    }

    private var seasonExport: CSVExportFile {
        var lines = ["Player,Matches,Innings,Not Outs,Runs,High Score,Average,Strike Rate,50s,100s,4s,6s,Overs,Maidens,Runs Conceded,Wickets,Best,Bowling Avg,Economy,Catches,Run Outs,Stumpings"]
        for stats in season {
            lines.append([
                stats.playerName, "\(stats.matches)", "\(stats.innings)", "\(stats.notOuts)", "\(stats.runs)", stats.highScoreText,
                stats.battingAverage?.cricketStatText ?? "", stats.strikeRate?.cricketStatText ?? "", "\(stats.fifties)", "\(stats.hundreds)",
                "\(stats.fours)", "\(stats.sixes)", CricketOvers.format(balls: stats.ballsBowled), "\(stats.maidens)", "\(stats.runsConceded)",
                "\(stats.wickets)", stats.bestBowlingText, stats.bowlingAverage?.cricketStatText ?? "", stats.economy?.cricketStatText ?? "",
                "\(stats.catches)", "\(stats.runOuts)", "\(stats.stumpings)",
            ].map(RosterCSV.escape).joined(separator: ","))
        }
        return CSVExportFile(filename: "Cricket_Season_Stats.csv", content: lines.joined(separator: "\n"))
    }
}
