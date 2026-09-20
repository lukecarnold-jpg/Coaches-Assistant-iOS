import Foundation

/// One of the sports the app can track. Basketball's own models/views never read
/// this type — it exists only to drive Basketball's landing tile and the shared
/// drill prompt. Everything else here backs the five new sports.
enum Sport: String, CaseIterable, Identifiable, Hashable, Codable {
    case basketball
    case netball
    case soccer
    case afl
    case rugbyUnion
    case rugbyLeague

    var id: String { rawValue }

    /// All sports except Basketball — the six landing tiles show `allCases`,
    /// but the parallel Squad/Fixture roster & game screens only ever query
    /// for these, since Basketball keeps its own separate Player/Game models.
    static var supported: [Sport] { allCases }

    var rules: SportRules {
        switch self {
        case .basketball:
            return SportRules(
                displayName: "Basketball",
                systemImage: "figure.basketball",
                onFieldCount: 5,
                periodFormat: "quarters",
                periodCount: 4,
                defaultPeriodMinutes: 10,
                maxPeriodMinutes: 25,
                onFieldTerm: "On Court",
                drillNoun: "basketball",
                scoringActions: [
                    ScoringAction(code: "freeThrow", label: "Free Throw", points: 1),
                    ScoringAction(code: "fieldGoal", label: "Field Goal", points: 2),
                    ScoringAction(code: "threePointer", label: "3-Pointer", points: 3),
                ],
                disciplineActions: [
                    DisciplineAction(code: "foul", label: "Foul", systemImage: "hand.raised", removal: .none),
                ],
                positions: []
            )
        case .netball:
            return SportRules(
                displayName: "Netball",
                systemImage: "figure.handball",
                onFieldCount: 7,
                periodFormat: "quarters",
                periodCount: 4,
                defaultPeriodMinutes: 15,
                maxPeriodMinutes: 25,
                onFieldTerm: "On Court",
                drillNoun: "netball",
                scoringActions: [
                    ScoringAction(code: "goal", label: "Goal", points: 1),
                ],
                disciplineActions: [
                    DisciplineAction(code: "contact", label: "Contact", systemImage: "hand.raised", removal: .none),
                    DisciplineAction(code: "obstruction", label: "Obstruction", systemImage: "hand.raised", removal: .none),
                    DisciplineAction(code: "footwork", label: "Footwork", systemImage: "shoeprints.fill", removal: .none),
                    DisciplineAction(code: "offside", label: "Offside", systemImage: "flag", removal: .none),
                ],
                positions: [
                    Position(code: "GS", name: "Goal Shooter"),
                    Position(code: "GA", name: "Goal Attack"),
                    Position(code: "WA", name: "Wing Attack"),
                    Position(code: "C", name: "Centre"),
                    Position(code: "WD", name: "Wing Defence"),
                    Position(code: "GD", name: "Goal Defence"),
                    Position(code: "GK", name: "Goal Keeper"),
                ]
            )
        case .soccer:
            return SportRules(
                displayName: "Soccer",
                systemImage: "figure.soccer",
                onFieldCount: 11,
                periodFormat: "halves",
                periodCount: 2,
                defaultPeriodMinutes: 45,
                maxPeriodMinutes: 45,
                onFieldTerm: "On Field",
                drillNoun: "soccer",
                scoringActions: [
                    ScoringAction(code: "goal", label: "Goal", points: 1),
                ],
                disciplineActions: [
                    DisciplineAction(code: "yellowCard", label: "Yellow Card", systemImage: "rectangle.portrait.fill", removal: .none),
                    DisciplineAction(code: "redCard", label: "Red Card", systemImage: "rectangle.portrait.fill", removal: .permanent),
                ],
                positions: [
                    Position(code: "GK", name: "Goalkeeper"),
                    Position(code: "DEF", name: "Defender"),
                    Position(code: "MID", name: "Midfielder"),
                    Position(code: "FWD", name: "Forward"),
                ]
            )
        case .afl:
            return SportRules(
                displayName: "AFL",
                systemImage: "figure.australian.football",
                onFieldCount: 18,
                periodFormat: "quarters",
                periodCount: 4,
                defaultPeriodMinutes: 20,
                maxPeriodMinutes: 30,
                onFieldTerm: "On Ground",
                drillNoun: "AFL",
                scoringActions: [
                    ScoringAction(code: "goal", label: "Goal", points: 6),
                    ScoringAction(code: "behind", label: "Behind", points: 1),
                ],
                disciplineActions: [
                    DisciplineAction(code: "freeKickAgainst", label: "Free Kick Against", systemImage: "flag", removal: .none),
                    DisciplineAction(code: "fiftyMetre", label: "50m Penalty", systemImage: "flag.fill", removal: .none),
                ],
                positions: [
                    Position(code: "DEF", name: "Defender"),
                    Position(code: "MID", name: "Midfielder"),
                    Position(code: "FWD", name: "Forward"),
                    Position(code: "RUC", name: "Ruck"),
                    Position(code: "INT", name: "Interchange"),
                ]
            )
        case .rugbyUnion:
            return SportRules(
                displayName: "Rugby Union",
                systemImage: "figure.rugby",
                onFieldCount: 15,
                periodFormat: "halves",
                periodCount: 2,
                defaultPeriodMinutes: 40,
                maxPeriodMinutes: 40,
                onFieldTerm: "On Field",
                drillNoun: "rugby union",
                scoringActions: [
                    ScoringAction(code: "try", label: "Try", points: 5),
                    ScoringAction(code: "conversion", label: "Conversion", points: 2),
                    ScoringAction(code: "penaltyGoal", label: "Penalty Goal", points: 3),
                    ScoringAction(code: "dropGoal", label: "Drop Goal", points: 3),
                ],
                disciplineActions: [
                    DisciplineAction(code: "penaltyConceded", label: "Penalty Conceded", systemImage: "flag", removal: .none),
                    DisciplineAction(code: "sinBin", label: "Sin Bin (10 min)", systemImage: "rectangle.portrait.fill", removal: .temporary(seconds: 600)),
                    DisciplineAction(code: "sendOff", label: "Sent Off", systemImage: "rectangle.portrait.fill", removal: .permanent),
                ],
                positions: [
                    Position(code: "FRW", name: "Front Row"),
                    Position(code: "LCK", name: "Lock"),
                    Position(code: "BR", name: "Back Row"),
                    Position(code: "SH", name: "Scrum-Half"),
                    Position(code: "FH", name: "Fly-Half"),
                    Position(code: "CTR", name: "Centre"),
                    Position(code: "BCK", name: "Back"),
                ]
            )
        case .rugbyLeague:
            return SportRules(
                displayName: "Rugby League",
                systemImage: "figure.rugby",
                onFieldCount: 13,
                periodFormat: "halves",
                periodCount: 2,
                defaultPeriodMinutes: 40,
                maxPeriodMinutes: 40,
                onFieldTerm: "On Field",
                drillNoun: "rugby league",
                scoringActions: [
                    ScoringAction(code: "try", label: "Try", points: 4),
                    ScoringAction(code: "conversion", label: "Conversion", points: 2),
                    ScoringAction(code: "penaltyGoal", label: "Penalty Goal", points: 2),
                    ScoringAction(code: "fieldGoal", label: "Field Goal", points: 1),
                ],
                disciplineActions: [
                    DisciplineAction(code: "penaltyConceded", label: "Penalty Conceded", systemImage: "flag", removal: .none),
                    DisciplineAction(code: "sinBin", label: "Sin Bin (10 min)", systemImage: "rectangle.portrait.fill", removal: .temporary(seconds: 600)),
                    DisciplineAction(code: "sendOff", label: "Sent Off", systemImage: "rectangle.portrait.fill", removal: .permanent),
                ],
                positions: [
                    Position(code: "PRP", name: "Prop"),
                    Position(code: "HKR", name: "Hooker"),
                    Position(code: "2RW", name: "Second Row"),
                    Position(code: "LF", name: "Lock"),
                    Position(code: "HB", name: "Halfback"),
                    Position(code: "FE", name: "Five-Eighth"),
                    Position(code: "CTR", name: "Centre"),
                    Position(code: "WNG", name: "Wing"),
                    Position(code: "FB", name: "Fullback"),
                ]
            )
        }
    }
}

