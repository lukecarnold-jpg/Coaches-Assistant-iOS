import Testing
@testable import Coaches_Assistant

struct SportRulesTests {

    // MARK: - Raw values (persisted — must never silently change)

    @Test func rawValuesAreStable() {
        #expect(Sport.basketball.rawValue == "basketball")
        #expect(Sport.netball.rawValue == "netball")
        #expect(Sport.soccer.rawValue == "soccer")
        #expect(Sport.afl.rawValue == "afl")
        #expect(Sport.rugbyUnion.rawValue == "rugbyUnion")
        #expect(Sport.rugbyLeague.rawValue == "rugbyLeague")
    }

    // MARK: - On-field counts

    @Test func onFieldCounts() {
        #expect(Sport.basketball.rules.onFieldCount == 5)
        #expect(Sport.netball.rules.onFieldCount == 7)
        #expect(Sport.soccer.rules.onFieldCount == 11)
        #expect(Sport.afl.rules.onFieldCount == 18)
        #expect(Sport.rugbyUnion.rules.onFieldCount == 15)
        #expect(Sport.rugbyLeague.rules.onFieldCount == 13)
    }

    // MARK: - Period structure

    @Test func periodStructure() {
        let quarters: [Sport] = [.basketball, .netball, .afl]
        let halves: [Sport] = [.soccer, .rugbyUnion, .rugbyLeague]
        for sport in quarters {
            #expect(sport.rules.periodFormat == "quarters")
            #expect(sport.rules.periodCount == 4)
        }
        for sport in halves {
            #expect(sport.rules.periodFormat == "halves")
            #expect(sport.rules.periodCount == 2)
        }
        #expect(Sport.basketball.rules.defaultPeriodMinutes == 10)
        #expect(Sport.netball.rules.defaultPeriodMinutes == 15)
        #expect(Sport.soccer.rules.defaultPeriodMinutes == 45)
        #expect(Sport.afl.rules.defaultPeriodMinutes == 20)
        #expect(Sport.rugbyUnion.rules.defaultPeriodMinutes == 40)
        #expect(Sport.rugbyLeague.rules.defaultPeriodMinutes == 40)
    }

    // MARK: - Exact scoring values

    @Test func basketballScoring() {
        let scoring = Sport.basketball.rules.scoringActions
        #expect(scoring.first { $0.code == "freeThrow" }?.points == 1)
        #expect(scoring.first { $0.code == "fieldGoal" }?.points == 2)
        #expect(scoring.first { $0.code == "threePointer" }?.points == 3)
    }

    @Test func netballAndSoccerScoreOnePoint() {
        #expect(Sport.netball.rules.scoringActions.map(\.points) == [1])
        #expect(Sport.soccer.rules.scoringActions.map(\.points) == [1])
    }

    @Test func aflScoring() {
        let scoring = Sport.afl.rules.scoringActions
        #expect(scoring.first { $0.code == "goal" }?.points == 6)
        #expect(scoring.first { $0.code == "behind" }?.points == 1)
    }

    @Test func rugbyUnionScoring() {
        let scoring = Sport.rugbyUnion.rules.scoringActions
        #expect(scoring.first { $0.code == "try" }?.points == 5)
        #expect(scoring.first { $0.code == "conversion" }?.points == 2)
        #expect(scoring.first { $0.code == "penaltyGoal" }?.points == 3)
        #expect(scoring.first { $0.code == "dropGoal" }?.points == 3)
    }

    @Test func rugbyLeagueScoring() {
        let scoring = Sport.rugbyLeague.rules.scoringActions
        #expect(scoring.first { $0.code == "try" }?.points == 4)
        #expect(scoring.first { $0.code == "conversion" }?.points == 2)
        #expect(scoring.first { $0.code == "penaltyGoal" }?.points == 2)
        #expect(scoring.first { $0.code == "fieldGoal" }?.points == 1)
    }

    // MARK: - Removal semantics

    @Test func sinBinIsTenMinuteTemporaryRemoval() {
        for sport in [Sport.rugbyUnion, .rugbyLeague] {
            let sinBin = sport.rules.disciplineAction(forCode: "sinBin")
            #expect(sinBin?.removal == .temporary(seconds: 600))
        }
    }

    @Test func sendOffAndRedCardArePermanent() {
        #expect(Sport.rugbyUnion.rules.disciplineAction(forCode: "sendOff")?.removal == .permanent)
        #expect(Sport.rugbyLeague.rules.disciplineAction(forCode: "sendOff")?.removal == .permanent)
        #expect(Sport.soccer.rules.disciplineAction(forCode: "redCard")?.removal == .permanent)
    }

    @Test func basketballFoulHasNoRemoval() {
        let removal = Sport.basketball.rules.disciplineAction(forCode: "foul")?.removal
        #expect(removal == Removal.none)
    }

    // MARK: - Uniqueness

    @Test func actionCodesAreUniquePerSport() {
        for sport in Sport.allCases {
            let scoringCodes = sport.rules.scoringActions.map(\.code)
            #expect(Set(scoringCodes).count == scoringCodes.count)
            let disciplineCodes = sport.rules.disciplineActions.map(\.code)
            #expect(Set(disciplineCodes).count == disciplineCodes.count)
        }
    }

    @Test func positionCodesAreUniquePerSport() {
        for sport in Sport.allCases {
            let codes = sport.rules.positions.map(\.code)
            #expect(Set(codes).count == codes.count)
        }
    }

    @Test func basketballHasNoPositions() {
        #expect(Sport.basketball.rules.positions.isEmpty)
        #expect(Sport.basketball.rules.hasPositions == false)
    }

    @Test func newSportsHavePositions() {
        for sport in [Sport.netball, .soccer, .afl, .rugbyUnion, .rugbyLeague] {
            #expect(sport.rules.hasPositions)
        }
    }
}
