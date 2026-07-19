import SwiftUI
import UniformTypeIdentifiers
import Combine

enum AppTab: Hashable, CaseIterable {
    case roster
    case game
    case training
    case settings

    var title: String {
        switch self {
        case .roster: return "Roster"
        case .game: return "Game"
        case .training: return "Training"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .roster: return "person.3.fill"
        case .game: return "basketball.fill"
        case .training: return "dumbbell.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

enum TrainingUiState {
    case idle
    case loading
    case success([BasketballDrill])
    case error(String)
}

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: AppTab = .roster
    @State private var now = Date()
    private let liveTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    List(AppTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            HStack {
                                Label(tab.title, systemImage: tab.icon)
                                Spacer()
                                if selectedTab == tab {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .navigationTitle("Basketball Rotation")
                } detail: {
                    selectedTabView
                }
            } else {
                TabView(selection: $selectedTab) {
                    tabViewItem(.roster)
                    tabViewItem(.game)
                    tabViewItem(.training)
                    tabViewItem(.settings)
                }
            }
        }
        .onReceive(liveTimer) { value in
            now = value
        }
        .overlay(alignment: .bottom) {
            if let message = store.toastMessage {
                ToastView(text: message)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.toastMessage)
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .roster:
            RosterScreen()
        case .game:
            GameScreen(now: now)
        case .training:
            TrainingScreen()
        case .settings:
            SettingsScreen()
        }
    }

    private func tabViewItem(_ tab: AppTab) -> some View {
        selectedView(for: tab)
            .tabItem {
                Label(tab.title, systemImage: tab.icon)
            }
            .tag(tab)
    }

    @ViewBuilder
    private func selectedView(for tab: AppTab) -> some View {
        switch tab {
        case .roster:
            RosterScreen()
        case .game:
            GameScreen(now: now)
        case .training:
            TrainingScreen()
        case .settings:
            SettingsScreen()
        }
    }
}

struct SettingsScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var showConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle("Settings")

                SectionCard(title: "Data management") {
                    Text("Clear all local data including players, games, and events. This cannot be undone.")
                        .font(.body)

                    Button(role: .destructive) {
                        showConfirm = true
                    } label: {
                        Text("Clear all data")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                SectionCard(title: "Exports") {
                    Text("Use the iOS export sheet to save CSV/TXT files to Files, iCloud Drive, or another location.")
                        .font(.body)
                }
            }
            .padding(16)
        }
        .alert("Confirm deletion", isPresented: $showConfirm) {
            Button("Delete everything", role: .destructive) {
                store.clearAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete all players, games, and events?")
        }
    }
}

