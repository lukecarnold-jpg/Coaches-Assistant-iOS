import SwiftUI
import SwiftData

struct GameDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Player.name) private var allPlayers: [Player]

    @Bindable var game: Game

    @State private var showLineupSetup = false
    @State private var showSubstitution = false
    @State private var showAttendance = false
    @State private var showEventHistory = false
    @State private var showPlayingTime = false
    @State private var showFoulPicker = false
    @State private var showMVPPicker = false
    @State private var showAdvancePeriodConfirm = false
    @State private var showEndGameConfirm = false
    @State private var showTeamScoreSheet = false
    @State private var showOpponentScoreSheet = false

    private let requiredOnCourtCount = Game.requiredOnCourtCount

    var presentPlayers: [Player] {
        let absentIDs = Set(game.attendances.filter { $0.isAbsent }.map { $0.playerID })
        return allPlayers.filter { !absentIDs.contains($0.playerID) }
    }

    var onCourtPlayers: [Player] {
        let onCourt = Set(game.onCourtPlayerIDs)
        return allPlayers.filter { onCourt.contains($0.playerID.uuidString) }
    }

    /// True once the present roster is too small to leave anyone on the bench —
    /// covers both "exactly enough" and "short-handed" squads.
    var hasNoSubstitutesAvailable: Bool {
        !game.isEnded && presentPlayers.count <= requiredOnCourtCount
    }

    var body: some View {
        let recentEvents = Array(game.events.sorted { $0.timestamp > $1.timestamp }.prefix(5))

        ScrollView {
            VStack(spacing: 16) {
                MatchScoreboard(
                    match: game,
                    tint: .blue,
                    onTeamMinus: { game.adjustScore(team: true, delta: -1, in: modelContext) },
                    onTeamPlus: { showTeamScoreSheet = true },
                    onOpponentMinus: { game.adjustScore(team: false, delta: -1, in: modelContext) },
                    onOpponentPlus: { showOpponentScoreSheet = true }
                )
                MatchClockSection(match: game) {
                    game.resetClock(in: modelContext)
                }
                if game.onCourtPlayerIDs.isEmpty && !game.isEnded {
                    LineupBanner(starterCount: requiredOnCourtCount) { showLineupSetup = true }
                }
                if hasNoSubstitutesAvailable {
                    NoSubstitutesBanner(availableCount: presentPlayers.count, requiredCount: requiredOnCourtCount)
                }
                actionsSection
                onCourtSection
                CoachingNotesSection(text: $game.notes)
                recentEventsSection(recentEvents)
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("vs \(game.opponentName)")
        .navigationBarTitleDisplayMode(.inline)
        .keepsScreenAwake(game.isGameDayModeActive && !game.isEnded)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showAttendance = true } label: {
                        Label("Attendance", systemImage: "person.badge.clock")
                    }
                    Button { showEventHistory = true } label: {
                        Label("Event History", systemImage: "list.bullet.clipboard")
                    }
                    Button { showPlayingTime = true } label: {
                        Label("Playing Time", systemImage: "stopwatch")
                    }
                    if !game.isEnded {
                        Toggle(isOn: $game.isGameDayModeActive) {
                            Label("Game Day Mode", systemImage: "sun.max")
                        }
                    }
                    Divider()
                    ShareLink(item: eventsExport, preview: SharePreview(eventsExport.filename, image: Image(systemName: "tablecells"))) {
                        Label("Export Events CSV", systemImage: "tablecells")
                    }
                    ShareLink(item: notesExport, preview: SharePreview(notesExport.filename, image: Image(systemName: "doc.text"))) {
                        Label("Export Notes TXT", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More options")
            }
        }
        .sheet(isPresented: $showLineupSetup) {
            LineupSetupView(game: game, players: presentPlayers)
        }
        .sheet(isPresented: $showSubstitution) {
            SubstitutionView(game: game, allPlayers: presentPlayers)
        }
        .sheet(isPresented: $showAttendance) {
            AttendanceView(game: game)
        }
        .navigationDestination(isPresented: $showEventHistory) {
            EventHistoryView(game: game)
        }
        .navigationDestination(isPresented: $showPlayingTime) {
            PlayingTimeView(game: game)
        }
        .sheet(isPresented: $showFoulPicker) {
            PlayerPickerSheet(title: "Log Foul", players: presentPlayers) { player in
                game.logEvent(.foul, player: player, detail: "Foul", in: modelContext)
            }
        }
        .sheet(isPresented: $showMVPPicker) {
            PlayerPickerSheet(title: "MVP Vote", players: presentPlayers) { player in
                game.logEvent(.mvpVote, player: player, detail: "MVP Vote", in: modelContext)
            }
        }
        .sheet(isPresented: $showTeamScoreSheet) {
            TeamScoreSheet(title: "Team Score", players: onCourtPlayers.isEmpty ? presentPlayers : onCourtPlayers) { player, points in
                game.logTeamScore(points: points, player: player, in: modelContext)
            }
        }
        .sheet(isPresented: $showOpponentScoreSheet) {
            TeamScoreSheet(title: "\(game.opponentName) Score", players: [], showScorer: false) { _, points in
                game.adjustScore(team: false, delta: points, in: modelContext)
            }
        }
        .confirmationDialog("Advance Period", isPresented: $showAdvancePeriodConfirm) {
            Button("Advance to \(game.periodLabel(forPeriod: game.currentPeriod + 1))") {
                game.advancePeriod(in: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(game.currentPeriod >= game.totalPeriods
                 ? "Regulation time is over. This starts an overtime period."
                 : "This will end the current period and start the next one.")
        }
        .confirmationDialog("End Game", isPresented: $showEndGameConfirm) {
            Button("End Game", role: .destructive) {
                game.endGame(in: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Final score: \(game.teamScore) – \(game.opponentScore)")
        }
    }

    // MARK: - Actions Section

    var actionsSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 12)], spacing: 12) {
            if !game.isEnded {
                ActionButton(title: "Foul", icon: "hand.raised.fill", color: .red) {
                    showFoulPicker = true
                }
                ActionButton(title: "MVP Vote", icon: "star.fill", color: .yellow) {
                    showMVPPicker = true
                }
                ActionButton(title: "Sub", icon: "arrow.left.arrow.right", color: .purple, isDisabled: hasNoSubstitutesAvailable) {
                    showSubstitution = true
                }
                ActionButton(title: game.currentPeriod >= game.totalPeriods ? "Overtime" : "Next Period", icon: "forward.end.fill", color: .blue) {
                    showAdvancePeriodConfirm = true
                }
                ActionButton(title: "End Game", icon: "flag.checkered", color: .gray) {
                    showEndGameConfirm = true
                }
            }
        }
    }

    // MARK: - On Court Section

    @ViewBuilder
    var onCourtSection: some View {
        if !onCourtPlayers.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("On Court")
                        .font(.headline)
                    Spacer()
                    if !game.isEnded {
                        Button("Lineup") { showLineupSetup = true }
                            .font(.caption)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                    ForEach(onCourtPlayers) { player in
                        HStack {
                            Image(systemName: "figure.basketball")
                                .foregroundStyle(.blue)
                                .accessibilityHidden(true)
                            Text(player.displayName)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Recent Events Section

    func recentEventsSection(_ events: [GameEvent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Events")
                    .font(.headline)
                Spacer()
                Button("See All") { showEventHistory = true }
                    .font(.caption)
            }
            if events.isEmpty {
                Text("No events yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(events) { event in
                    EventRowView(event: event)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Exports

    private var eventsExport: CSVExportFile {
        let rows = game.events.sorted { $0.timestamp < $1.timestamp }.map { event in
            MatchExport.EventRow(
                period: game.shortPeriodLabel(forPeriod: event.periodNumber),
                time: formatClock(event.elapsedSeconds),
                event: event.displayName(opponentName: game.opponentName),
                player: event.playerName,
                detail: event.detail
            )
        }
        return CSVExportFile(
            filename: MatchExport.filename(prefix: "Game_Events", opponentName: game.opponentName, ext: "csv"),
            content: MatchExport.eventsCSV(rows: rows, notes: game.notes)
        )
    }

    private var notesExport: TextExportFile {
        TextExportFile(
            filename: MatchExport.filename(prefix: "Game_Notes", opponentName: game.opponentName, ext: "txt"),
            content: MatchExport.notesText(title: "Game Notes", opponentName: game.opponentName, date: game.date, notes: game.notes)
        )
    }
}

// MARK: - Supporting Views

struct EventRowView: View {
    let event: GameEvent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.eventKind.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.displayName(opponentName: event.game?.opponentName ?? ""))
                        .font(.caption.bold())
                    if !event.playerName.isEmpty {
                        Text("· \(event.playerName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(event.game?.shortPeriodLabel(forPeriod: event.periodNumber) ?? "\(event.periodNumber)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct PlayerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let players: [Player]
    let onSelect: (Player) -> Void

    var body: some View {
        NavigationStack {
            List(players) { player in
                Button {
                    onSelect(player)
                    dismiss()
                } label: {
                    Text(player.displayName)
                        .foregroundStyle(.primary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// Basketball points picker (1/2/3), used for both teams. The scorer list is
/// hidden for the opponent, whose roster we don't track.
struct TeamScoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let players: [Player]
    var showScorer: Bool = true
    let onConfirm: (Player?, Int) -> Void

    @State private var selectedPlayer: Player?
    @State private var points = 2

    var body: some View {
        NavigationStack {
            Form {
                Section("Points Scored") {
                    Picker("Points", selection: $points) {
                        Text("1 pt  (Free Throw)").tag(1)
                        Text("2 pts").tag(2)
                        Text("3 pts").tag(3)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if showScorer {
                    Section {
                        if players.isEmpty {
                            Text("No players available — set lineup first.")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(players) { player in
                                Button {
                                    selectedPlayer = selectedPlayer?.playerID == player.playerID ? nil : player
                                } label: {
                                    HStack {
                                        Text(player.displayName)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedPlayer?.playerID == player.playerID {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                                .accessibilityAddTraits(selectedPlayer?.playerID == player.playerID ? .isSelected : [])
                            }
                        }
                    } header: {
                        Text("Scorer (Optional)")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log +\(points)") {
                        onConfirm(selectedPlayer, points)
                        dismiss()
                    }
                }
            }
        }
    }
}
