import Foundation

/// Pure CSV parsing/escaping for roster import & export, split out of `RosterView` so
/// the parsing logic can be unit tested without a SwiftUI/SwiftData context.
enum RosterCSV {
    struct ParsedPlayer: Equatable {
        let name: String
        let jerseyNumber: Int?
        // Only populated for the new-sport rosters, which have positions;
        // Basketball's CSVs have no Position column and this stays nil.
        let positionCode: String?

        init(name: String, jerseyNumber: Int? = nil, positionCode: String? = nil) {
            self.name = name
            self.jerseyNumber = jerseyNumber
            self.positionCode = positionCode
        }
    }

    static func parse(_ content: String) -> [ParsedPlayer] {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }

        let header = lines[0].lowercased()
        let nameIndex = columnIndex(header: header, candidates: ["name", "player"]) ?? 0
        let jerseyIndex = columnIndex(header: header, candidates: ["jersey", "number", "#"])
        let positionIndex = columnIndex(header: header, candidates: ["position", "pos"])

        var result: [ParsedPlayer] = []
        for line in lines.dropFirst() {
            let cols = parseLine(line)
            guard cols.indices.contains(nameIndex) else { continue }
            let name = cols[nameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let jerseyNum: Int? = jerseyIndex.flatMap { cols.indices.contains($0) ? Int(cols[$0].trimmingCharacters(in: .whitespacesAndNewlines)) : nil }
            let position: String? = positionIndex.flatMap { cols.indices.contains($0) ? cols[$0].trimmingCharacters(in: .whitespacesAndNewlines) : nil }
            result.append(ParsedPlayer(name: name, jerseyNumber: jerseyNum, positionCode: (position?.isEmpty ?? true) ? nil : position))
        }
        return result
    }

    static func columnIndex(header: String, candidates: [String]) -> Int? {
        let cols = parseLine(header)
        for (i, col) in cols.enumerated() {
            let trimmed = col.trimmingCharacters(in: .whitespacesAndNewlines)
            if candidates.contains(where: { trimmed.contains($0) }) { return i }
        }
        return nil
    }

    static func parseLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" { inQuotes.toggle() }
            else if char == "," && !inQuotes { result.append(current); current = "" }
            else { current.append(char) }
        }
        result.append(current)
        return result
    }

    static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    /// Writes exported text content (CSV or TXT) to a file URL in the temporary directory
    /// so system activities (Save to Files, AirDrop, Mail) treat it as a real file with a proper extension.
    static func createTemporaryFile(filename: String, content: String) -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }
}
