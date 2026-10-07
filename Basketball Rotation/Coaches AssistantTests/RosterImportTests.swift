import Testing
import Foundation
@testable import Coaches_Assistant

struct RosterImportTests {
    @Test func handlesEscapedQuotesAndEmbeddedNewlines() {
        let csv = "Name,Jersey\n\"Sam \"\"Ace\"\" Jones\",4\n\"Two\nLines\",5"
        let players = RosterCSV.parse(csv)
        #expect(players == [
            .init(name: "Sam \"Ace\" Jones", jerseyNumber: 4),
            .init(name: "Two\nLines", jerseyNumber: 5),
        ])
    }

    @Test func handlesWindowsLineEndings() {
        let players = RosterCSV.parse("Name,Jersey Number\r\nJordan,23\r\nPippen,33\r\n")
        #expect(players.map(\.name) == ["Jordan", "Pippen"])
    }

    @Test func headerlessFileKeepsFirstPlayer() {
        let players = RosterCSV.parse("Jordan,23\nPippen,33")
        #expect(players == [.init(name: "Jordan", jerseyNumber: 23), .init(name: "Pippen", jerseyNumber: 33)])
    }

    @Test func playerNamesAreNotMistakenForHeaders() {
        // "Posey" contains "pos" but isn't a Position header.
        let players = RosterCSV.parse("Jo Posey,7\nAl Num,8")
        #expect(players.map(\.name) == ["Jo Posey", "Al Num"])
    }

    @Test func jerseyWithHashPrefixParses() {
        #expect(RosterCSV.parse("Name,#\nCurry,#30") == [.init(name: "Curry", jerseyNumber: 30)])
    }

    @Test func importPlanSkipsExistingAndInFileDuplicates() {
        let parsed: [RosterCSV.ParsedPlayer] = [
            .init(name: "Jordan", jerseyNumber: 23),
            .init(name: "jordan ", jerseyNumber: 23),   // same as above
            .init(name: "Pippen", jerseyNumber: 33),     // already on roster
            .init(name: "Pippen", jerseyNumber: 8),      // different number → new
        ]
        let plan = RosterCSV.importPlan(for: parsed, existing: [.init(name: "Pippen", jerseyNumber: 33)])
        #expect(plan.toAdd.map(\.name) == ["Jordan", "Pippen"])
        #expect(plan.toAdd.last?.jerseyNumber == 8)
        #expect(plan.duplicateCount == 2)
        #expect(RosterCSV.importSummary(plan) == "Imported 2 players. Skipped 2 already on the roster.")
    }

    @Test func escapeQuotesCarriageReturns() {
        #expect(RosterCSV.escape("a\rb") == "\"a\rb\"")
    }
}
