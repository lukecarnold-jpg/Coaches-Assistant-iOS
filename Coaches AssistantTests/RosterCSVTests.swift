import Testing
import Foundation
@testable import Coaches_Assistant

struct RosterCSVTests {
    @Test func parsesNameAndJerseyColumns() {
        let csv = "Name,Jersey Number\nJordan,23\nPippen,33"
        let players = RosterCSV.parse(csv)
        #expect(players == [
            .init(name: "Jordan", jerseyNumber: 23),
            .init(name: "Pippen", jerseyNumber: 33)
        ])
    }

    @Test func handlesQuotedCommasInNames() {
        let csv = "Name,Jersey Number\n\"Smith, Jr.\",7"
        let players = RosterCSV.parse(csv)
        #expect(players == [.init(name: "Smith, Jr.", jerseyNumber: 7)])
    }

    @Test func toleratesReorderedAndAlternatelyNamedColumns() {
        let csv = "Jersey,Player\n10,Curry"
        let players = RosterCSV.parse(csv)
        #expect(players == [.init(name: "Curry", jerseyNumber: 10)])
    }

    @Test func skipsBlankNamesAndAllowsMissingJersey() {
        let csv = "Name,Jersey Number\n,5\nThompson,"
        let players = RosterCSV.parse(csv)
        #expect(players == [.init(name: "Thompson", jerseyNumber: nil)])
    }

    @Test func headerOnlyProducesNoPlayers() {
        #expect(RosterCSV.parse("Name,Jersey Number").isEmpty)
    }

    @Test func emptyContentProducesNoPlayers() {
        #expect(RosterCSV.parse("").isEmpty)
    }

    @Test func escapesValuesContainingCommasOrQuotes() {
        #expect(RosterCSV.escape("Smith, Jr.") == "\"Smith, Jr.\"")
        #expect(RosterCSV.escape("Sam \"Ace\" Jones") == "\"Sam \"\"Ace\"\" Jones\"")
        #expect(RosterCSV.escape("Curry") == "Curry")
    }

    @Test func createsTemporaryFileWithCorrectContentAndExtension() throws {
        let filename = "Test_Roster.csv"
        let sampleContent = "Name,Jersey Number\nJordan,23"
        guard let url = RosterCSV.createTemporaryFile(filename: filename, content: sampleContent) else {
            Issue.record("Failed to create temporary file")
            return
        }
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.lastPathComponent == filename)
        #expect(url.pathExtension == "csv")
        #expect(FileManager.default.fileExists(atPath: url.path))

        let readContent = try String(contentsOf: url, encoding: .utf8)
        #expect(readContent == sampleContent)
    }
}
