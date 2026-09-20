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
        #expect(Sport.iceHockey.rawValue == "iceHockey")
        #expect(Sport.fieldHockey.rawValue == "fieldHockey")
        #expect(Sport.teamHandball.rawValue == "teamHandball")
        #expect(Sport.waterPolo.rawValue == "waterPolo")
        #expect(Sport.lacrosse.rawValue == "lacrosse")
        #expect(Sport.flagFootball.rawValue == "flagFootball")
        #expect(Sport.futsal.rawValue == "futsal")
        #expect(Sport.volleyball.rawValue == "volleyball")
        #expect(Sport.touchFootball.rawValue == "touchFootball")
    }

    // MARK: - On-field counts

    @Test func onFieldCounts() {
        #expect(Sport.basketball.rules.onFieldCount == 5)
        #expect(Sport.netball.rules.onFieldCount == 7)
        #expect(Sport.soccer.rules.onFieldCount == 11)
        #expect(Sport.afl.rules.onFieldCount == 18)
        #expect(Sport.rugbyUnion.rules.onFieldCount == 15)
        #expect(Sport.rugbyLeague.rules.onFieldCount == 13)
        #expect(Sport.iceHockey.rules.onFieldCount == 6)
        #expect(Sport.fieldHockey.rules.onFieldCount == 11)
        #expect(Sport.teamHandball.rules.onFieldCount == 7)
        #expect(Sport.waterPolo.rules.onFieldCount == 7)
        #expect(Sport.lacrosse.rules.onFieldCount == 10)
        #expect(Sport.flagFootball.rules.onFieldCount == 5)
        #expect(Sport.futsal.rules.onFieldCount == 5)
        #expect(Sport.volleyball.rules.onFieldCount == 6)
        #expect(Sport.touchFootball.rules.onFieldCount == 6)
    }

    // MARK: - Period structure

    @Test func periodStructure() {
        let quarters: [Sport] = [.basketball, .netball, .afl, .iceHockey, .fieldHockey, .waterPolo, .lacrosse]
        let halves: [Sport] = [.soccer, .rugbyUnion, .rugbyLeague, .teamHandball, .flagFootball, .futsal, .volleyball, .touchFootball]
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
        #expect(Sport.iceHockey.rules.defaultPeriodMinutes == 15)
        #expect(Sport.fieldHockey.rules.defaultPeriodMinutes == 15)
        #expect(Sport.teamHandball.rules.defaultPeriodMinutes == 30)
        #expect(Sport.waterPolo.rules.defaultPeriodMinutes == 8)
        #expect(Sport.lacrosse.rules.defaultPeriodMinutes == 15)
        #expect(Sport.flagFootball.rules.defaultPeriodMinutes == 20)
        #expect(Sport.futsal.rules.defaultPeriodMinutes == 20)
        #expect(Sport.volleyball.rules.defaultPeriodMinutes == 25)
        #expect(Sport.touchFootball.rules.defaultPeriodMinutes == 20)
    }

    // MARK: - Exact scoring values

    @Test func basketballScoring() {
        let scoring = Sport.basketball.rules.scoringActions
        #expect(scoring.first { $0.code == "freeThrow" }?.points == 1)
        #expect(scoring.first { $0.code == "fieldGoal" }?.points == 2)
        #expect(scoring.first { $0.code == "threePointer" }?.points == 3)
    }

    @Test func singlePointGoalSports() {
        let singlePointSports: [Sport] = [.netball, .soccer, .iceHockey, .fieldHockey, .teamHandball, .waterPolo, .futsal, .volleyball, .touchFootball]
        for sport in singlePointSports {
            #expect(sport.rules.scoringActions.first?.points == 1)
        }
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

    @Test func flagFootballScoring() {
        let scoring = Sport.flagFootball.rules.scoringActions
        #expect(scoring.first { $0.code == "touchdown" }?.points == 6)
        #expect(scoring.first { $0.code == "extraPoint1" }?.points == 1)
        #expect(scoring.first { $0.code == "extraPoint2" }?.points == 2)
        #expect(scoring.first { $0.code == "safety" }?.points == 2)
    }

    @Test func lacrosseScoring() {
        let scoring = Sport.lacrosse.rules.scoringActions
        #expect(scoring.first { $0.code == "goal" }?.points == 1)
        #expect(scoring.first { $0.code == "twoPointGoal" }?.points == 2)
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
        #expect(Sport.teamHandball.rules.disciplineAction(forCode: "redCard")?.removal == .permanent)
        #expect(Sport.touchFootball.rules.disciplineAction(forCode: "sendOff")?.removal == .permanent)
    }

    @Test func temporarySuspensionRemovals() {
        #expect(Sport.iceHockey.rules.disciplineAction(forCode: "minorPenalty")?.removal == .temporary(seconds: 120))
        #expect(Sport.iceHockey.rules.disciplineAction(forCode: "majorPenalty")?.removal == .temporary(seconds: 300))
        #expect(Sport.fieldHockey.rules.disciplineAction(forCode: "greenCard")?.removal == .temporary(seconds: 120))
        #expect(Sport.fieldHockey.rules.disciplineAction(forCode: "yellowCard")?.removal == .temporary(seconds: 300))
        #expect(Sport.teamHandball.rules.disciplineAction(forCode: "twoMinuteSuspension")?.removal == .temporary(seconds: 120))
        #expect(Sport.waterPolo.rules.disciplineAction(forCode: "exclusion")?.removal == .temporary(seconds: 20))
        #expect(Sport.lacrosse.rules.disciplineAction(forCode: "technicalFoul")?.removal == .temporary(seconds: 30))
        #expect(Sport.lacrosse.rules.disciplineAction(forCode: "personalFoul")?.removal == .temporary(seconds: 60))
        #expect(Sport.futsal.rules.disciplineAction(forCode: "redCard")?.removal == .temporary(seconds: 120))
        #expect(Sport.touchFootball.rules.disciplineAction(forCode: "sinBin")?.removal == .temporary(seconds: 240))
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

    @Test func nonBasketballSportsHavePositions() {
        for sport in Sport.allCases where sport != .basketball {
            #expect(sport.rules.hasPositions, "Expected positions for \(sport.rawValue)")
        }
    }
}
