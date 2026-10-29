import Testing
import Foundation
@testable import Coaches_Assistant

@MainActor
struct MatchExportTests {
    @Test func eventsCSVEscapesEveryField() {
        let rows = [
            MatchExport.EventRow(period: "Q1", time: "02:15", event: "Hawks, Inc Score", player: "Smith, Jr.", detail: "said \"wow\""),
        ]
        let csv = MatchExport.eventsCSV(rows: rows, notes: "Line one\nLine, two")
        let lines = RosterCSV.parseRows(csv)
        #expect(lines[0] == ["Period", "Time", "Event", "Player", "Detail"])
        #expect(lines[1] == ["Q1", "02:15", "Hawks, Inc Score", "Smith, Jr.", "said \"wow\""])
        #expect(lines.last == ["Line one\nLine, two"])
    }

    @Test func filenamesAreSanitised() {
        #expect(MatchExport.filename(prefix: "Game_Events", opponentName: "St. Mary's", ext: "csv") == "Game_Events_vs_St__Mary_s.csv")
        #expect(MatchExport.filename(prefix: "Game_Notes", opponentName: "  ", ext: "txt") == "Game_Notes.txt")
    }

    @Test func writesExportToUniqueTemporaryFile() throws {
        let first = try MatchExport.writeTemporaryFile(filename: "Same.csv", content: "a")
        let second = try MatchExport.writeTemporaryFile(filename: "Same.csv", content: "b")
        defer {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }
        #expect(first != second)
        #expect(first.lastPathComponent == "Same.csv")
        #expect(try String(contentsOf: first, encoding: .utf8) == "a")
        #expect(try String(contentsOf: second, encoding: .utf8) == "b")
    }
}
