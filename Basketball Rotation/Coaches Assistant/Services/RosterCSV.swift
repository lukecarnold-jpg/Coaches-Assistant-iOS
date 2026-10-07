import Foundation

/// Pure CSV parsing/escaping for roster import & export, split out of `RosterView` so
/// the parsing logic can be unit tested without a SwiftUI/SwiftData context.
nonisolated enum RosterCSV {
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

    /// Identity used to skip players already on the roster: case-insensitive name
    /// plus jersey number (so two different "Sam"s with different numbers both import).
    struct PlayerKey: Hashable {
        let name: String
        let jerseyNumber: Int?

        init(name: String, jerseyNumber: Int?) {
            self.name = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            self.jerseyNumber = jerseyNumber
        }
    }

    struct ImportPlan: Equatable {
        let toAdd: [ParsedPlayer]
        let duplicateCount: Int
    }

    // Matched against whole words in a header cell, so a player named "Jo Posey"
    // in a header-less file isn't mistaken for a "pos" column.
    private static let nameCandidates = ["name", "player"]
    private static let jerseyCandidates = ["jersey", "number", "#", "no", "num"]
    private static let positionCandidates = ["position", "pos"]

    static func parse(_ content: String) -> [ParsedPlayer] {
        let rows = parseRows(content).filter { row in
            row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        guard let first = rows.first else { return [] }

        let header = first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let headerName = columnIndex(in: header, candidates: nameCandidates)
        let headerJersey = columnIndex(in: header, candidates: jerseyCandidates, excluding: headerName)
        let headerPosition = columnIndex(in: header, candidates: positionCandidates, excluding: headerName)
        // Header cells are words; a first row containing a plain number (a jersey)
        // is data even if a name happens to look like a header word ("Al Num").
        let firstRowHasNumber = header.contains { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "#"))) != nil }
        let hasHeader = !firstRowHasNumber && (headerName != nil || headerJersey != nil || headerPosition != nil)

        // Without a recognisable header, assume "Name, Jersey, Position" order and
        // treat the first row as a player rather than silently dropping it.
        let nameIndex = hasHeader ? (headerName ?? 0) : 0
        let jerseyIndex: Int? = hasHeader ? headerJersey : 1
        let positionIndex: Int? = hasHeader ? headerPosition : 2
        let dataRows = hasHeader ? Array(rows.dropFirst()) : rows

        var result: [ParsedPlayer] = []
        for cols in dataRows {
            func value(_ index: Int?) -> String? {
                guard let index, cols.indices.contains(index) else { return nil }
                let trimmed = cols[index].trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            guard let name = value(nameIndex) else { continue }
            let jersey = value(jerseyIndex).flatMap { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "#"))) }
            result.append(ParsedPlayer(name: name, jerseyNumber: jersey, positionCode: value(positionIndex)))
        }
        return result
    }

    /// Splits parsed rows into new players and duplicates of `existing` (or of each
    /// other within the same file), so re-importing a file doesn't double the roster.
    static func importPlan(for parsed: [ParsedPlayer], existing: [PlayerKey]) -> ImportPlan {
        var seen = Set(existing)
        var toAdd: [ParsedPlayer] = []
        var duplicates = 0
        for player in parsed {
            let key = PlayerKey(name: player.name, jerseyNumber: player.jerseyNumber)
            if seen.insert(key).inserted {
                toAdd.append(player)
            } else {
                duplicates += 1
            }
        }
        return ImportPlan(toAdd: toAdd, duplicateCount: duplicates)
    }

    static func importSummary(_ plan: ImportPlan) -> String {
        var parts = ["Imported \(plan.toAdd.count) player\(plan.toAdd.count == 1 ? "" : "s")."]
        if plan.duplicateCount > 0 {
            parts.append("Skipped \(plan.duplicateCount) already on the roster.")
        }
        return parts.joined(separator: " ")
    }

    static func columnIndex(header: String, candidates: [String]) -> Int? {
        let cols = (parseRows(header).first ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return columnIndex(in: cols, candidates: candidates)
    }

    private static func columnIndex(in header: [String], candidates: [String], excluding excluded: Int? = nil) -> Int? {
        for (i, col) in header.enumerated() where i != excluded {
            let words = Set(col.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "#")).inverted).filter { !$0.isEmpty })
            if candidates.contains(where: { words.contains($0) }) { return i }
        }
        return nil
    }

    /// RFC 4180-style parsing: handles quoted fields containing commas, escaped
    /// quotes (`""`) and line breaks, and both `\n` and `\r\n` line endings.
    static func parseRows(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = Array(content.unicodeScalars).makeIterator()
        var pending: Unicode.Scalar? = iterator.next()

        while let char = pending {
            pending = iterator.next()
            if inQuotes {
                if char == "\"" {
                    if pending == "\"" {
                        field.unicodeScalars.append("\"")
                        pending = iterator.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.unicodeScalars.append(char)
                }
                continue
            }
            switch char {
            case "\"":
                inQuotes = true
            case ",":
                row.append(field)
                field = ""
            case "\r":
                if pending == "\n" { pending = iterator.next() }
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            case "\n":
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            default:
                field.unicodeScalars.append(char)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    /// Parses a single CSV line. Kept for callers that already have one line.
    static func parseLine(_ line: String) -> [String] {
        parseRows(line).first ?? [""]
    }

    static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
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

    /// Reads an imported file, handling sandboxed (security-scoped) and in-app URLs
    /// alike. `startAccessingSecurityScopedResource()` returns false for URLs that
    /// don't need it, which isn't an error.
    static func readImportedFile(at url: URL) throws -> String {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