struct RosterScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var name = ""
    @State private var jerseyNumber = ""
    @State private var showError = false
    @State private var editingPlayer: Player?
    @State private var showExport = false
    @State private var exportText = ""
    @State private var showImport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle("Team roster")

                SectionCard(title: "Add player") {
                    TextField("Player name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)

                    TextField("Jersey number (optional)", text: $jerseyNumber)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)

                    if showError {
                        ErrorBanner(text: "Player name is required.")
                    }

                    HStack(spacing: 12) {
                        Button("Add player") {
                            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                showError = true
                            } else {
                                store.addPlayer(name: name, jerseyText: jerseyNumber)
                                name = ""
                                jerseyNumber = ""
                                showError = false
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Export roster CSV") {
                            exportText = store.playersCSV()
                            showExport = true
                        }
                        .buttonStyle(.bordered)
                    }

                    Button("Import roster CSV") {
                        showImport = true
                    }
                    .buttonStyle(.bordered)
                }

                SectionCard(title: "Players") {
                    if store.players.isEmpty {
                        EmptyMessage(text: "No players yet. Add your roster first.")
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(store.players) { player in
                                HStack {
                                    Text(player.displayLabel)
                                        .font(.headline)

                                    Spacer()

                                    Button("Edit") {
                                        editingPlayer = player
                                    }
                                    .buttonStyle(.borderless)

                                    Button("Remove", role: .destructive) {
                                        store.deletePlayer(player.id)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(uiColor: .systemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(uiColor: .separator), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .sheet(item: $editingPlayer) { player in
            EditPlayerSheet(player: player)
        }
        .fileExporter(
            isPresented: $showExport,
            document: CSVDocument(text: exportText),
            contentType: .commaSeparatedText,
            defaultFilename: "players"
        ) { result in
            switch result {
            case .success:
                store.showMessage("Roster CSV exported.")
            case .failure(let error):
                store.showMessage(error.localizedDescription)
            }
        }
        .fileImporter(
            isPresented: $showImport,
            allowedContentTypes: [.commaSeparatedText, .plainText]
        ) { result in
            switch result {
            case .success(let url):
                do {
                    let hasAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if hasAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    try store.importPlayersCSV(from: url)
                } catch {
                    store.showMessage(error.localizedDescription)
                }
            case .failure(let error):
                store.showMessage(error.localizedDescription)
            }
        }
    }
}

struct EditPlayerSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let player: Player

    @State private var name: String
    @State private var jerseyNumber: String

    init(player: Player) {
        self.player = player
        _name = State(initialValue: player.name)
        _jerseyNumber = State(initialValue: player.jerseyNumber.map(String.init) ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                TextField("Player name", text: $name)
                    .textInputAutocapitalization(.words)

                TextField("Jersey number (optional)", text: $jerseyNumber)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("Edit player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updatePlayer(player, name: name, jerseyText: jerseyNumber)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GameScreen: View {
    @EnvironmentObject private var store: AppStore
    let now: Date

    @State private var gameTitle = ""
    @State private var opponent = ""
    @State private var useQuarters = false
    @State private var periodMinutes = 10
    @State private var absentSelection: Set<UUID> = []
    @State private var startingLineupSelection: Set<UUID> = []
    @State private var playerOutID: UUID?
    @State private var playerInID: UUID?
    @State private var notesDraft = ""
    @State private var showGameExport = false
    @State private var gameExportText = ""
    @State private var showRosterExport = false
    @State private var rosterExportText = ""
    @State private var showNotesExport = false
    @State private var notesExportText = ""
    @State private var editingEvent: GameEvent?

    var body: some View {
        let selectedGame = store.selectedGame
        let stats = selectedGame.map { store.stats(for: $0, now: now) } ?? []
        let onCourtStats = stats.filter { $0.onCourt }
        let benchStats = stats.filter { !$0.onCourt }
        let playersByID = Dictionary(uniqueKeysWithValues: store.players.map { ($0.id, $0) })
        let absentPlayers = Set(selectedGame?.absentPlayerIDs ?? [])
        let availablePlayers = store.players.filter { !absentPlayers.contains($0.id) }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle("Game tracker")

                SectionCard(title: "Create a game") {
                    TextField("Game title", text: $gameTitle)
                        .textFieldStyle(.roundedBorder)

                    TextField("Opponent", text: $opponent)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)

                    Toggle(isOn: $useQuarters) {
                        Text(useQuarters ? "Quarter game (4 periods)" : "Half game (2 periods)")
                    }

                    HStack {
                        Text("Period minutes: \(periodMinutes)")
                        Spacer()
                        Stepper("", value: $periodMinutes, in: 1...30)
                            .labelsHidden()
                    }

                    Button("Create game") {
                        store.createGame(
                            title: gameTitle,
                            opponent: opponent,
                            useQuarters: useQuarters,
                            periodMinutes: periodMinutes
                        )
                        gameTitle = ""
                        opponent = ""
                        useQuarters = false
                        periodMinutes = 10
                    }
                    .buttonStyle(.borderedProminent)
                }

                SectionCard(title: "Games") {
                    if store.games.isEmpty {
                        EmptyMessage(text: "No games yet.")
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(store.games) { game in
                                let selected = selectedGame?.id == game.id

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(game.title)
                                        .font(.headline)

                                    if !game.opponent.isEmpty {
                                        Text("Opponent: \(game.opponent)")
                                            .font(.subheadline)
                                    }

                                    Text("Period: \(game.currentPeriod)/\(game.maxPeriods)")
                                        .font(.subheadline)

                                    Text("Score: \(game.teamScore) - \(game.opponentScore)")
                                        .font(.subheadline)

                                    if game.isFinished {
                                        StatusBadge(text: "FINISHED")
                                    }

                                    HStack {
                                        Button(selected ? "Selected" : "Select") {
                                            store.selectGame(game.id)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(selected ? .green : Color.accentColor)

                                        Button("Delete", role: .destructive) {
                                            store.deleteGame(game.id)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(uiColor: .systemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selected ? Color.accentColor : Color(uiColor: .separator), lineWidth: selected ? 2 : 1)
                                )
                            }
                        }
                    }
                }

                if let game = selectedGame {
                    SectionCard(title: "Period controls") {
                        Text("\(game.useQuarters ? "Quarter" : "Half") \(game.currentPeriod) of \(game.maxPeriods)")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Button("Advance period") {
                                store.advancePeriod()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(game.isFinished || game.currentPeriod >= game.maxPeriods)

                            Button("End game", role: .destructive) {
                                store.endGame()
                            }
                            .buttonStyle(.bordered)
                            .disabled(game.isFinished)
                        }
                    }

                    SectionCard(title: "Attendance") {
                        Text("Mark absent players for this game.")

                        LazyVStack(spacing: 8) {
                            ForEach(store.players) { player in
                                CheckmarkRow(
                                    text: player.displayLabel,
                                    selected: absentSelection.contains(player.id)
                                ) {
                                    if absentSelection.contains(player.id) {
                                        absentSelection.remove(player.id)
                                    } else {
                                        absentSelection.insert(player.id)
                                    }
                                }
                            }
                        }

                        Button("Save attendance") {
                            store.updateAbsentPlayers(Array(absentSelection))
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(game.isFinished)
                    }

                    SectionCard(title: "Game clock & score") {
                        GameClockView(game: game, now: now)

                        Divider().padding(.vertical, 8)

                        HStack(spacing: 16) {
                            ScorePanel(
                                title: "Us",
                                score: game.teamScore,
                                buttons: [
                                    ScoreButton(title: "-1", action: { store.adjustTeamScore(by: -1) })
                                ]
                            )

                            ScorePanel(
                                title: game.opponent.isEmpty ? "Them" : game.opponent,
                                score: game.opponentScore,
                                buttons: [
                                    ScoreButton(title: "-1", action: { store.addScore(playerID: nil, points: -1) }),
                                    ScoreButton(title: "+1", action: { store.addScore(playerID: nil, points: 1) })
                                ]
                            )
                        }

                        HStack(spacing: 12) {
                            Button("Export game CSV") {
                                gameExportText = store.selectedGameCSV()
                                showGameExport = true
                            }
                            .buttonStyle(.bordered)

                            Button("Export roster CSV") {
                                rosterExportText = store.playersCSV()
                                showRosterExport = true
                            }
                            .buttonStyle(.bordered)

                            Button("Export notes TXT") {
                                notesExportText = store.selectedGameNotesTXT()
                                showNotesExport = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    SectionCard(title: "Coaching notes") {
                        TextEditor(text: $notesDraft)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(uiColor: .systemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(uiColor: .separator), lineWidth: 1)
                            )

                        Button("Save notes") {
                            store.updateGameNotes(notesDraft)
                            store.showMessage("Notes updated.")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if availablePlayers.count < 5 {
                        SectionCard(title: "Lineup") {
                            EmptyMessage(text: "You need at least 5 available players (not absent) before you can set the lineup.")
                        }
                    } else if game.onCourtPlayerIDs.count < 5 {
                        SectionCard(title: "Set starting lineup") {
                            Text("Select exactly 5 available players.")

                            LazyVStack(spacing: 8) {
                                ForEach(availablePlayers) { player in
                                    CheckmarkRow(
                                        text: player.displayLabel,
                                        selected: startingLineupSelection.contains(player.id)
                                    ) {
                                        if startingLineupSelection.contains(player.id) {
                                            startingLineupSelection.remove(player.id)
                                        } else if startingLineupSelection.count < 5 {
                                            startingLineupSelection.insert(player.id)
                                        }
                                    }
                                }
                            }

                            Button("Save starting lineup") {
                                store.setStartingLineup(Array(startingLineupSelection))
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(startingLineupSelection.count != 5 || game.isFinished)
                        }
                    } else {
                        SectionCard(title: "Players on court") {
                            LazyVStack(spacing: 10) {
                                ForEach(onCourtStats) { stat in
                                    PlayerActionCard(stat: stat)
                                }
                            }
                        }

                        SectionCard(title: "Substitution") {
                            Text("Choose one player to come out and one player to come in.")
                                .font(.body)

                            Text("Player out")
                                .font(.headline)

                            LazyVStack(spacing: 8) {
                                ForEach(onCourtStats) { stat in
                                    SelectablePlayerRow(
                                        text: stat.player.displayLabel,
                                        selected: playerOutID == stat.player.id
                                    ) {
                                        playerOutID = stat.player.id
                                    }
                                }
                            }

                            Text("Player in")
                                .font(.headline)
                                .padding(.top, 8)

                            if benchStats.isEmpty {
                                EmptyMessage(text: "No bench players available.")
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(benchStats) { stat in
                                        SelectablePlayerRow(
                                            text: stat.player.displayLabel,
                                            selected: playerInID == stat.player.id
                                        ) {
                                            playerInID = stat.player.id
                                        }
                                    }
                                }
                            }

                            Button("Record substitution") {
                                store.substitute(playerInID: playerInID, playerOutID: playerOutID)
                                playerInID = nil
                                playerOutID = nil
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(playerInID == nil || playerOutID == nil || game.isFinished)
                        }
                    }

                    SectionCard(title: "Game stats") {
                        if stats.isEmpty {
                            EmptyMessage(text: "No stats yet.")
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(stats) { stat in
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(stat.player.displayLabel)
                                                .font(.headline)

                                            Text("Points: \(stat.points)   Fouls: \(stat.fouls)   Votes: \(stat.mvpVotes)")
                                                .font(.subheadline)
                                            Text("Subbed off: \(stat.timesSubbedOff)   Total time: \(formatDuration(stat.totalTimeMillis))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if stat.onCourt {
                                            VStack(alignment: .trailing, spacing: 6) {
                                                StatusBadge(text: "ON COURT")
                                                Text(formatDuration(stat.currentShiftTimeMillis))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(uiColor: .systemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color(uiColor: .separator), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }

                    SectionCard(title: "Recent events") {
                        if store.selectedGameEvents.isEmpty {
                            EmptyMessage(text: "No events yet.")
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(store.selectedGameEvents) { event in
                                    VStack(alignment: .leading, spacing: 8) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(store.eventDescription(event, playersByID: playersByID))
                                                .font(.body.weight(.medium))

                                            Text("\(formatTime(event.timestamp)) • \(formatDuration(event.gameTimeMillis))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        HStack(spacing: 12) {
                                            Button("Edit") {
                                                editingEvent = event
                                            }
                                            .buttonStyle(.bordered)

                                            Button("Delete", role: .destructive) {
                                                store.deleteEvent(eventID: event.id)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(uiColor: .systemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color(uiColor: .separator), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                } else {
                    SectionCard(title: "Game") {
                        EmptyMessage(text: "Select a game to track rotation, scoring, fouls, MVP votes, and the game clock.")
                    }
                }
            }
            .padding(16)
        }
        .onAppear {
            if let game = store.selectedGame {
                absentSelection = Set(game.absentPlayerIDs)
                notesDraft = game.notes
            }
        }
        .onChange(of: store.selectedGameID) { _ in
            startingLineupSelection.removeAll()
            playerInID = nil
            playerOutID = nil
            if let game = store.selectedGame {
                absentSelection = Set(game.absentPlayerIDs)
                notesDraft = game.notes
            } else {
                absentSelection.removeAll()
                notesDraft = ""
            }
        }
        .sheet(item: $editingEvent) { event in
            EventEditorSheet(event: event) { amountText, note in
                store.updateEvent(eventID: event.id, amountText: amountText, note: note)
            }
        }
        .fileExporter(
            isPresented: $showGameExport,
            document: CSVDocument(text: gameExportText),
            contentType: .commaSeparatedText,
            defaultFilename: "game"
        ) { result in
            switch result {
            case .success:
                store.showMessage("Game CSV exported.")
            case .failure(let error):
                store.showMessage(error.localizedDescription)
            }
        }
        .fileExporter(
            isPresented: $showRosterExport,
            document: CSVDocument(text: rosterExportText),
            contentType: .commaSeparatedText,
            defaultFilename: "players"
        ) { result in
            switch result {
            case .success:
                store.showMessage("Roster CSV exported.")
            case .failure(let error):
                store.showMessage(error.localizedDescription)
            }
        }
        .fileExporter(
            isPresented: $showNotesExport,
            document: TextDocument(text: notesExportText),
            contentType: .plainText,
            defaultFilename: "coaching-notes"
        ) { result in
            switch result {
            case .success:
                store.showMessage("Coaching notes exported.")
            case .failure(let error):
                store.showMessage(error.localizedDescription)
            }
        }
    }
}

struct EventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let event: GameEvent
    let onSave: (String, String) -> Void

    @State private var amountText: String
    @State private var noteText: String

    init(event: GameEvent, onSave: @escaping (String, String) -> Void) {
        self.event = event
        self.onSave = onSave
        _amountText = State(initialValue: String(event.amount))
        _noteText = State(initialValue: event.note)
    }

    private var isAmountEditable: Bool {
        [.score, .opponentScore, .foul, .mvpVote].contains(event.type)
    }

    var body: some View {
        NavigationView {
            Form {
                if isAmountEditable {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.numbersAndPunctuation)
                }
                TextField("Note", text: $noteText)
            }
            .navigationTitle("Edit event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(amountText, noteText)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TrainingScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var ageGroup = "Under 10's"
    @State private var apiKey = ""
    @State private var uiState: TrainingUiState = .idle

    private let ageGroups = [
        "Mini Ball (Ages 5-6)",
        "Under 8's",
        "Under 10's",
        "Under 12's",
        "Under 14's",
        "Under 16's",
        "Under 18's"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ScreenTitle("Training drills")
                    Spacer()
                    Text("COMING SOON")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.15))
                        )
                }

                SectionCard(title: "Generate AI drills") {
                    Picker("Age group", selection: $ageGroup) {
                        ForEach(ageGroups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .pickerStyle(.menu)

                    SecureField("Gemini API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)

                    Button("Generate drills") {
                        Task {
                            uiState = .loading
                            do {
                                let drills = try await store.generateDrills(ageGroup: ageGroup, apiKey: apiKey)
                                uiState = .success(drills)
                            } catch {
                                uiState = .error(error.localizedDescription)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                SectionCard(title: "Training modules") {
                    Text("Interactive training modules, video demonstrations, and progress tracking are being expanded in upcoming releases.")
                        .font(.body)
                }

                SectionCard(title: "Results") {
                    switch uiState {
                    case .idle:
                        EmptyMessage(text: "Select an age group, add your API key, and generate drills.")
                    case .loading:
                        HStack {
                            ProgressView()
                            Text("Generating drills...")
                        }
                    case .error(let message):
                        ErrorBanner(text: message)
                    case .success(let drills):
                        LazyVStack(spacing: 10) {
                            ForEach(drills) { drill in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(drill.title)
                                        .font(.headline)
                                    Text("Description")
                                        .font(.subheadline.weight(.semibold))
                                    Text(drill.description)
                                        .font(.body)
                                    Divider()
                                    Text("Teaching points")
                                        .font(.subheadline.weight(.semibold))
                                    Text(drill.teachingPoints)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(uiColor: .systemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(uiColor: .separator), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct GameClockView: View {
    @EnvironmentObject private var store: AppStore
    let game: Game
    let now: Date

    @State private var editing = false
    @State private var minutesText = ""
    @State private var secondsText = ""

    var elapsed: Int64 {
        store.currentElapsedTime(for: game, now: now)
    }

    var remaining: Int64 {
        store.periodRemainingTime(for: game, now: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDuration(remaining))
                        .font(.system(size: 38, weight: .bold, design: .monospaced))
                    Text("Elapsed: \(formatDuration(elapsed))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    let remainingMinutes = remaining / 60_000
                    let remainingSeconds = (remaining % 60_000) / 1_000
                    minutesText = String(remainingMinutes)
                    secondsText = String(remainingSeconds)
                    editing.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)

                Button {
                    store.resetTimer()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Button(game.timerLastStartedAt == nil ? "Start" : "Stop") {
                    store.toggleTimer()
                }
                .buttonStyle(.borderedProminent)
                .tint(game.timerLastStartedAt == nil ? .accentColor : .red)
                .disabled(game.isFinished)
            }

            if editing {
                HStack(spacing: 12) {
                    TextField("Min", text: $minutesText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)

                    TextField("Sec", text: $secondsText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)

                    Button("Set") {
                        let minutes = Int64(minutesText) ?? 0
                        let seconds = Int64(secondsText) ?? 0
                        let requestedRemaining = max(0, (minutes * 60 + seconds) * 1000)
                        let targetElapsed = max(0, game.periodDurationMillis - requestedRemaining)
                        store.setGameTime(targetElapsed)
                        editing = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct PlayerActionCard: View {
    @EnvironmentObject private var store: AppStore
    let stat: PlayerGameStat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(stat.player.displayLabel)
                        .font(.headline)

                    Text("Points: \(stat.points)   Fouls: \(stat.fouls)")
                        .font(.subheadline)

                    Button("-1 pt") {
                        store.addScore(playerID: stat.player.id, points: -1)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)

                    Text("Shift: \(formatDuration(stat.currentShiftTimeMillis))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text("Total: \(formatDuration(stat.totalTimeMillis)) • Off: \(stat.timesSubbedOff)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    StatusBadge(text: "ON COURT")

                    Button("MVP Vote (\(stat.mvpVotes))") {
                        store.addMvpVote(playerID: stat.player.id)
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 8) {
                SmallActionButton(title: "+1") {
                    store.addScore(playerID: stat.player.id, points: 1)
                }
                SmallActionButton(title: "+2") {
                    store.addScore(playerID: stat.player.id, points: 2)
                }
                SmallActionButton(title: "+3") {
                    store.addScore(playerID: stat.player.id, points: 3)
                }
            }

            HStack {
                Text("Fouls")
                    .font(.body.weight(.bold))

                Spacer()

                HStack(spacing: 10) {
                    Button("-") {
                        store.addFoul(playerID: stat.player.id, delta: -1)
                    }
                    .buttonStyle(.bordered)

                    Text("\(stat.fouls)")
                        .font(.headline)
                        .frame(minWidth: 28)

                    Button {
                        store.addFoul(playerID: stat.player.id, delta: 1)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(uiColor: .separator), lineWidth: 1)
        )
    }
}

struct ScoreButton {
    let title: String
    let action: () -> Void
}

struct ScorePanel: View {
    let title: String
    let score: Int
    let buttons: [ScoreButton]

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("\(score)")
                .font(.system(size: 42, weight: .bold))

            HStack(spacing: 8) {
                ForEach(buttons.indices, id: \.self) { index in
                    Button(buttons[index].title, action: buttons[index].action)
                        .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(uiColor: .separator), lineWidth: 1)
        )
    }
}

struct ScreenTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

struct SmallActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
    }
}

struct SelectablePlayerRow: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .fontWeight(selected ? .semibold : .regular)

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? .accentColor : .secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? Color.accentColor.opacity(0.15) : Color(uiColor: .systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.accentColor : Color(uiColor: .separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CheckmarkRow: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? .accentColor : .secondary)

                Text(text)

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(uiColor: .systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(uiColor: .separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StatusBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
    }
}

struct ErrorBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.08))
            )
    }
}

struct EmptyMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(
                Capsule().fill(Color.black.opacity(0.85))
            )
            .padding(.horizontal, 16)
    }
}
