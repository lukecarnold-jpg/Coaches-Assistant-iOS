import Testing
@testable import Basketball_Rotation

/// Covers the additive Position column on `RosterCSV` used by the new sports'
/// roster import/export. Basketball's own CSVs never carry this column —
/// `RosterCSVTests` (unedited) proves files without it still parse identically.
struct SquadRosterCSVTests {
    @Test func parsesPositionColumnWhenPresent() {
        let csv = "Name,Jersey Number,Position\nJordan,23,SF\nPippen,33,SG"
        let players = RosterCSV.parse(csv)
        #expect(players == [
            .init(name: "Jordan", jerseyNumber: 23, positionCode: "SF"),
            .init(name: "Pippen", jerseyNumber: 33, positionCode: "SG"),
        ])
    }

    @Test func filesWithoutPositionColumnStillParse() {
        let csv = "Name,Jersey Number\nCurry,30"
        let players = RosterCSV.parse(csv)
        #expect(players == [.init(name: "Curry", jerseyNumber: 30, positionCode: nil)])
    }

    @Test func blankPositionCellBecomesNilNotEmptyString() {
        let csv = "Name,Jersey Number,Position\nThompson,11,"
        let players = RosterCSV.parse(csv)
        #expect(players == [.init(name: "Thompson", jerseyNumber: 11, positionCode: nil)])
    }

    @Test func toleratesShortPosHeader() {
        let csv = "Name,Pos\nGreen,23"
        let players = RosterCSV.parse(csv)
        #expect(players == [.init(name: "Green", jerseyNumber: nil, positionCode: "23")])
    }
}
