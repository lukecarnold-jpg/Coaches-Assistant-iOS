import SwiftUI
import SwiftData

/// Non-Basketball equivalent of `GameDetailView`. Reuses `ActionButton` and
/// `ManualClockView` (both sport-agnostic, defined alongside Basketball's
/// `GameDetailView`) unchanged. The scoreboard's "+" buttons open the
/// rules-driven `ScoreSheet` for both team and opponent instead of a
/// hardcoded 1/2/3 picker, and "Foul" becomes "Discipline", wired through
/// `DisciplineSheet` with sin-bin/send-off removal handled inline.
struct FixtureDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var allPlayers: [SquadPlayer]

    @Bindable var fixture: Fixture

    @State private var showLineupSetup = false
    @State private var showSubstitution = false
    @State private var showAttendance = false
    @State private var showEventHistory = false
    @State private var showPlayingTime = false
    @State private var showDisciplineSheet = false
    @State private var showMVPPicker = false
    @State private var showManualClock = false
    @State private var showAdvancePeriodConfirm = false
    @State private var showEndFixtureConfirm = false
    @State private var manualMinutes = ""
    @State private var manualSeconds = ""
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
        allPlayers.filter { fixture.onFieldPlayerIDs.contains($0.playerID.uuidString) }
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

    var noSubstitutesMessage: String {
        if eligiblePlayers.count < rules.onFieldCount {
            return "Only \(eligiblePlayers.count) of \(rules.onFieldCount) players available — no bench to substitute from."
        }
        return "Exactly \(rules.onFieldCount) players available — no bench to substitute from."
    }

    var sortedEvents: [FixtureEvent] {
        fixture.events.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                scoreBoard
                clockSection
                if fixture.onFieldPlayerIDs.isEmpty && !fixture.isEnded {
                    lineupBanner
                }
                if hasNoSubstitutesAvailable {
                    noSubstitutesBanner
                }
                actionsSection
                onFieldSection
                notesSection
                recentEventsSection
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("vs \(fixture.opponentName)")
        .navigationBarTitleDisplayMode(.inline)
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
                    Divider()
                    if let csvURL = generateFixtureCSVURL() {
                        ShareLink(item: csvURL, preview: SharePreview(csvURL.lastPathComponent, image: Image(systemName: "tablecells"))) {
                            Label("Export Events CSV", systemImage: "tablecells")
                        }
                    }
                    if let txtURL = generateNotesTXTURL() {
                        ShareLink(item: txtURL, preview: SharePreview(txtURL.lastPathComponent, image: Image(systemName: "doc.text"))) {
                            Label("Export Notes TXT", systemImage: "doc.text")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
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
                logDiscipline(player: player, action: action)
            }
        }
        .sheet(isPresented: $showMVPPicker) {
            SquadPlayerPickerSheet(title: "MVP Vote", players: presentPlayers) { player in
                logEvent(type: .mvpVote, player: player, detail: "MVP Vote")
            }
        }
        .sheet(isPresented: $showManualClock) {
            ManualClockView(minutes: $manualMinutes, seconds: $manualSeconds) {
                applyManualTime()
            }
        }
        .sheet(isPresented: $showTeamScoreSheet) {
            ScoreSheet(sport: sport, title: "Team Score", players: onFieldPlayers.isEmpty ? presentPlayers : onFieldPlayers) { player, action in
                logTeamScore(player: player, action: action)
            }
        }
        .sheet(isPresented: $showOpponentScoreSheet) {
            ScoreSheet(sport: sport, title: "\(fixture.opponentName) Score", players: [], showScorer: false) { _, action in
                logOpponentScore(action: action)
            }
        }
        .confirmationDialog("Advance Period", isPresented: $showAdvancePeriodConfirm) {
            Button("Advance to \(nextPeriodLabel())") {
                advancePeriod()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will end the current period and start the next one.")
        }
        .confirmationDialog("End Fixture", isPresented: $showEndFixtureConfirm) {
            Button("End Fixture", role: .destructive) {
                endFixture()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Final score: \(fixture.teamScore) – \(fixture.opponentScore)")
        }
    }

    // MARK: - Score Board

    var scoreBoard: some View {
        VStack(spacing: 8) {
            HStack {
                Text(fixture.isEnded ? "Final" : fixture.periodLabel)
                    .font(.caption.bold())
                    .foregroundStyle(fixture.isEnded ? Color.gray : sport.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(fixture.isEnded ? Color.gray.opacity(0.15) : sport.tint.opacity(0.1), in: Capsule())
            }

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("US")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(fixture.teamScore)")
                        .font(.system(size: horizontalSizeClass == .compact ? 46 : 58, weight: .bold, design: .rounded))
                    if !fixture.isEnded {
                        HStack(spacing: 8) {
                            Button { adjustScore(team: true, delta: -1) } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            Button { showTeamScoreSheet = true } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(sport.tint)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Text("–")
                    .font(.title)
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Text(fixture.opponentName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(fixture.opponentScore)")
                        .font(.system(size: horizontalSizeClass == .compact ? 46 : 58, weight: .bold, design: .rounded))
                    if !fixture.isEnded {
                        HStack(spacing: 8) {
                            Button { adjustScore(team: false, delta: -1) } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            Button { showOpponentScoreSheet = true } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Clock Section

    var clockSection: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            let elapsed = fixture.currentElapsedSeconds()
            let remaining = fixture.remainingSeconds(at: elapsed)
            VStack(spacing: 8) {
                HStack {
                    VStack {
                        Text(formatTime(remaining))
                            .font(.system(size: horizontalSizeClass == .compact ? 30 : 40, weight: .bold, design: .monospaced))
                        Text("Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: horizontalSizeClass == .compact ? 42 : 56)

                    VStack {
                        Text(formatTime(elapsed))
                            .font(.system(size: horizontalSizeClass == .compact ? 30 : 40, weight: .bold, design: .monospaced))
                        Text("Elapsed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                if !fixture.isEnded {
                    HStack(spacing: 16) {
                        Button {
                            toggleClock()
                        } label: {
                            Label(fixture.clockIsRunning ? "Stop" : "Start", systemImage: fixture.clockIsRunning ? "stop.fill" : "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(fixture.clockIsRunning ? .red : .green)

                        Button {
                            resetClock()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title2)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            prepareManualClock(elapsed: elapsed)
                            showManualClock = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.title2)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Lineup Banner

    var lineupBanner: some View {
        Button { showLineupSetup = true } label: {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text("Set Starting Lineup")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Tap to select your \(rules.onFieldCount) starters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - No Substitutes Banner

    var noSubstitutesBanner: some View {
        HStack {
            Image(systemName: "person.2.slash.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading) {
                Text(eligiblePlayers.count < rules.onFieldCount ? "Playing Short-Handed" : "No Substitutes Available")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(noSubstitutesMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
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
                if fixture.currentPeriod < fixture.totalPeriods {
                    ActionButton(title: "Next Period", icon: "forward.end.fill", color: .blue) {
                        showAdvancePeriodConfirm = true
                    }
                }
                ActionButton(title: "End Fixture", icon: "flag.checkered", color: .gray) {
                    showEndFixtureConfirm = true
                }
            }
        }
    }

    // MARK: - On Field Section

    var onFieldSection: some View {
        Group {
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
                                Text(player.displayName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                if let position = fixture.position(for: player.playerID) {
                                    Text(position.code)
                                        .font(.caption2.bold())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(sport.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Notes Section

    var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coaching Notes")
                .font(.headline)
            TextEditor(text: $fixture.notes)
                .frame(minHeight: horizontalSizeClass == .compact ? 80 : 120)
                .padding(4)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recent Events Section

    var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Events")
                    .font(.headline)
                Spacer()
                Button("See All") { showEventHistory = true }
                    .font(.caption)
            }
            if sortedEvents.isEmpty {
                Text("No events yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(sortedEvents.prefix(5)) { event in
                    FixtureEventRowView(event: event, sport: sport)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions

    private func logTeamScore(player: SquadPlayer?, action: ScoringAction) {
        fixture.teamScore += action.points
        logEvent(type: .teamScore, player: player, detail: action.label, actionCode: action.code, scoreDelta: action.points)
    }

    private func logOpponentScore(action: ScoringAction) {
        fixture.opponentScore += action.points
        logEvent(type: .opponentScore, player: nil, detail: action.label, actionCode: action.code, scoreDelta: action.points)
    }

    /// Sin bin / send off: log the discipline event, then — if the player is on
    /// the field — remove them and log a paired `.substitutionOut` at the same
    /// time. `Fixture.minutesPlayedSeconds()` needs no special case as a result.
    private func logDiscipline(player: SquadPlayer?, action: DisciplineAction) {
        let elapsed = fixture.currentElapsedSeconds()
        let event = FixtureEvent(
            fixture: fixture,
            eventType: .discipline,
            actionCode: action.code,
            playerID: player?.playerID,
            playerName: player?.name ?? "",
            detail: action.label,
            periodNumber: fixture.currentPeriod,
            elapsedSeconds: elapsed
        )
        modelContext.insert(event)
        fixture.events.append(event)

        guard let player, action.removal != .none, fixture.onFieldPlayerIDs.contains(player.playerID.uuidString) else { return }

        fixture.onFieldPlayerIDs.removeAll { $0 == player.playerID.uuidString }
        let subOut = FixtureEvent(
            fixture: fixture,
            eventType: .substitutionOut,
            playerID: player.playerID,
            playerName: player.name,
            detail: "Off — \(action.label)",
            periodNumber: fixture.currentPeriod,
            elapsedSeconds: elapsed
        )
        modelContext.insert(subOut)
        fixture.events.append(subOut)
    }

    private func adjustScore(team: Bool, delta: Int) {
        let previous = team ? fixture.teamScore : fixture.opponentScore
        let clamped = max(0, previous + delta)
        let appliedDelta = clamped - previous
        if team {
            fixture.teamScore = clamped
            logEvent(type: .teamScore, player: nil, detail: appliedDelta > 0 ? "+\(appliedDelta)" : "\(appliedDelta)", scoreDelta: appliedDelta)
        } else {
            fixture.opponentScore = clamped
            logEvent(type: .opponentScore, player: nil, detail: appliedDelta > 0 ? "+\(appliedDelta)" : "\(appliedDelta)", scoreDelta: appliedDelta)
        }
    }

    private func toggleClock() {
        if fixture.clockIsRunning {
            fixture.elapsedSeconds = fixture.currentElapsedSeconds()
            fixture.clockIsRunning = false
            fixture.clockStartedAt = nil
        } else {
            fixture.clockIsRunning = true
            fixture.clockStartedAt = Date()
        }
    }

    private func resetClock() {
        fixture.elapsedSeconds = 0
        fixture.clockIsRunning = false
        fixture.clockStartedAt = nil
    }

    private func prepareManualClock(elapsed: Int) {
        let remaining = fixture.remainingSeconds(at: elapsed)
        manualMinutes = String(remaining / 60)
        manualSeconds = String(remaining % 60)
    }

    private func applyManualTime() {
        let mins = Int(manualMinutes) ?? 0
        let secs = Int(manualSeconds) ?? 0
        let remainingTarget = mins * 60 + secs
        let newElapsed = max(0, fixture.periodLengthSeconds - remainingTarget)
        fixture.elapsedSeconds = newElapsed
        fixture.clockIsRunning = false
        fixture.clockStartedAt = nil
    }

    private func advancePeriod() {
        stopClock()
        let event = FixtureEvent(fixture: fixture, eventType: .periodAdvance, detail: "End of \(fixture.periodLabel)", periodNumber: fixture.currentPeriod, elapsedSeconds: fixture.elapsedSeconds)
        modelContext.insert(event)
        fixture.events.append(event)
        fixture.currentPeriod += 1
        fixture.elapsedSeconds = 0
    }

    private func endFixture() {
        stopClock()
        fixture.isEnded = true
        fixture.isGameDayModeActive = false
        let event = FixtureEvent(fixture: fixture, eventType: .fixtureEnd, detail: "Final: \(fixture.teamScore) – \(fixture.opponentScore)", periodNumber: fixture.currentPeriod, elapsedSeconds: fixture.elapsedSeconds)
        modelContext.insert(event)
        fixture.events.append(event)
    }

    private func stopClock() {
        if fixture.clockIsRunning {
            fixture.elapsedSeconds = fixture.currentElapsedSeconds()
            fixture.clockIsRunning = false
            fixture.clockStartedAt = nil
        }
    }

    private func logEvent(type: FixtureEventType, player: SquadPlayer?, detail: String, actionCode: String = "", scoreDelta: Int = 0) {
        let event = FixtureEvent(
            fixture: fixture,
            eventType: type,
            actionCode: actionCode,
            playerID: player?.playerID,
            playerName: player?.name ?? "",
            detail: detail,
            periodNumber: fixture.currentPeriod,
            elapsedSeconds: fixture.currentElapsedSeconds(),
            scoreDelta: scoreDelta
        )
        modelContext.insert(event)
        fixture.events.append(event)
    }

    private func nextPeriodLabel() -> String {
        fixture.periodLabel(forPeriod: fixture.currentPeriod + 1)
    }

    private func generateFixtureCSVURL() -> URL? {
        var lines = ["Period,Time,Event,Player,Detail"]
        for event in fixture.events.sorted(by: { $0.timestamp < $1.timestamp }) {
            let time = formatTime(event.elapsedSeconds)
            let player = event.playerName.isEmpty ? "" : event.playerName
            let detail = event.detail.replacingOccurrences(of: ",", with: " ")
            let eventName = event.displayName(opponentName: fixture.opponentName)
            lines.append("\(event.periodNumber),\(time),\(eventName),\(player),\(detail)")
        }
        if !fixture.notes.isEmpty {
            lines.append("")
            lines.append("Coaching Notes")
            lines.append(fixture.notes.replacingOccurrences(of: "\n", with: " "))
        }
        let content = lines.joined(separator: "\n")
        let safeSport = sport.rules.displayName.replacingOccurrences(of: " ", with: "_")
        let safeOpponent = fixture.opponentName.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "[^a-zA-Z0-9_\\-]", with: "_", options: .regularExpression)
        let filename = safeOpponent.isEmpty ? "\(safeSport)_Events.csv" : "\(safeSport)_Events_vs_\(safeOpponent).csv"
        return RosterCSV.createTemporaryFile(filename: filename, content: content)
    }

    private func generateNotesTXTURL() -> URL? {
        let header = "Fixture Notes – vs \(fixture.opponentName) – \(fixture.date.formatted(date: .long, time: .omitted))\n\n"
        let content = header + (fixture.notes.isEmpty ? "No notes." : fixture.notes)
        let safeSport = sport.rules.displayName.replacingOccurrences(of: " ", with: "_")
        let safeOpponent = fixture.opponentName.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "[^a-zA-Z0-9_\\-]", with: "_", options: .regularExpression)
        let filename = safeOpponent.isEmpty ? "\(safeSport)_Notes.txt" : "\(safeSport)_Notes_vs_\(safeOpponent).txt"
        return RosterCSV.createTemporaryFile(filename: filename, content: content)
    }

    func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
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
            Text("P\(event.periodNumber)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
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
