import SwiftUI
import SwiftData

/// Non-Basketball equivalent of `GameDetailView`. Reuses `ActionButton` and
/// `ManualClockView` (both sport-agnostic, defined alongside Basketball's
/// `GameDetailView`) unchanged. The scoreboard's "+" buttons open the
/// rules-driven `ScoreSheet` for both team and opponent instead of a
/// hardcoded 1/2/3 picker, and "Foul" becomes "Discipline", wired through
/// `DisciplineSheet` with sin-bin/send-off removal handled by `Fixture.logDiscipline`.
/// Scoreboard, clock, banners and notes are the shared `MatchComponents`.
struct FixtureDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPlayers: [SquadPlayer]

    @Bindable var fixture: Fixture

    @State private var showLineupSetup = false
    @State private var showSubstitution = false
    @State private var showAttendance = false
    @State private var showEventHistory = false
    @State private var showPlayingTime = false
    @State private var showDisciplineSheet = false
    @State private var showMVPPicker = false
    @State private var showAdvancePeriodConfirm = false
    @State private var showEndFixtureConfirm = false
    @State private var showTeamScoreSheet = false
    @State private var showOpponentScoreSheet = false

    private var sport: Sport { fixture.sportValue }
    private var rules: SportRules { sport.rules }

    init(fixture: Fixture) {
        self.fixture = fixture
        let raw = fixture.sport
        _allPlayers = Query(filter: #Predicate<SquadPlayer> { $0.sport == raw }, sort: \SquadPlayer.name)
    }

    var presentPlayers: [SquadPlayer] {
        let absentIDs = Set(fixture.attendances.filter { $0.isAbsent }.map { $0.playerID })
        return allPlayers.filter { !absentIDs.contains($0.playerID) }
    }

    var onFieldPlayers: [SquadPlayer] {
        let onField = Set(fixture.onFieldPlayerIDs)
        return allPlayers.filter { onField.contains($0.playerID.uuidString) }
    }

    /// Present players who haven't been sent off — the actual pool substitutions
    /// can draw from, matching `FixtureSubstitutionView.benchPlayers`'s filter.
    var eligiblePlayers: [SquadPlayer] {
        let sentOff = fixture.sentOffPlayerIDs
        return presentPlayers.filter { !sentOff.contains($0.playerID) }
    }

    /// True once the eligible pool is too small to leave anyone on the bench —
    /// covers both "exactly enough" and "short-handed" squads.
    var hasNoSubstitutesAvailable: Bool {
        !fixture.isEnded && eligiblePlayers.count <= rules.onFieldCount
    }

    var body: some View {
        let recentEvents = Array(fixture.events.sorted { $0.timestamp > $1.timestamp }.prefix(5))

        ScrollView {
            VStack(spacing: 16) {
                MatchScoreboard(
                    match: fixture,
                    tint: sport.tint,
                    onTeamMinus: { fixture.adjustScore(team: true, delta: -1, in: modelContext) },
                    onTeamPlus: { showTeamScoreSheet = true },
                    onOpponentMinus: { fixture.adjustScore(team: false, delta: -1, in: modelContext) },
                    onOpponentPlus: { showOpponentScoreSheet = true }
                )
                MatchClockSection(match: fixture) {
                    fixture.resetClock(in: modelContext)
                }
                if fixture.onFieldPlayerIDs.isEmpty && !fixture.isEnded {
                    LineupBanner(starterCount: rules.onFieldCount) { showLineupSetup = true }
                }
                if hasNoSubstitutesAvailable {
                    NoSubstitutesBanner(availableCount: eligiblePlayers.count, requiredCount: rules.onFieldCount)
                }
                actionsSection
                onFieldSection
                CoachingNotesSection(text: $fixture.notes)
                recentEventsSection(recentEvents)
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("vs \(fixture.opponentName)")
        .navigationBarTitleDisplayMode(.inline)
        .keepsScreenAwake(fixture.isGameDayModeActive && !fixture.isEnded)
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
                    if !fixture.isEnded {
                        Toggle(isOn: $fixture.isGameDayModeActive) {
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
            FixtureLineupView(fixture: fixture, players: presentPlayers)
        }
        .sheet(isPresented: $showSubstitution) {
            FixtureSubstitutionView(fixture: fixture, allPlayers: presentPlayers)
        }
        .sheet(isPresented: $showAttendance) {
            FixtureAttendanceView(fixture: fixture)
        }
        .navigationDestination(isPresented: $showEventHistory) {
            FixtureEventHistoryView(fixture: fixture)
        }
        .navigationDestination(isPresented: $showPlayingTime) {
            FixturePlayingTimeView(fixture: fixture)
        }
        .sheet(isPresented: $showDisciplineSheet) {
            DisciplineSheet(sport: sport, players: presentPlayers) { player, action in
                fixture.logDiscipline(action, player: player, in: modelContext)
            }
        }
        .sheet(isPresented: $showMVPPicker) {
            SquadPlayerPickerSheet(title: "MVP Vote", players: presentPlayers) { player in
                fixture.logEvent(.mvpVote, player: player, detail: "MVP Vote", in: modelContext)
            }
        }
        .sheet(isPresented: $showTeamScoreSheet) {
            ScoreSheet(sport: sport, title: "Team Score", players: onFieldPlayers.isEmpty ? presentPlayers : onFieldPlayers) { player, action in
                fixture.logScore(team: true, action: action, player: player, in: modelContext)
            }
        }
        .sheet(isPresented: $showOpponentScoreSheet) {
            ScoreSheet(sport: sport, title: "\(fixture.opponentName) Score", players: [], showScorer: false) { _, action in
                fixture.logScore(team: false, action: action, player: nil, in: modelContext)
            }
        }
        .confirmationDialog("Advance Period", isPresented: $showAdvancePeriodConfirm) {
            Button("Advance to \(fixture.periodLabel(forPeriod: fixture.currentPeriod + 1))") {
                fixture.advancePeriod(in: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(fixture.currentPeriod >= fixture.totalPeriods
                 ? "Regulation time is over. This starts an overtime period."
                 : "This will end the current period and start the next one.")
        }
        .confirmationDialog("End Fixture", isPresented: $showEndFixtureConfirm) {
            Button("End Fixture", role: .destructive) {
                fixture.endFixture(in: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Final score: \(fixture.teamScore) – \(fixture.opponentScore)")
        }
    }

    // MARK: - Actions Section

    var actionsSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 12)], spacing: 12) {
            if !fixture.isEnded {
                ActionButton(title: "Discipline", icon: "flag.fill", color: .red) {
                    showDisciplineSheet = true
                }
                ActionButton(title: "MVP Vote", icon: "star.fill", color: .yellow) {
                    showMVPPicker = true
                }
                ActionButton(title: "Sub", icon: "arrow.left.arrow.right", color: .purple, isDisabled: hasNoSubstitutesAvailable) {
                    showSubstitution = true
                }
                ActionButton(title: fixture.currentPeriod >= fixture.totalPeriods ? "Overtime" : "Next Period", icon: "forward.end.fill", color: .blue) {
                    showAdvancePeriodConfirm = true
                }
                ActionButton(title: "End Fixture", icon: "flag.checkered", color: .gray) {
                    showEndFixtureConfirm = true
                }
            }
        }
    }

    // MARK: - On Field Section

    @ViewBuilder
    var onFieldSection: some View {
        if !onFieldPlayers.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(rules.onFieldTerm)
                        .font(.headline)
                    Spacer()
                    if !fixture.isEnded {
                        Button("Lineup") { showLineupSetup = true }
                            .font(.caption)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                    ForEach(onFieldPlayers) { player in
                        HStack {
                            Image(systemName: rules.systemImage)
                                .foregroundStyle(sport.tint)
                                .accessibilityHidden(true)
                            Text(player.displayName)
                                .font(.subheadline)
                                .lineLimit(1)
                            if let position = fixture.position(for: player.playerID) {
                                Text(position.code)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel(position.name)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(sport.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Recent Events Section

    func recentEventsSection(_ events: [FixtureEvent]) -> some View {
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
                    FixtureEventRowView(event: event, sport: sport)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Exports

    private var exportPrefix: String {
        MatchExport.safeFilenameComponent(sport.rules.displayName)
    }

    private var eventsExport: CSVExportFile {
        let rows = fixture.events.sorted { $0.timestamp < $1.timestamp }.map { event in
            MatchExport.EventRow(
                period: fixture.shortPeriodLabel(forPeriod: event.periodNumber),
                time: formatClock(event.elapsedSeconds),
                event: event.displayName(opponentName: fixture.opponentName),
                player: event.playerName,
                detail: event.detail
            )
        }
        return CSVExportFile(
            filename: MatchExport.filename(prefix: "\(exportPrefix)_Events", opponentName: fixture.opponentName, ext: "csv"),
            content: MatchExport.eventsCSV(rows: rows, notes: fixture.notes)
        )
    }

    private var notesExport: TextExportFile {
        TextExportFile(
            filename: MatchExport.filename(prefix: "\(exportPrefix)_Notes", opponentName: fixture.opponentName, ext: "txt"),
            content: MatchExport.notesText(title: "Fixture Notes", opponentName: fixture.opponentName, date: fixture.date, notes: fixture.notes)
        )
    }
}

// MARK: - Supporting Views

struct FixtureEventRowView: View {
    let event: FixtureEvent
    let sport: Sport

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.symbolName(for: sport))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.displayName(opponentName: event.fixture?.opponentName ?? ""))
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
            Text(event.fixture?.shortPeriodLabel(forPeriod: event.periodNumber) ?? "\(event.periodNumber)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct SquadPlayerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let players: [SquadPlayer]
    let onSelect: (SquadPlayer) -> Void

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
