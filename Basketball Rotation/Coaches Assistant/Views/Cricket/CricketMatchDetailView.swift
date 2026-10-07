import SwiftUI
import SwiftData

/// Scorecard for one cricket match: team totals for both innings, our batting and
/// bowling cards, fielding, and notes. Everything is editable after the fact.
struct CricketMatchDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var squad: [SquadPlayer]

    @Bindable var match: CricketMatch

    @State private var editingStats: CricketPlayerStats?

    init(match: CricketMatch) {
        self.match = match
        let raw = Sport.cricket.rawValue
        _squad = Query(filter: #Predicate<SquadPlayer> { $0.sport == raw }, sort: \SquadPlayer.name)
    }

    private var tint: Color { Sport.cricket.tint }

    private var maxWickets: Int { max(1, max(match.playerStats.count, Sport.cricket.rules.onFieldCount) - 1) }

    private var maxOvers: Int { match.oversPerInnings > 0 ? match.oversPerInnings : 200 }

    private var notYetBatted: [CricketPlayerStats] {
        match.playerStats.filter { !$0.didBat }.sorted { $0.playerName < $1.playerName }
    }

    private var notYetBowled: [CricketPlayerStats] {
        match.playerStats.filter { !$0.didBowl }.sorted { $0.playerName < $1.playerName }
    }

    private var fielders: [CricketPlayerStats] {
        match.playerStats.filter { $0.catches + $0.runOuts + $0.stumpings > 0 }.sorted { $0.playerName < $1.playerName }
    }

    private var squadNotInMatch: [SquadPlayer] {
        let inMatch = Set(match.playerStats.map(\.playerID))
        return squad.filter { !inMatch.contains($0.playerID) }
    }

    var body: some View {
        Form {
            summarySection
            ourInningsSection
            oppositionInningsSection
            bowlingSection
            fieldingSection
            teamSection
            detailsSection
            Section("Notes") {
                TextEditor(text: $match.notes)
                    .frame(minHeight: 100)
                    .accessibilityLabel("Match notes")
            }
        }
        .numberPadDismissal()
        .navigationTitle("vs \(match.opponentName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: scorecardExport, preview: SharePreview(scorecardExport.filename, image: Image(systemName: "tablecells"))) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export scorecard CSV")
            }
        }
        .sheet(item: $editingStats) { stats in
            CricketPlayerStatsEditView(stats: stats, nextBattingPosition: match.nextBattingPosition)
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section {
            HStack {
                scoreColumn(title: "Us", score: match.ourScoreLine)
                Text("v")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                scoreColumn(title: match.opponentName, score: match.theirScoreLine)
            }
            .padding(.vertical, 4)

            if let result = match.result {
                Text(result.summary)
                    .font(.headline)
                    .foregroundStyle(result.outcome.tint)
                    .frame(maxWidth: .infinity)
            }
            Toggle("Match Completed", isOn: $match.isCompleted)
        }
    }

    private func scoreColumn(title: String, score: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(score)
                .font(.title2.bold().monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var ourInningsSection: some View {
        Section {
            ForEach(match.battingCard) { stats in
                Button { editingStats = stats } label: {
                    HStack {
                        Text("\(stats.battingPosition ?? 0).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stats.playerName)
                                .foregroundStyle(.primary)
                            Text(stats.dismissal?.label ?? "not out")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(stats.battingLine)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.listRow)
                .accessibilityElement(children: .combine)
            }
            if !notYetBatted.isEmpty {
                Menu {
                    ForEach(notYetBatted) { stats in
                        Button(stats.playerName) {
                            stats.battingPosition = match.nextBattingPosition
                            editingStats = stats
                        }
                    }
                } label: {
                    Label("Add Batter", systemImage: "plus.circle")
                }
            }
            CricketStatField(title: "Extras", value: $match.ourExtras)
            CricketOversField(title: "Overs Faced", balls: $match.ourBallsFaced, maxOvers: maxOvers)
        } header: {
            Text("Our Innings — \(match.ourScoreLine)")
        } footer: {
            Text("Total runs and wickets come from the batting card plus extras.")
        }
    }

    private var oppositionInningsSection: some View {
        Section("\(match.opponentName) Innings") {
            CricketStatField(title: "Runs", value: $match.theirRuns)
            CricketStatField(title: "Wickets", value: $match.theirWickets, range: 0...maxWickets)
            CricketOversField(title: "Overs Faced", balls: $match.theirBallsFaced, maxOvers: maxOvers)
        }
    }

    private var bowlingSection: some View {
        Section {
            ForEach(match.bowlingCard) { stats in
                Button { editingStats = stats } label: {
                    HStack {
                        Text(stats.playerName)
                            .foregroundStyle(.primary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(stats.bowlingLine)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.primary)
                            if let economy = stats.economy {
                                Text("Econ \(economy.cricketStatText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(.listRow)
                .accessibilityElement(children: .combine)
            }
            if !notYetBowled.isEmpty {
                Menu {
                    ForEach(notYetBowled) { stats in
                        Button(stats.playerName) { editingStats = stats }
                    }
                } label: {
                    Label("Add Bowler", systemImage: "plus.circle")
                }
            }
        } header: {
            Text("Our Bowling")
        } footer: {
            Text("Figures are overs-maidens-runs-wickets.")
        }
    }

    @ViewBuilder
    private var fieldingSection: some View {
        if !fielders.isEmpty {
            Section("Fielding") {
                ForEach(fielders) { stats in
                    Button { editingStats = stats } label: {
                        HStack {
                            Text(stats.playerName)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(fieldingSummary(stats))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.listRow)
                }
            }
        }
    }

    private var teamSection: some View {
        Section {
            ForEach(match.playerStats.sorted { $0.playerName < $1.playerName }) { stats in
                Button { editingStats = stats } label: {
                    HStack {
                        Text(stats.playerName)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.listRow)
            }
            .onDelete(perform: removePlayers)

            if !squadNotInMatch.isEmpty {
                Menu {
                    ForEach(squadNotInMatch) { player in
                        Button(player.displayName) { addPlayer(player) }
                    }
                } label: {
                    Label("Add Player", systemImage: "person.badge.plus")
                }
            }
        } header: {
            Text("Team (\(match.playerStats.count))")
        } footer: {
            Text("Tap a player to edit all of their batting, bowling and fielding stats.")
        }
    }

    private var detailsSection: some View {
        Section("Match Details") {
            TextField("Opponent", text: $match.opponentName)
            DatePicker("Date", selection: $match.date, displayedComponents: .date)
            TextField("Venue", text: $match.venue)
            Picker("Overs per Innings", selection: $match.oversPerInnings) {
                ForEach(CricketMatchSetupView.overOptions, id: \.self) { overs in
                    Text(overs == 0 ? "Unlimited" : "\(overs) overs").tag(overs)
                }
            }
            Toggle("We Batted First", isOn: $match.weBattedFirst)
        }
    }

    // MARK: - Actions

    private func fieldingSummary(_ stats: CricketPlayerStats) -> String {
        var parts: [String] = []
        if stats.catches > 0 { parts.append("\(stats.catches) ct") }
        if stats.runOuts > 0 { parts.append("\(stats.runOuts) ro") }
        if stats.stumpings > 0 { parts.append("\(stats.stumpings) st") }
        return parts.joined(separator: " · ")
    }

    private func addPlayer(_ player: SquadPlayer) {
        let line = CricketPlayerStats(match: match, playerID: player.playerID, playerName: player.name)
        modelContext.insert(line)
        match.playerStats.append(line)
    }

    private func removePlayers(at offsets: IndexSet) {
        let sorted = match.playerStats.sorted { $0.playerName < $1.playerName }
        for index in offsets {
            let line = sorted[index]
            match.playerStats.removeAll { $0.statsID == line.statsID }
            modelContext.delete(line)
        }
    }

    // MARK: - Export

    private var scorecardExport: CSVExportFile {
        var lines = ["Section,Player,Detail,Runs,Balls,4s,6s,SR,Overs,Maidens,Conceded,Wickets,Econ,Catches,Run Outs,Stumpings"]
        for stats in match.battingCard {
            lines.append([
                "Batting", stats.playerName, stats.dismissal?.label ?? "not out",
                "\(stats.runs)", "\(stats.ballsFaced)", "\(stats.fours)", "\(stats.sixes)",
                stats.strikeRate?.cricketStatText ?? "", "", "", "", "", "", "", "", ""
            ].map(RosterCSV.escape).joined(separator: ","))
        }
        for stats in match.bowlingCard {
            lines.append([
                "Bowling", stats.playerName, "", "", "", "", "", "",
                CricketOvers.format(balls: stats.ballsBowled), "\(stats.maidens)", "\(stats.runsConceded)", "\(stats.wicketsTaken)",
                stats.economy?.cricketStatText ?? "", "", "", ""
            ].map(RosterCSV.escape).joined(separator: ","))
        }
        for stats in fielders {
            lines.append([
                "Fielding", stats.playerName, "", "", "", "", "", "", "", "", "", "", "",
                "\(stats.catches)", "\(stats.runOuts)", "\(stats.stumpings)"
            ].map(RosterCSV.escape).joined(separator: ","))
        }
        lines.append("")
        lines.append(RosterCSV.escape("Us: \(match.ourScoreLine) (extras \(match.ourExtras))"))
        lines.append(RosterCSV.escape("\(match.opponentName): \(match.theirScoreLine)"))
        if let result = match.result {
            lines.append(RosterCSV.escape(result.summary))
        }
        if !match.notes.isEmpty {
            lines.append("")
            lines.append("Notes")
            lines.append(RosterCSV.escape(match.notes))
        }
        return CSVExportFile(
            filename: MatchExport.filename(prefix: "Cricket_Scorecard", opponentName: match.opponentName, ext: "csv"),
            content: lines.joined(separator: "\n")
        )
    }
}
