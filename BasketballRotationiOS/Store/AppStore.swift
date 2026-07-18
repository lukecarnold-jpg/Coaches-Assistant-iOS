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

struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

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

enum TrainingError: LocalizedError {
    case missingAPIKey
    case noResponse
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Please provide a Gemini API key."
        case .noResponse:
            return "No response was returned from Gemini."
        case .parseFailed:
            return "Could not parse drills from the AI response."
        }
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
        let onCourt = game.onCourtIDSet
        let absent = game.absentIDSet
        let gameEvents = events
            .filter { $0.gameID == game.id }
            .sorted { lhs, rhs in
                if lhs.timestamp == rhs.timestamp {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.timestamp < rhs.timestamp
            }

        var totalTimeByPlayer: [UUID: Int64] = [:]
        var lastEnteredAtByPlayer: [UUID: Int64] = [:]
        var pointsByPlayer: [UUID: Int] = [:]
        var foulsByPlayer: [UUID: Int] = [:]
        var timesSubbedOffByPlayer: [UUID: Int] = [:]

        for event in gameEvents {
            switch event.type {
            case .startLineup:
                for id in parseUUIDCSV(event.note) {
                    lastEnteredAtByPlayer[id] = event.gameTimeMillis
                }

            case .substitution:
                if let playerInID = event.playerID {
                    lastEnteredAtByPlayer[playerInID] = event.gameTimeMillis
                }
                if let playerOutID = event.relatedPlayerID {
                    timesSubbedOffByPlayer[playerOutID, default: 0] += 1
                    if let enteredAt = lastEnteredAtByPlayer.removeValue(forKey: playerOutID) {
                        totalTimeByPlayer[playerOutID, default: 0] += max(0, event.gameTimeMillis - enteredAt)
                    }
                }

            case .score:
                if let playerID = event.playerID {
                    pointsByPlayer[playerID, default: 0] += event.amount
                }

            case .foul:
                if let playerID = event.playerID {
                    foulsByPlayer[playerID, default: 0] += event.amount
                }

            case .periodChange, .gameEnd:
                for (id, enteredAt) in lastEnteredAtByPlayer {
                    totalTimeByPlayer[id, default: 0] += max(0, event.gameTimeMillis - enteredAt)
                }
                lastEnteredAtByPlayer.removeAll()

            case .opponentScore, .mvpVote:
                break
            }
        }

        return players
            .filter { !absent.contains($0.id) }
            .map { player in
                let isOnCourt = onCourt.contains(player.id)
                let enteredAt = lastEnteredAtByPlayer[player.id] ?? currentGameTime
                let currentShift = isOnCourt ? max(0, currentGameTime - enteredAt) : 0
                let totalTime = (totalTimeByPlayer[player.id] ?? 0) + currentShift
                let playerKey = player.id.uuidString

                return PlayerGameStat(
                    player: player,
                    points: max(0, pointsByPlayer[player.id] ?? game.playerPoints[playerKey] ?? 0),
                    fouls: max(0, foulsByPlayer[player.id] ?? game.playerFouls[playerKey] ?? 0),
                    mvpVotes: max(0, game.playerMvpVotes[playerKey] ?? 0),
                    timesSubbedOff: max(0, timesSubbedOffByPlayer[player.id] ?? 0),
                    onCourt: isOnCourt,
                    currentShiftTimeMillis: currentShift,
                    totalTimeMillis: totalTime
                )
            }
    }

    func currentElapsedTime(for game: Game, now: Date = Date()) -> Int64 {
        let base = game.runningTimeMillis
        let liveOffset: Int64
        if let startedAt = game.timerLastStartedAt {
            liveOffset = Int64(now.timeIntervalSince(startedAt) * 1000)
        } else {
            liveOffset = 0
        }
        return min(game.periodDurationMillis, max(0, base + max(0, liveOffset)))
    }

    func periodRemainingTime(for game: Game, now: Date = Date()) -> Int64 {
        max(0, game.periodDurationMillis - currentElapsedTime(for: game, now: now))
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

        let trimmedJersey = jerseyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let jerseyNumber: Int?
        if trimmedJersey.isEmpty {
            jerseyNumber = nil
        } else if let parsed = Int(trimmedJersey) {
            jerseyNumber = parsed
        } else {
            showMessage("Jersey number must be numeric.")
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

        let trimmedJersey = jerseyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let jerseyNumber: Int?
        if trimmedJersey.isEmpty {
            jerseyNumber = nil
        } else if let parsed = Int(trimmedJersey) {
            jerseyNumber = parsed
        } else {
            showMessage("Jersey number must be numeric.")
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
            games[index].absentPlayerIDs.removeAll { $0 == playerID }
            games[index].onCourtEnteredAtMillisByPlayerID.removeValue(forKey: playerID.uuidString)
            games[index].playerPoints.removeValue(forKey: playerID.uuidString)
            games[index].playerFouls.removeValue(forKey: playerID.uuidString)
            games[index].playerMvpVotes.removeValue(forKey: playerID.uuidString)
        }

        saveState()
        showMessage("Player removed.")
    }

    func importPlayersCSV(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let text = String(decoding: data, as: UTF8.self)
        importPlayersCSV(text: text)
    }

    func createGame(title: String, opponent: String, useQuarters: Bool, periodMinutes: Int) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? "Game \(games.count + 1)" : trimmedTitle
        let duration = Int64(max(1, periodMinutes)) * 60 * 1000

        let game = Game(
            title: finalTitle,
            opponent: opponent.trimmingCharacters(in: .whitespacesAndNewlines),
            useQuarters: useQuarters,
            periodDurationMillis: duration
        )
        games.insert(game, at: 0)
        selectedGameID = game.id
        sortGames()
        saveState()
        showMessage("Game created.")
    }

    func advancePeriod() {
        mutateSelectedGame { game in
            guard !game.isFinished, game.currentPeriod < game.maxPeriods else { return }
            events.append(
                GameEvent(
                    gameID: game.id,
                    type: .periodChange,
                    note: "Finished Period \(game.currentPeriod)",
                    gameTimeMillis: currentElapsedTime(for: game)
                )
            )
            game.currentPeriod += 1
            game.runningTimeMillis = 0
            game.timerLastStartedAt = nil
            game.onCourtPlayerIDs = []
            game.onCourtEnteredAtMillisByPlayerID = [:]
        } successMessage: {
            showMessage("Advanced to next period.")
        }
    }

    func endGame() {
        mutateSelectedGame { game in
            guard !game.isFinished else { return }
            game.isFinished = true
            game.timerLastStartedAt = nil
            game.onCourtPlayerIDs = []
            game.onCourtEnteredAtMillisByPlayerID = [:]
            events.append(
                GameEvent(
                    gameID: game.id,
                    type: .gameEnd,
                    note: "Game Ended",
                    gameTimeMillis: currentElapsedTime(for: game)
                )
            )
        } successMessage: {
            showMessage("Game finalized and court reset.")
        }
    }

    func updateAbsentPlayers(_ playerIDs: [UUID]) {
        mutateSelectedGame { game in
            let unique = uniqueIDs(from: playerIDs)
            game.absentPlayerIDs = unique
            let absentSet = Set(unique)
            game.onCourtPlayerIDs.removeAll { absentSet.contains($0) }
            for id in absentSet {
                game.onCourtEnteredAtMillisByPlayerID.removeValue(forKey: id.uuidString)
            }
        } successMessage: {
            showMessage("Attendance updated.")
        }
    }

    func updateGameNotes(_ notes: String) {
        mutateSelectedGame { game in
            game.notes = notes
        }
    }

    func updateEvent(eventID: UUID, amountText: String, note: String) {
        guard let eventIndex = events.firstIndex(where: { $0.id == eventID }) else { return }
        let oldEvent = events[eventIndex]

        guard let gameIndex = games.firstIndex(where: { $0.id == oldEvent.gameID }) else { return }
        var game = games[gameIndex]

        let editableAmountTypes: Set<EventType> = [.score, .opponentScore, .foul, .mvpVote]
        let parsedAmount: Int
        if editableAmountTypes.contains(oldEvent.type) {
            guard let value = Int(amountText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                showMessage("Amount must be numeric.")
                return
            }
            parsedAmount = value
        } else {
            parsedAmount = oldEvent.amount
        }

        var updatedEvent = oldEvent
        updatedEvent.amount = parsedAmount
        updatedEvent.note = note

        rollbackEventEffect(oldEvent, from: &game)
        applyEventEffect(updatedEvent, to: &game)

        games[gameIndex] = game
        events[eventIndex] = updatedEvent
        saveState()
        showMessage("Event updated.")
    }

    func deleteEvent(eventID: UUID) {
        guard let eventIndex = events.firstIndex(where: { $0.id == eventID }) else { return }
        let event = events[eventIndex]

        guard let gameIndex = games.firstIndex(where: { $0.id == event.gameID }) else { return }
        var game = games[gameIndex]
        rollbackEventEffect(event, from: &game)

        games[gameIndex] = game
        events.remove(at: eventIndex)
        saveState()
        showMessage("Event removed.")
    }

    func deleteGame(_ gameID: UUID) {
        games.removeAll { $0.id == gameID }
        events.removeAll { $0.gameID == gameID }
        normalizeSelection()
        saveState()
        showMessage("Game deleted.")
    }

    func setStartingLineup(_ playerIDs: [UUID]) {
        let uniqueIDs = uniqueIDs(from: playerIDs)
        guard uniqueIDs.count == 5 else {
            showMessage("Select exactly 5 players.")
            return
        }

        mutateSelectedGame { game in
            guard !game.isFinished else { return }
            let eligible = uniqueIDs.filter { !game.absentIDSet.contains($0) }
            guard eligible.count == 5 else { return }

            let currentGameTime = currentElapsedTime(for: game)
            game.onCourtPlayerIDs = eligible
            game.onCourtEnteredAtMillisByPlayerID = Dictionary(uniqueKeysWithValues: eligible.map { ($0.uuidString, currentGameTime) })

            events.append(
                GameEvent(
                    gameID: game.id,
                    type: .startLineup,
                    note: eligible.map(\.uuidString).joined(separator: ","),
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
            guard !game.isFinished else { return }
            guard !game.absentIDSet.contains(playerInID),
                  game.onCourtPlayerIDs.contains(playerOutID),
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

        mutateSelectedGame { game in
            guard !game.isFinished else { return }
            let currentGameTime = currentElapsedTime(for: game)

            if let playerID {
                let playerKey = playerID.uuidString
                let currentPlayerPoints = game.playerPoints[playerKey] ?? 0
                let actualDelta = boundedDelta(requested: points, floors: [currentPlayerPoints, game.teamScore])
                guard actualDelta != 0 else { return }

                game.playerPoints[playerKey] = currentPlayerPoints + actualDelta
                game.teamScore = max(0, game.teamScore + actualDelta)
                events.append(
                    GameEvent(
                        gameID: game.id,
                        type: .score,
                        playerID: playerID,
                        amount: actualDelta,
                        gameTimeMillis: currentGameTime
                    )
                )
            } else {
                let actualDelta = boundedDelta(requested: points, floors: [game.opponentScore])
                guard actualDelta != 0 else { return }

                game.opponentScore = max(0, game.opponentScore + actualDelta)
                events.append(
                    GameEvent(
                        gameID: game.id,
                        type: .opponentScore,
                        amount: actualDelta,
                        gameTimeMillis: currentGameTime
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

            game.teamScore = max(0, game.teamScore + actualDelta)
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
            guard !game.isFinished else { return }
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
            guard !game.isFinished else { return }
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
            guard !game.isFinished else { return }

            if let startedAt = game.timerLastStartedAt {
                game.runningTimeMillis = currentElapsedTime(for: game, now: Date())
                game.timerLastStartedAt = nil
                return
            }

            if currentElapsedTime(for: game) >= game.periodDurationMillis {
                showMessage("Period has ended. Advance period or reset clock.")
                return
            }

            game.timerLastStartedAt = Date()
        }
    }

    func resetTimer() {
        mutateSelectedGame { game in
            game.runningTimeMillis = 0
            game.timerLastStartedAt = nil
            game.onCourtEnteredAtMillisByPlayerID = Dictionary(uniqueKeysWithValues: game.onCourtPlayerIDs.map { ($0.uuidString, Int64(0)) })
        } successMessage: {
            showMessage("Timer reset to 0:00.")
        }
    }

    func setGameTime(_ elapsedMillis: Int64) {
        mutateSelectedGame { game in
            let target = min(game.periodDurationMillis, max(0, elapsedMillis))
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
                csv($0.jerseyNumber.map(String.init) ?? "")
            ].joined(separator: ",")
        })
        return lines.joined(separator: "\n")
    }

    func selectedGameCSV() -> String {
        guard let game = selectedGame else { return "" }
        return gameCSV(for: game)
    }

    func selectedGameNotesTXT() -> String {
        guard let game = selectedGame else { return "" }
        return gameNotesTXT(for: game)
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
            "gameId,gameTitle,opponent,createdAt,teamScoreAtExport,gameNotes,eventId,eventTimestamp,eventGameTime,eventType,playerName,playerNumber,relatedPlayerName,relatedPlayerNumber,points,note"
        ]

        if gameEvents.isEmpty {
            lines.append([
                csv(game.id.uuidString),
                csv(game.title),
                csv(game.opponent),
                csv(Self.timestampFormatter.string(from: game.createdAt)),
                csv(String(game.teamScore)),
                csv(game.notes),
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
                    csv(game.notes),
                    csv(event.id.uuidString),
                    csv(Self.timestampFormatter.string(from: event.timestamp)),
                    csv(formatDuration(event.gameTimeMillis)),
                    csv(event.type.rawValue),
                    csv(player?.name ?? ""),
                    csv(player?.jerseyNumber.map(String.init) ?? ""),
                    csv(relatedPlayer?.name ?? ""),
                    csv(relatedPlayer?.jerseyNumber.map(String.init) ?? ""),
                    csv(String(event.amount)),
                    csv(exportNote(for: event, playersByID: playersByID))
                ].joined(separator: ","))
            }
        }

        return lines.joined(separator: "\n")
    }

    func gameNotesTXT(for game: Game) -> String {
        var lines: [String] = []
        lines.append("Game: \(game.title)")
        lines.append("Opponent: \(game.opponent)")
        lines.append("Date: \(Self.timestampFormatter.string(from: game.createdAt))")
        lines.append("Score: Us \(game.teamScore) - \(game.opponentScore) \(game.opponent)")
        lines.append("")
        lines.append("--- COACHING NOTES ---")
        lines.append("")
        lines.append(game.notes)
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
            let lineup = parseUUIDCSV(event.note)
                .compactMap { playersByID[$0]?.displayLabel }
                .joined(separator: " | ")
            return "Starting lineup: \(lineup)"

        case .substitution:
            let playerIn = playerLabel(for: event.playerID, playersByID: playersByID)
            let playerOut = playerLabel(for: event.relatedPlayerID, playersByID: playersByID)
            return "\(playerIn) in for \(playerOut)"

        case .score:
            if event.note == "TEAM_ADJUSTMENT" {
                return "Team score \(signed(event.amount))"
            }
            return "\(playerLabel(for: event.playerID, playersByID: playersByID)) \(signed(event.amount))"

        case .opponentScore:
            return "Opponent \(signed(event.amount))"

        case .foul:
            if event.amount >= 0 {
                return "\(playerLabel(for: event.playerID, playersByID: playersByID)) foul"
            }
            return "\(playerLabel(for: event.playerID, playersByID: playersByID)) foul correction"

        case .mvpVote:
            return "\(playerLabel(for: event.playerID, playersByID: playersByID)) MVP vote"

        case .periodChange:
            return event.note.isEmpty ? "Period changed" : event.note

        case .gameEnd:
            return "Game ended"
        }
    }

    func generateDrills(ageGroup: String, apiKey: String) async throws -> [BasketballDrill] {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw TrainingError.missingAPIKey }

        let prompt = """
        Generate exactly 3 age-appropriate basketball drills for \(ageGroup) players.
        Format each drill with a 'TITLE:', 'DESCRIPTION:', and 'TEACHING POINTS:' on separate lines.
        Keep descriptions concise and practical.
        """

        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(trimmedKey)")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GeminiRequest(contents: [GeminiContent(parts: [GeminiPart(text: prompt)])])
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        let text = response.candidates.first?.content.parts.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw TrainingError.noResponse }

        let drills = parseDrills(from: text)
        guard !drills.isEmpty else { throw TrainingError.parseFailed }
        return Array(drills.prefix(3))
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
            return parseUUIDCSV(event.note)
                .compactMap { playersByID[$0]?.displayLabel }
                .joined(separator: " | ")
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
            switch (lhs.jerseyNumber, rhs.jerseyNumber) {
            case let (.some(left), .some(right)):
                if left == right {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return left < right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
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

        let oldGame = games[index]
        mutate(&games[index])
        if games[index] != oldGame {
            saveState()
            successMessage?()
        }
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

    private func parseUUIDCSV(_ text: String) -> [UUID] {
        text.split(separator: ",")
            .compactMap { UUID(uuidString: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func uniqueIDs(from ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        var result: [UUID] = []
        for id in ids where !seen.contains(id) {
            seen.insert(id)
            result.append(id)
        }
        return result
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let char = line[index]
            if char == "\"" {
                let next = line.index(after: index)
                if inQuotes && next < line.endIndex && line[next] == "\"" {
                    current.append("\"")
                    index = next
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
            index = line.index(after: index)
        }

        result.append(current)
        return result
    }

    private func importPlayersCSV(text: String) {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !lines.isEmpty else { return }

        let startIndex = lines.first?.localizedCaseInsensitiveContains("name") == true ? 1 : 0
        var importedCount = 0

        for line in lines.dropFirst(startIndex) {
            let fields = parseCSVLine(line)
            if fields.count >= 3 {
                let name = fields[1].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let jersey = Int(fields[2].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
                if !name.isEmpty {
                    players.append(Player(name: name, jerseyNumber: jersey))
                    importedCount += 1
                }
            } else if fields.count == 2 {
                let first = fields[0].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let second = fields[1].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let looksLikeID = Int(first) != nil
                let name = looksLikeID ? second : first
                let jersey = looksLikeID ? nil : Int(second)
                if !name.isEmpty {
                    players.append(Player(name: name, jerseyNumber: jersey))
                    importedCount += 1
                }
            } else if fields.count == 1 {
                let name = fields[0].trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if !name.isEmpty {
                    players.append(Player(name: name, jerseyNumber: nil))
                    importedCount += 1
                }
            }
        }

        sortPlayers()
        saveState()
        showMessage("Imported \(importedCount) players.")
    }

    private func applyEventEffect(_ event: GameEvent, to game: inout Game) {
        switch event.type {
        case .score:
            if let playerID = event.playerID {
                let key = playerID.uuidString
                game.playerPoints[key] = max(0, (game.playerPoints[key] ?? 0) + event.amount)
                game.teamScore = max(0, game.teamScore + event.amount)
            } else {
                game.teamScore = max(0, game.teamScore + event.amount)
            }
        case .opponentScore:
            game.opponentScore = max(0, game.opponentScore + event.amount)
        case .foul:
            if let playerID = event.playerID {
                let key = playerID.uuidString
                game.playerFouls[key] = max(0, (game.playerFouls[key] ?? 0) + event.amount)
            }
        case .mvpVote:
            if let playerID = event.playerID {
                let key = playerID.uuidString
                game.playerMvpVotes[key] = max(0, (game.playerMvpVotes[key] ?? 0) + event.amount)
            }
        case .startLineup, .substitution, .periodChange, .gameEnd:
            break
        }
    }

    private func rollbackEventEffect(_ event: GameEvent, from game: inout Game) {
        var inverse = event
        inverse.amount = -event.amount
        applyEventEffect(inverse, to: &game)
    }

    private func parseDrills(from text: String) -> [BasketballDrill] {
        let blocks = text.components(separatedBy: "TITLE:")
        var drills: [BasketballDrill] = []

        for rawBlock in blocks {
            let block = rawBlock.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !block.isEmpty else { continue }

            guard let descriptionRange = block.range(of: "DESCRIPTION:", options: .caseInsensitive),
                  let teachingRange = block.range(of: "TEACHING POINTS:", options: .caseInsensitive) else {
                continue
            }

            let title = block[..<descriptionRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let description = block[descriptionRange.upperBound..<teachingRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let teaching = block[teachingRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !title.isEmpty, !description.isEmpty else { continue }
            drills.append(BasketballDrill(title: title, description: description, teachingPoints: teaching))
        }

        return drills
    }
}

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
}

private struct GeminiContent: Encodable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Encodable {
    let text: String
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContentResponse
}

private struct GeminiContentResponse: Decodable {
    let parts: [GeminiPartResponse]
}

private struct GeminiPartResponse: Decodable {
    let text: String?
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