/// How a discipline action removes a player from play.
enum Removal: Hashable {
    case none
    case temporary(seconds: Int)
    case permanent
}

struct ScoringAction: Identifiable, Hashable {
    let code: String
    let label: String
    let points: Int
    var id: String { code }
}

struct DisciplineAction: Identifiable, Hashable {
    let code: String
    let label: String
    let systemImage: String
    let removal: Removal
    var id: String { code }
}

struct Position: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }
}

/// Per-sport configuration: squad size, period structure, terminology, scoring,
/// discipline vocabulary and (optional) on-field positions.
struct SportRules {
    let displayName: String
    let systemImage: String
    let onFieldCount: Int
    let periodFormat: String
    let periodCount: Int
    let defaultPeriodMinutes: Int
    let maxPeriodMinutes: Int
    let onFieldTerm: String
    let drillNoun: String
    let scoringActions: [ScoringAction]
    let disciplineActions: [DisciplineAction]
    let positions: [Position]

    var hasPositions: Bool { !positions.isEmpty }

    func position(forCode code: String) -> Position? {
        positions.first { $0.code == code }
    }

    func disciplineAction(forCode code: String) -> DisciplineAction? {
        disciplineActions.first { $0.code == code }
    }

    func scoringAction(forCode code: String) -> ScoringAction? {
        scoringActions.first { $0.code == code }
    }
}
