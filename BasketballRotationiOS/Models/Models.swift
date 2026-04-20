import Foundation

enum EventType: String, Codable, CaseIterable, Hashable {
    case startLineup = "START_LINEUP"
    case substitution = "SUBSTITUTION"
    case score = "SCORE"
    case foul = "FOUL"
    case mvpVote = "MVP_VOTE"
}

struct Player: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var jerseyNumber: Int

    init(id: UUID = UUID(), name: String, jerseyNumber: Int) {
        self.id = id
        self.name = name
        self.jerseyNumber = jerseyNumber
    }
}

struct Game: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var opponent: String
    var createdAt: Date
    var teamScore: Int
    var opponentScore: Int
    var onCourtPlayerIDs: [UUID]
    var onCourtEnteredAtMillisByPlayerID: [String: Int64]
    var runningTimeMillis: Int64
    var timerLastStartedAt: Date?
    var playerPoints: [String: Int]
    var playerFouls: [String: Int]
    var playerMvpVotes: [String: Int]

    init(
        id: UUID = UUID(),
        title: String,
        opponent: String,
        createdAt: Date = Date(),
        teamScore: Int = 0,
        opponentScore: Int = 0,
        onCourtPlayerIDs: [UUID] = [],
        onCourtEnteredAtMillisByPlayerID: [String: Int64] = [:],
        runningTimeMillis: Int64 = 0,
        timerLastStartedAt: Date? = nil,
        playerPoints: [String: Int] = [:],
        playerFouls: [String: Int] = [:],
        playerMvpVotes: [String: Int] = [:]
    ) {
        self.id = id
        self.title = title
        self.opponent = opponent
        self.createdAt = createdAt
        self.teamScore = teamScore
        self.opponentScore = opponentScore
        self.onCourtPlayerIDs = onCourtPlayerIDs
        self.onCourtEnteredAtMillisByPlayerID = onCourtEnteredAtMillisByPlayerID
        self.runningTimeMillis = runningTimeMillis
        self.timerLastStartedAt = timerLastStartedAt
        self.playerPoints = playerPoints
        self.playerFouls = playerFouls
        self.playerMvpVotes = playerMvpVotes
    }
}

struct GameEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let gameID: UUID
    let timestamp: Date
    let type: EventType
    let playerID: UUID?
    let relatedPlayerID: UUID?
    let amount: Int
    let note: String
    let gameTimeMillis: Int64

    init(
        id: UUID = UUID(),
        gameID: UUID,
        timestamp: Date = Date(),
        type: EventType,
        playerID: UUID? = nil,
        relatedPlayerID: UUID? = nil,
        amount: Int = 0,
        note: String = "",
        gameTimeMillis: Int64 = 0
    ) {
        self.id = id
        self.gameID = gameID
        self.timestamp = timestamp
        self.type = type
        self.playerID = playerID
        self.relatedPlayerID = relatedPlayerID
        self.amount = amount
        self.note = note
        self.gameTimeMillis = gameTimeMillis
    }
}

struct PlayerGameStat: Identifiable, Hashable {
    let id: UUID
    let player: Player
    let points: Int
    let fouls: Int
    let mvpVotes: Int
    let onCourt: Bool
    let currentShiftTimeMillis: Int64

    init(
        player: Player,
        points: Int,
        fouls: Int,
        mvpVotes: Int,
        onCourt: Bool,
        currentShiftTimeMillis: Int64
    ) {
        self.id = player.id
        self.player = player
        self.points = points
        self.fouls = fouls
        self.mvpVotes = mvpVotes
        self.onCourt = onCourt
        self.currentShiftTimeMillis = currentShiftTimeMillis
    }
}

struct PersistedState: Codable {
    var players: [Player]
    var games: [Game]
    var events: [GameEvent]
    var selectedGameID: UUID?
}

extension Player {
    var displayLabel: String {
        "#\(jerseyNumber) \(name)"
    }
}

extension Game {
    var onCourtIDSet: Set<UUID> {
        Set(onCourtPlayerIDs)
    }
}
