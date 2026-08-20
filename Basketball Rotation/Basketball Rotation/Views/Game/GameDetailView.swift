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
    @State private var showFoulPicker = false
    @State private var showMVPPicker = false
    @State private var showManualClock = false
    @State private var showAdvancePeriodConfirm = false
    @State private var showEndGameConfirm = false
    @State private var showExportOptions = false
    @State private var exportContent = ""
    @State private var showShareSheet = false
    @State private var manualMinutes = ""
    @State private var manualSeconds = ""

    var presentPlayers: [Player] {
        let absentIDs = Set(game.attendances.filter { $0.isAbsent }.map { $0.playerID })
        return allPlayers.filter { !absentIDs.contains($0.playerID) }
    }

    var onCourtPlayers: [Player] {
        allPlayers.filter { game.onCourtPlayerIDs.contains($0.playerID) }
    }

    var sortedEvents: [GameEvent] {
        game.events.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                scoreBoard
                clockSection
                if game.onCourtPlayerIDs.isEmpty && !game.isEnded {
                    lineupBanner
                }
                actionsSection
                onCourtSection
                notesSection
                recentEventsSection
            }
            .padding()
        }
        .navigationTitle("vs \(game.opponentName)")
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
                    Divider()
                    Button { exportGameCSV() } label: {
                        Label("Export Events CSV", systemImage: "tablecells")
                    }
                    Button { exportNotesTXT() } label: {
                        Label("Export Notes TXT", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
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
        .sheet(isPresented: $showFoulPicker) {
            PlayerPickerSheet(title: "Log Foul", players: presentPlayers) { player in
                logEvent(type: .foul, player: player, detail: "Foul")
            }
        }
        .sheet(isPresented: $showMVPPicker) {
            PlayerPickerSheet(title: "MVP Vote", players: presentPlayers) { player in
                logEvent(type: .mvpVote, player: player, detail: "MVP Vote")
            }
        }
        .sheet(isPresented: $showManualClock) {
            ManualClockView(minutes: $manualMinutes, seconds: $manualSeconds) {
                applyManualTime()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [exportContent])
        }
        .confirmationDialog("Advance Period", isPresented: $showAdvancePeriodConfirm) {
            Button("Advance to \(nextPeriodLabel())") {
                advancePeriod()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will end the current period and start the next one.")
        }
        .confirmationDialog("End Game", isPresented: $showEndGameConfirm) {
            Button("End Game", role: .destructive) {
                endGame()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Final score: \(game.teamScore) – \(game.opponentScore)")
        }
    }

    // MARK: - Score Board

    var scoreBoard: some View {
        VStack(spacing: 8) {
            HStack {
                Text(game.isEnded ? "Final" : game.periodLabel)
                    .font(.caption.bold())
                    .foregroundStyle(game.isEnded ? .secondary : .blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(game.isEnded ? .secondary.opacity(0.15) : .blue.opacity(0.1), in: Capsule())
            }

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("US")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(game.teamScore)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                    if !game.isEnded {
                        HStack(spacing: 8) {
                            Button { adjustScore(team: true, delta: -1) } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            Button { adjustScore(team: true, delta: 1) } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Text("–")
                    .font(.title)
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Text(game.opponentName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(game.opponentScore)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                    if !game.isEnded {
                        HStack(spacing: 8) {
                            Button { adjustScore(team: false, delta: -1) } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            Button { adjustScore(team: false, delta: 1) } label: {
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
            let elapsed = game.currentElapsedSeconds()
            let remaining = game.remainingSeconds(at: elapsed)
            VStack(spacing: 8) {
                HStack {
                    VStack {
                        Text(formatTime(remaining))
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                        Text("Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 50)

                    VStack {
                        Text(formatTime(elapsed))
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                        Text("Elapsed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                if !game.isEnded {
                    HStack(spacing: 16) {
                        Button {
                            toggleClock()
                        } label: {
                            Label(game.clockIsRunning ? "Stop" : "Start", systemImage: game.clockIsRunning ? "stop.fill" : "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(game.clockIsRunning ? .red : .green)

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
                    Text("Tap to select your 5 starters")
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

    // MARK: - Actions Section

    var actionsSection: some View {
        VStack(spacing: 12) {
            if !game.isEnded {
                HStack(spacing: 12) {
                    ActionButton(title: "Foul", icon: "hand.raised.fill", color: .red) {
                        showFoulPicker = true
                    }
                    ActionButton(title: "MVP Vote", icon: "star.fill", color: .yellow) {
                        showMVPPicker = true
                    }
                    ActionButton(title: "Sub", icon: "arrow.left.arrow.right", color: .purple) {
                        showSubstitution = true
                    }
                }

                HStack(spacing: 12) {
                    if game.currentPeriod < game.totalPeriods {
                        ActionButton(title: "Next Period", icon: "forward.end.fill", color: .blue) {
                            showAdvancePeriodConfirm = true
                        }
                    }
                    ActionButton(title: game.currentPeriod >= game.totalPeriods ? "End Game" : "End Game", icon: "flag.checkered", color: .gray) {
                        showEndGameConfirm = true
                    }
                }
            }
        }
    }

    // MARK: - On Court Section

    var onCourtSection: some View {
        Group {
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
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(onCourtPlayers) { player in
                            HStack {
                                Image(systemName: "figure.basketball")
                                    .foregroundStyle(.blue)
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
    }

    // MARK: - Notes Section

    var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coaching Notes")
                .font(.headline)
            TextEditor(text: $game.notes)
                .frame(minHeight: 80)
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
                    EventRowView(event: event)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions

    private func adjustScore(team: Bool, delta: Int) {
        if team {
            game.teamScore = max(0, game.teamScore + delta)
            logEvent(type: delta > 0 ? .teamScore : .teamScore, player: nil, detail: delta > 0 ? "+\(delta)" : "\(delta)")
        } else {
            game.opponentScore = max(0, game.opponentScore + delta)
            logEvent(type: .opponentScore, player: nil, detail: delta > 0 ? "+\(delta)" : "\(delta)")
        }
    }

    private func toggleClock() {
        if game.clockIsRunning {
            game.elapsedSeconds = game.currentElapsedSeconds()
            game.clockIsRunning = false
            game.clockStartedAt = nil
        } else {
            game.clockIsRunning = true
            game.clockStartedAt = Date()
        }
    }

    private func resetClock() {
        game.elapsedSeconds = 0
        game.clockIsRunning = false
        game.clockStartedAt = nil
    }

    private func prepareManualClock(elapsed: Int) {
        let remaining = game.remainingSeconds(at: elapsed)
        manualMinutes = String(remaining / 60)
        manualSeconds = String(remaining % 60)
    }

    private func applyManualTime() {
        let mins = Int(manualMinutes) ?? 0
        let secs = Int(manualSeconds) ?? 0
        let remainingTarget = mins * 60 + secs
        let newElapsed = max(0, game.periodLengthSeconds - remainingTarget)
        game.elapsedSeconds = newElapsed
        game.clockIsRunning = false
        game.clockStartedAt = nil
    }

    private func advancePeriod() {
        stopClock()
        let event = GameEvent(game: game, eventType: .periodAdvance, detail: "End of \(game.periodLabel)", periodNumber: game.currentPeriod, elapsedSeconds: game.elapsedSeconds)
        modelContext.insert(event)
        game.events.append(event)
        game.currentPeriod += 1
        game.elapsedSeconds = 0
    }

    private func endGame() {
        stopClock()
        game.isEnded = true
        let event = GameEvent(game: game, eventType: .gameEnd, detail: "Final: \(game.teamScore) – \(game.opponentScore)", periodNumber: game.currentPeriod, elapsedSeconds: game.elapsedSeconds)
        modelContext.insert(event)
        game.events.append(event)
    }

    private func stopClock() {
        if game.clockIsRunning {
            game.elapsedSeconds = game.currentElapsedSeconds()
            game.clockIsRunning = false
            game.clockStartedAt = nil
        }
    }

    private func logEvent(type: GameEventType, player: Player?, detail: String) {
        let event = GameEvent(
            game: game,
            eventType: type,
            playerID: player?.playerID,
            playerName: player?.name ?? "",
            detail: detail,
            periodNumber: game.currentPeriod,
            elapsedSeconds: game.currentElapsedSeconds()
        )
        modelContext.insert(event)
        game.events.append(event)
    }

    private func nextPeriodLabel() -> String {
        let next = game.currentPeriod + 1
        if game.periodFormat == "quarters" {
            switch next {
            case 2: return "2nd Quarter"
            case 3: return "3rd Quarter"
            case 4: return "4th Quarter"
            default: return "Period \(next)"
            }
        } else {
            return next == 2 ? "2nd Half" : "OT"
        }
    }

    private func exportGameCSV() {
        var lines = ["Period,Time,Event,Player,Detail"]
        for event in game.events.sorted(by: { $0.timestamp < $1.timestamp }) {
            let time = formatTime(event.elapsedSeconds)
            let player = event.playerName.isEmpty ? "" : event.playerName
            let detail = event.detail.replacingOccurrences(of: ",", with: " ")
            lines.append("\(event.periodNumber),\(time),\(event.eventType.rawValue),\(player),\(detail)")
        }
        if !game.notes.isEmpty {
            lines.append("")
            lines.append("Coaching Notes")
            lines.append(game.notes.replacingOccurrences(of: "\n", with: " "))
        }
        exportContent = lines.joined(separator: "\n")
        showShareSheet = true
    }

    private func exportNotesTXT() {
        let header = "Game Notes – vs \(game.opponentName) – \(game.date.formatted(date: .long, time: .omitted))\n\n"
        exportContent = header + (game.notes.isEmpty ? "No notes." : game.notes)
        showShareSheet = true
    }

    func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Supporting Views

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(color)
        }
    }
}

struct EventRowView: View {
    let event: GameEvent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.eventType.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.eventType.rawValue)
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
            Text("Q\(event.periodNumber)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
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

struct ManualClockView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var minutes: String
    @Binding var seconds: String
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Set Remaining Time") {
                    HStack {
                        TextField("MM", text: $minutes)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text(":")
                        TextField("SS", text: $seconds)
                            .keyboardType(.numberPad)
                    }
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                }
            }
            .navigationTitle("Set Clock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}
