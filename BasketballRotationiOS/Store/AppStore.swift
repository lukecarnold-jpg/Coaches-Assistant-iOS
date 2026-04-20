import SwiftUI
import UniformTypeIdentifiers

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        self.text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var players: [Player] = []
    @Published private(set) var games: [Game] = []
    @Published private(set) var events: [GameEvent] = []
    @Published var selectedGameID: UUID?
    @Published var toastMessage: String?

    private let saveURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        self.saveURL = directory.appendingPathComponent("basketball_rotation_state.json")
        loadState()
    }

    var selectedGame: Game? {
        if let selectedGameID,
           let game = games.first(where: { $0.id == selectedGameID }) {
            return game
        }
        return games.first
    }

    var selectedGameEvents: [GameEvent] {
        guard let gameID = selectedGame?.id else { return [] }
        return events
            .filter { $0.gameID == gameID }
            .sorted { lhs, rhs in
                if lhs.timestamp == rhs.timestamp {
                    return lhs.id.uuidString > rhs.id.uuidString
                }
                return lhs.timestamp > rhs.timestamp
            }
    }

    func stats(for game: Game, now: Date = Date()) -> [PlayerGameStat] {
        let currentGameTime = currentElapsedTime(for: game, now: now)

        return players.map { player in
            let key = player.id.uuidString
            let onCourt = game.onCourtIDSet.contains(player.id)
            let enteredAt = game.onCourtEnteredAtMillisByPlayerID[key] ?? currentGameTime
            let shift = onCourt ? max(0, currentGameTime - enteredAt) : 0

            return PlayerGameStat(
                player: player,
                points: game.playerPoints[key] ?? 0,
                fouls: game.playerFouls[key] ?? 0,
                mvpVotes: game.playerMvpVotes[key] ?? 0,
                onCourt: onCourt,
                currentShiftTimeMillis: shift
            )
        }
    }

    func currentElapsedTime(for game: Game, now: Date = Date()) -> Int64 {
        let base = game.runningTimeMillis
        guard let startedAt = game.timerLastStartedAt else { return base }
        let liveOffset = Int64(now.timeIntervalSince(startedAt) * 1000)
        return base + max(0, liveOffset)
    }

    func selectGame(_ id: UUID) {
        selectedGameID = id
        saveState()
    }

    func addPlayer(name: String, jerseyText: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showMessage("Enter a player name.")
            return
        }

        guard let jerseyNumber = Int(jerseyText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            showMessage("Enter a valid jersey number.")
            return
        }

        players.append(Player(name: trimmedName, jerseyNumber: jerseyNumber))
        sortPlayers()
        saveState()
        showMessage("Player added.")
    }

    func updatePlayer(_ player: Player, name: String, jerseyText: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showMessage("Enter a player name.")
            return
        }

        guard let jerseyNumber = Int(jerseyText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            showMessage("Enter a valid jersey number.")
            return
        }

        guard let index = players.firstIndex(where: { $0.id == player.id }) else { return }
        players[index].name = trimmedName
        players[index].jerseyNumber = jerseyNumber
        sortPlayers()
        saveState()
        showMessage("Player updated.")
    }

    func deletePlayer(_ playerID: UUID) {
        players.removeAll { $0.id == playerID }

        for index in games.indices {
            games[index].onCourtPlayerIDs.removeAll { $0 == playerID }
            games[index].onCourtEnteredAtMillisByPlayerID.removeValue(forKey: playerID.uuidString)
            games[index].playerPoints.removeValue(forKey: playerID.uuidString)
            games[index].playerFouls.removeValue(forKey: playerID.uuidString)
            games[index].playerMvpVotes.removeValue(forKey: playerID.uuidString)
        }

        saveState()
        showMessage("Player removed.")
    }

    func createGame(title: String, opponent: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? "Game \(games.count + 1)" : trimmedTitle

        let game = Game(title: finalTitle, opponent: opponent.trimmingCharacters(in: .whitespacesAndNewlines))
        games.insert(game, at: 0)
        selectedGameID = game.id
        sortGames()
        saveState()
        showMessage("Game created.")
    }

    func deleteGame(_ gameID: UUID) {
        games.removeAll { $0.id == gameID }
        events.removeAll { $0.gameID == gameID }
        normalizeSelection()
        saveState()
        showMessage("Game deleted.")
    }

    func setStartingLineup(_ playerIDs: [UUID]) {
        var uniqueIDs: [UUID] = []
        for id in playerIDs where !uniqueIDs.contains(id) {
            uniqueIDs.append(id)
        }

        guard uniqueIDs.count == 5 else {
            showMessage("Select exactly 5 players.")
            return
        }

        mutateSelectedGame { game in
            let currentGameTime = currentElapsedTime(for: game)
            game.onCourtPlayerIDs = uniqueIDs
            game.onCourtEnteredAtMillisByPlayerID = Dictionary(uniqueKeysWithValues: uniqueIDs.map { ($0.uuidString, currentGameTime) })

            events.append(
                GameEvent(
                    gameID: game.id,
                    type: .startLineup,
                    note: uniqueIDs.map(\.uuidString).joined(separator: ","),
                    gameTimeMillis: currentGameTime
                )
            )
        } successMessage: {
            showMessage("Starting lineup saved.")
        }
    }

    func substitute(playerInID: UUID?, playerOutID: UUID?) {
        guard let playerInID, let playerOutID else {
            showMessage("Pick one player in and one player out.")
            return
        }

        guard playerInID != playerOutID else {
            showMessage("Player in and player out must be different.")
            return
        }

        mutateSelectedGame { game in
            guard game.onCourtPlayerIDs.contains(playerOutID),
                  !game.onCourtPlayerIDs.contains(playerInID) else {
                return
            }

            let currentGameTime = currentElapsedTime(for: game)
            game.onCourtPlayerIDs = game.onCourtPlayerIDs.map { $0 == playerOutID ? playerInID : $0 }
            game.onCourtEnteredAtMillisByPlayerID.removeValue(forKey: playerOutID.uuidString)
            game.onCourtEnteredAtMillisByPlayerID[playerInID.uuidString] = currentGameTime

            events.append(
                GameEvent(
                    gameID: game.id,
                    type: .substitution,
                    playerID: playerInID,
                    relatedPlayerID: playerOutID,
                    gameTimeMillis: currentGameTime
                )
            )
        } successMessage: {
            showMessage("Substitution recorded.")
        }
    }

    func addScore(playerID: UUID?, points: Int) {
        guard points != 0 else { return }

        if let playerID {
            mutateSelectedGame { game in
                let playerKey = playerID.uuidString
                let currentPlayerPoints = game.playerPoints[playerKey] ?? 0
                let actualDelta = boundedDelta(requested: points, floors: [currentPlayerPoints, game.teamScore])
                guard actualDelta != 0 else { return }

                game.playerPoints[playerKey] = currentPlayerPoints + actualDelta
                game.teamScore += actualDelta

                events.append(
                    GameEvent(
                        gameID: game.id,
                        type: .score,
                        playerID: playerID,
                        amount: actualDelta,
                        gameTimeMillis: currentElapsedTime(for: game)
                    )
                )
            }
        } else {
            mutateSelectedGame { game in
                let actualDelta = boundedDelta(requested: points, floors: [game.opponentScore])
                guard actualDelta != 0 else { return }

                game.opponentScore += actualDelta
                events.append(
                    GameEvent(
                        gameID: game.id,
                        type: .score,
                        amount: actualDelta,
                        note: "OPPONENT",
                        gameTimeMillis: currentElapsedTime(for: game)
                    )
                )
            }
        }
    }

    func adjustTeamScore(by delta: Int) {
        guard delta != 0 else { return }

        mutateSelectedGame { game in
            let actualDelta = boundedDelta(requested: delta, floors: [game.teamScore])
            guard actualDelta != 0 else { return }

            game.teamScore += actualDelta
            events.append(
                GameEvent(
                    gameID: game.id,
                    type: .score,
                    amount: actualDelta,
                    note: "TEAM_ADJUSTMENT",
                    gameTimeMillis: currentElapsedTime(for: game)
                )
            )
        }
    }

    func addFoul(playerID: UUID, delta: Int) {
        guard delta != 0 else { return }

        mutateSelectedGame { game in
            let key = playerID.uuidString
            let currentValue = game.playerFouls[key] ?? 0
            let actualDelta = boundedDelta(requested: delta, floors: [currentValue])
            guard actualDelta != 0 else { return }

            game.playerFouls[key] = currentValue + actualDelta
            events.append(
                GameEvent(
                    gameID: game.id,
                    type: .foul,
                    playerID: playerID,
                    amount: actualDelta,
                    gameTimeMillis: currentElapsedTime(for: game)
                )
            )
        }
    }

    func addMvpVote(playerID: UUID) {
        mutateSelectedGame { game in
            let key = playerID.uuidString
            game.playerMvpVotes[key] = (game.playerMvpVotes[key] ?? 0) + 1
            events.append(
                GameEvent(
                    gameID: game.id,
                    type: .mvpVote,
                    playerID: playerID,
                    amount: 1,
                    gameTimeMillis: currentElapsedTime(for: game)
                )
            )
        }
    }

    func toggleTimer() {
        mutateSelectedGame { game in
            if let startedAt = game.timerLastStartedAt {
                game.runningTimeMillis += Int64(Date().timeIntervalSince(startedAt) * 1000)
                game.timerLastStartedAt = nil
            } else {
                game.timerLastStartedAt = Date()
            }
        }
    }

    func resetTimer() {
        mutateSelectedGame { game in
            game.runningTimeMillis = 0
            game.timerLastStartedAt = nil
            game.onCourtEnteredAtMillisByPlayerID = Dictionary(uniqueKeysWithValues: game.onCourtPlayerIDs.map { ($0.uuidString, Int64(0)) })
        }
    }

    func setGameTime(_ millis: Int64) {
        let target = max(0, millis)

        mutateSelectedGame { game in
            let current = currentElapsedTime(for: game)
            let delta = target - current

            game.runningTimeMillis = target
            if game.timerLastStartedAt != nil {
                game.timerLastStartedAt = Date()
            }

            for key in game.onCourtEnteredAtMillisByPlayerID.keys {
                let oldValue = game.onCourtEnteredAtMillisByPlayerID[key] ?? 0
                game.onCourtEnteredAtMillisByPlayerID[key] = oldValue + delta
            }
        }
    }

    func clearAllData() {
        players = []
        games = []
        events = []
        selectedGameID = nil
        saveState()
        showMessage("All data cleared.")
    }

    func playersCSV() -> String {
        var lines = ["id,name,jerseyNumber"]
        lines.append(contentsOf: players.map {
            [
                csv($0.id.uuidString),
                csv($0.name),
                csv(String($0.jerseyNumber))
            ].joined(separator: ",")
        })
        return lines.joined(separator: "\n")
    }

    func selectedGameCSV() -> String {
        guard let game = selectedGame else { return "" }
        return gameCSV(for: game)
    }

    func gameCSV(for game: Game) -> String {
        let playersByID = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
        let gameEvents = events
            .filter { $0.gameID == game.id }
            .sorted { lhs, rhs in
                if lhs.timestamp == rhs.timestamp {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.timestamp < rhs.timestamp
            }

        var lines = [
            "gameId,gameTitle,opponent,createdAt,teamScoreAtExport,opponentScoreAtExport,eventId,eventTimestamp,gameClock,eventType,playerName,playerNumber,relatedPlayerName,relatedPlayerNumber,amount,note"
        ]

        if gameEvents.isEmpty {
            lines.append([
                csv(game.id.uuidString),
                csv(game.title),
                csv(game.opponent),
                csv(Self.timestampFormatter.string(from: game.createdAt)),
                csv(String(game.teamScore)),
                csv(String(game.opponentScore)),
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                ""
            ].joined(separator: ","))
        } else {
            for event in gameEvents {
                let player = event.playerID.flatMap { playersByID[$0] }
                let relatedPlayer = event.relatedPlayerID.flatMap { playersByID[$0] }

                lines.append([
                    csv(game.id.uuidString),
                    csv(game.title),
                    csv(game.opponent),
                    csv(Self.timestampFormatter.string(from: game.createdAt)),
                    csv(String(game.teamScore)),
                    csv(String(game.opponentScore)),
                    csv(event.id.uuidString),
                    csv(Self.timestampFormatter.string(from: event.timestamp)),
                    csv(formatDuration(event.gameTimeMillis)),
                    csv(event.type.rawValue),
                    csv(player?.name ?? ""),
                    csv(player.map { String($0.jerseyNumber) } ?? ""),
                    csv(relatedPlayer?.name ?? ""),
                    csv(relatedPlayer.map { String($0.jerseyNumber) } ?? ""),
                    csv(String(event.amount)),
                    csv(exportNote(for: event, playersByID: playersByID))
                ].joined(separator: ","))
            }
        }

        return lines.joined(separator: "\n")
    }

    func showMessage(_ text: String) {
        toastMessage = text
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if self.toastMessage == text {
                self.toastMessage = nil
            }
        }
    }

    func eventDescription(_ event: GameEvent, playersByID: [UUID: Player]) -> String {
        switch event.type {
        case .startLineup:
            let lineup = event.note
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
                .compactMap { playersByID[$0]?.displayLabel }
                .joined(separator: " | ")
            return "Starting lineup: \(lineup)"

        case .substitution:
            let playerIn = playerLabel(for: event.playerID, playersByID: playersByID)
            let playerOut = playerLabel(for: event.relatedPlayerID, playersByID: playersByID)
            return "\(playerIn) in for \(playerOut)"

        case .score:
            if event.note == "OPPONENT" {
                return "Opponent \(signed(event.amount))"
            }
            if event.note == "TEAM_ADJUSTMENT" {
                return "Team score \(signed(event.amount))"
            }
            return "\(playerLabel(for: event.playerID, playersByID: playersByID)) \(signed(event.amount))"

        case .foul:
            if event.amount >= 0 {
                return "\(playerLabel(for: event.playerID, playersByID: playersByID)) foul"
            }
            return "\(playerLabel(for: event.playerID, playersByID: playersByID)) foul correction"

        case .mvpVote:
            return "\(playerLabel(for: event.playerID, playersByID: playersByID)) MVP vote"
        }
    }

    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private func playerLabel(for id: UUID?, playersByID: [UUID: Player]) -> String {
        guard let id else { return "Unknown player" }
        return playersByID[id]?.displayLabel ?? "Removed player"
    }

    private func exportNote(for event: GameEvent, playersByID: [UUID: Player]) -> String {
        switch event.type {
        case .startLineup:
            return event.note
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
                .compactMap { playersByID[$0]?.displayLabel }
                .joined(separator: " | ")
        case .score where event.note == "OPPONENT":
            return "Opponent score"
        case .score where event.note == "TEAM_ADJUSTMENT":
            return "Team score adjustment"
        default:
            return event.note
        }
    }

    private func loadState() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        do {
            let data = try Data(contentsOf: saveURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(PersistedState.self, from: data)
            self.players = state.players
            self.games = state.games
            self.events = state.events
            self.selectedGameID = state.selectedGameID
            sortPlayers()
            sortGames()
            normalizeSelection()
        } catch {
            showMessage("Could not load saved data.")
        }
    }

    private func saveState() {
        do {
            let state = PersistedState(players: players, games: games, events: events, selectedGameID: selectedGameID)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            showMessage("Could not save local data.")
        }
    }

    private func sortPlayers() {
        players.sort { lhs, rhs in
            if lhs.jerseyNumber == rhs.jerseyNumber {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.jerseyNumber < rhs.jerseyNumber
        }
    }

    private func sortGames() {
        games.sort { $0.createdAt > $1.createdAt }
    }

    private func normalizeSelection() {
        guard !games.isEmpty else {
            selectedGameID = nil
            return
        }
        if let selectedGameID,
           games.contains(where: { $0.id == selectedGameID }) {
            return
        }
        selectedGameID = games.first?.id
    }

    private func mutateSelectedGame(_ mutate: (inout Game) -> Void, successMessage: (() -> Void)? = nil) {
        guard let currentGameID = selectedGame?.id,
              let index = games.firstIndex(where: { $0.id == currentGameID }) else {
            showMessage("Create or select a game first.")
            return
        }

        mutate(&games[index])
        saveState()
        successMessage?()
    }

    private func boundedDelta(requested: Int, floors: [Int]) -> Int {
        guard requested < 0 else { return requested }
        let maxNegative = floors.map { -$0 }.max() ?? requested
        return max(requested, maxNegative)
    }

    private func csv(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

func formatTime(_ date: Date) -> String {
    AppStore.timestampFormatter.string(from: date)
}

func formatDuration(_ millis: Int64) -> String {
    let totalSeconds = max(0, millis) / 1000
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

private func signed(_ value: Int) -> String {
    value >= 0 ? "+\(value)" : "\(value)"
}
