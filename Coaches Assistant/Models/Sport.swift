import Foundation

/// One of the sports the app can track. Every timed sport (including Basketball)
/// runs on the shared `SquadPlayer` / `Fixture` models; stats-only sports
/// (Cricket) use their own scorecard models.
nonisolated enum Sport: String, CaseIterable, Identifiable, Hashable, Codable {
    case basketball
    case netball
    case soccer
    case afl
    case rugbyUnion
    case rugbyLeague
    case iceHockey
    case fieldHockey
    case teamHandball
    case waterPolo
    case lacrosse
    case flagFootball
    case futsal
    case volleyball
    case touchFootball
    case cricket

    var id: String { rawValue }


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
                positions: [],
                matchTerm: "Game"
            )
        case .netball:
            return SportRules(
                displayName: "Netball",
                systemImage: "sportscourt",
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
        case .iceHockey:
            return SportRules(
                displayName: "Ice Hockey",
                systemImage: "figure.hockey",
                onFieldCount: 6,
                periodFormat: "quarters",
                periodCount: 4,
                defaultPeriodMinutes: 15,
                maxPeriodMinutes: 25,
                onFieldTerm: "On Ice",
                drillNoun: "ice hockey",
                scoringActions: [
                    ScoringAction(code: "goal", label: "Goal", points: 1),
                ],
                disciplineActions: [
                    DisciplineAction(code: "minorPenalty", label: "Minor Penalty (2 min)", systemImage: "timer", removal: .temporary(seconds: 120)),
                    DisciplineAction(code: "majorPenalty", label: "Major Penalty (5 min)", systemImage: "timer", removal: .temporary(seconds: 300)),
                    DisciplineAction(code: "misconduct", label: "Misconduct", systemImage: "rectangle.portrait.fill", removal: .permanent),
                ],
                positions: [
                    Position(code: "G", name: "Goalie"),
                    Position(code: "LD", name: "Left Defense"),
                    Position(code: "RD", name: "Right Defense"),
                    Position(code: "LW", name: "Left Wing"),
                    Position(code: "C", name: "Center"),
                    Position(code: "RW", name: "Right Wing"),
                ]
            )
        case .fieldHockey:
            return SportRules(
                displayName: "Field Hockey",
                systemImage: "figure.field.hockey",
                onFieldCount: 11,
                periodFormat: "quarters",
                periodCount: 4,
                defaultPeriodMinutes: 15,
                maxPeriodMinutes: 25,
                onFieldTerm: "On Field",
                drillNoun: "field hockey",
                scoringActions: [
                    ScoringAction(code: "goal", label: "Goal", points: 1),
                ],
                disciplineActions: [
                    DisciplineAction(code: "greenCard", label: "Green Card (2 min)", systemImage: "rectangle.portrait.fill", removal: .temporary(seconds: 120)),
                    DisciplineAction(code: "yellowCard", label: "Yellow Card (5 min)", systemImage: "rectangle.portrait.fill", removal: .temporary(seconds: 300)),
                    DisciplineAction(code: "redCard", label: "Red Card", systemImage: "rectangle.portrait.fill", removal: .permanent),
                ],
                positions: [
                    Position(code: "GK", name: "Goalkeeper"),
                    Position(code: "DEF", name: "Defender"),
                    Position(code: "MID", name: "Midfielder"),
                    Position(code: "FWD", name: "Forward"),
                ]
            )
        case .teamHandball:
            return SportRules(
                displayName: "Handball",
                systemImage: "figure.handball",
                onFieldCount: 7,
                periodFormat: "halves",
                periodCount: 2,
                defaultPeriodMinutes: 30,
                maxPeriodMinutes: 30,
                onFieldTerm: "On Court",
                drillNoun: "team handball",
                scoringActions: [
                    ScoringAction(code: "goal", label: "Goal", points: 1),
                ],
                disciplineActions: [
                    DisciplineAction(code: "yellowCard", label: "Yellow Card", systemImage: "rectangle.portrait.fill", removal: .none),
                    DisciplineAction(code: "twoMinuteSuspension", label: "2-Min Suspension", systemImage: "timer", removal: .temporary(seconds: 120)),
                    DisciplineAction(code: "redCard", label: "Red Card", systemImage: "rectangle.portrait.fill", removal: .permanent),
                ],
                positions: [
                    Position(code: "GK", name: "Goalkeeper"),
                    Position(code: "LW", name: "Left Wing"),
                    Position(code: "LB", name: "Left Back"),
                    Position(code: "CB", name: "Centre Back"),
                    Position(code: "RB", name: "Right Back"),
                    Position(code: "RW", name: "Right Wing"),
                    Position(code: "PVT", name: "Pivot"),
                ]
            )
        case .waterPolo:
            return SportRules(
                displayName: "Water Polo",
                systemImage: "figure.waterpolo",
                onFieldCount: 7,
                periodFormat: "quarters",
                periodCount: 4,
                defaultPeriodMinutes: 8,
                maxPeriodMinutes: 15,
                onFieldTerm: "In Pool",
                drillNoun: "water polo",
                scoringActions: [
                    ScoringAction(code: "goal", label: "Goal", points: 1),
                ],
                disciplineActions: [
                    DisciplineAction(code: "exclusion", label: "Exclusion (20s)", systemImage: "timer", removal: .temporary(seconds: 20)),
                    DisciplineAction(code: "majorFoul", label: "Brutality / Red Card", systemImage: "rectangle.portrait.fill", removal: .permanent),
                ],
                positions: [
                    Position(code: "GK", name: "Goalkeeper"),
                    Position(code: "CF", name: "Center Forward"),
                    Position(code: "CB", name: "Center Back"),
                    Position(code: "WNG", name: "Wing"),
                    Position(code: "DRV", name: "Driver"),
                    Position(code: "UTL", name: "Utility"),
                ]
            )
        case .lacrosse:
            return SportRules(
                displayName: "Lacrosse",
                systemImage: "figure.lacrosse",
                onFieldCount: 10,
                periodFormat: "quarters",
                periodCount: 4,
                defaultPeriodMinutes: 15,
                maxPeriodMinutes: 20,
                onFieldTerm: "On Field",
                drillNoun: "lacrosse",
                scoringActions: [
                    ScoringAction(code: "goal", label: "Goal", points: 1),
                    ScoringAction(code: "twoPointGoal", label: "2-Point Goal", points: 2),
                ],
                disciplineActions: [
                    DisciplineAction(code: "technicalFoul", label: "Technical Foul (30s)", systemImage: "timer", removal: .temporary(seconds: 30)),
                    DisciplineAction(code: "personalFoul", label: "Personal Foul (1 min)", systemImage: "timer", removal: .temporary(seconds: 60)),
                    DisciplineAction(code: "expulsion", label: "Expulsion", systemImage: "rectangle.portrait.fill", removal: .permanent),
                ],
                positions: [
                    Position(code: "G", name: "Goalie"),
                    Position(code: "DEF", name: "Close Defense"),
                    Position(code: "LSM", name: "Long Stick Midfield"),
                    Position(code: "MID", name: "Midfield"),
                    Position(code: "FOGO", name: "Face-off Specialist"),
                    Position(code: "ATT", name: "Attack"),
                ]
            )
        case .flagFootball:
            return SportRules(
                displayName: "Flag Football",
                systemImage: "figure.american.football",
                onFieldCount: 5,
                periodFormat: "halves",
                periodCount: 2,
                defaultPeriodMinutes: 20,
                maxPeriodMinutes: 30,
                onFieldTerm: "On Field",
                drillNoun: "flag football",
                scoringActions: [
                    ScoringAction(code: "touchdown", label: "Touchdown", points: 6),
                    ScoringAction(code: "extraPoint1", label: "1-Pt Conversion", points: 1),
                    ScoringAction(code: "extraPoint2", label: "2-Pt Conversion", points: 2),
                    ScoringAction(code: "safety", label: "Safety", points: 2),
                ],
                disciplineActions: [
                    DisciplineAction(code: "penalty", label: "Penalty", systemImage: "flag", removal: .none),
                    DisciplineAction(code: "unsportsmanlike", label: "Unsportsmanlike Conduct", systemImage: "flag.fill", removal: .none),
                ],
                positions: [
                    Position(code: "QB", name: "Quarterback"),
                    Position(code: "C", name: "Center"),
                    Position(code: "WR", name: "Wide Receiver"),
                    Position(code: "RB", name: "Running Back"),
                    Position(code: "RUSH", name: "Pass Rusher"),
                    Position(code: "DB", name: "Defensive Back"),
                    Position(code: "SAF", name: "Safety"),
                ]
            )
        case .futsal:
            return SportRules(
                displayName: "Futsal",
                systemImage: "figure.indoor.soccer",
                onFieldCount: 5,
                periodFormat: "halves",
                periodCount: 2,
                defaultPeriodMinutes: 20,
                maxPeriodMinutes: 25,
                onFieldTerm: "On Court",
                drillNoun: "futsal",
                scoringActions: [
                    ScoringAction(code: "goal", label: "Goal", points: 1),
                ],
                disciplineActions: [
                    DisciplineAction(code: "yellowCard", label: "Yellow Card", systemImage: "rectangle.portrait.fill", removal: .none),
                    DisciplineAction(code: "redCard", label: "Red Card (2 min)", systemImage: "rectangle.portrait.fill", removal: .temporary(seconds: 120)),
                ],
                positions: [
                    Position(code: "GK", name: "Goalkeeper"),
                    Position(code: "FIX", name: "Defender (Fixo)"),
                    Position(code: "ALA", name: "Winger (Ala)"),
                    Position(code: "PIV", name: "Pivot (Pivô)"),
                ]
            )
        case .volleyball:
            return SportRules(
                displayName: "Volleyball",
                systemImage: "figure.volleyball",
                onFieldCount: 6,
                periodFormat: "halves",
                periodCount: 2,
                defaultPeriodMinutes: 25,
                maxPeriodMinutes: 35,
                onFieldTerm: "On Court",
                drillNoun: "volleyball",
                scoringActions: [
                    ScoringAction(code: "point", label: "Point", points: 1),
                ],
                disciplineActions: [
                    DisciplineAction(code: "yellowCard", label: "Yellow Card (Warning)", systemImage: "rectangle.portrait.fill", removal: .none),
                    DisciplineAction(code: "redCard", label: "Red Card (Penalty Point)", systemImage: "rectangle.portrait.fill", removal: .none),
                    DisciplineAction(code: "expulsion", label: "Expulsion", systemImage: "rectangle.portrait.fill", removal: .permanent),
                ],
                positions: [
                    Position(code: "S", name: "Setter"),
                    Position(code: "OH", name: "Outside Hitter"),
                    Position(code: "MB", name: "Middle Blocker"),
                    Position(code: "OPP", name: "Opposite Hitter"),
                    Position(code: "L", name: "Libero"),
                    Position(code: "DS", name: "Defensive Specialist"),
                ]
            )
        case .touchFootball:
            return SportRules(
                displayName: "Touch Football",
                systemImage: "figure.rugby",
                onFieldCount: 6,
                periodFormat: "halves",
                periodCount: 2,
                defaultPeriodMinutes: 20,
                maxPeriodMinutes: 25,
                onFieldTerm: "On Field",
                drillNoun: "touch football",
                scoringActions: [
                    ScoringAction(code: "touchdown", label: "Touchdown", points: 1),
                ],
                disciplineActions: [
                    DisciplineAction(code: "penalty", label: "Penalty Conceded", systemImage: "flag", removal: .none),
                    DisciplineAction(code: "sinBin", label: "Sin Bin (4 min)", systemImage: "timer", removal: .temporary(seconds: 240)),
                    DisciplineAction(code: "sendOff", label: "Sent Off", systemImage: "rectangle.portrait.fill", removal: .permanent),
                ],
                positions: [
                    Position(code: "MID", name: "Middle"),
                    Position(code: "LNK", name: "Link"),
                    Position(code: "WNG", name: "Wing"),
                ]
            )
        case .cricket:
            // Stats-only: no clock, rotations or substitutions. Matches are recorded
            // as scorecards (`CricketMatch`) rather than `Fixture`s, so the period
            // fields below are placeholders that nothing reads.
            return SportRules(
                displayName: "Cricket",
                systemImage: "figure.cricket",
                onFieldCount: 11,
                periodFormat: "halves",
                periodCount: 2,
                defaultPeriodMinutes: 20,
                maxPeriodMinutes: 50,
                onFieldTerm: "Playing XI",
                drillNoun: "cricket",
                scoringActions: [
                    ScoringAction(code: "run", label: "Run", points: 1),
                    ScoringAction(code: "four", label: "Four", points: 4),
                    ScoringAction(code: "six", label: "Six", points: 6),
                ],
                disciplineActions: [],
                positions: [
                    Position(code: "BAT", name: "Batter"),
                    Position(code: "BWL", name: "Bowler"),
                    Position(code: "AR", name: "All-Rounder"),
                    Position(code: "WK", name: "Wicketkeeper"),
                ],
                isStatsOnly: true
            )
        }
    }
}

/// How a discipline action removes a player from play.
nonisolated enum Removal: Hashable {
    case none
    case temporary(seconds: Int)
    case permanent
}

nonisolated struct ScoringAction: Identifiable, Hashable {
    let code: String
    let label: String
    let points: Int
    var id: String { code }
}

nonisolated struct DisciplineAction: Identifiable, Hashable {
    let code: String
    let label: String
    let systemImage: String
    let removal: Removal
    var id: String { code }
}

nonisolated struct Position: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }
}

/// Per-sport configuration: squad size, period structure, terminology, scoring,
/// discipline vocabulary and (optional) on-field positions.
nonisolated struct SportRules {
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
    /// True for sports recorded as a post-match scorecard (Cricket) instead of a
    /// live clock/rotation fixture.
    var isStatsOnly: Bool = false
    /// What coaches of this sport call a match in the UI ("Game" for Basketball).
    var matchTerm: String = "Fixture"

    var matchTermPlural: String { matchTerm + "s" }

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
