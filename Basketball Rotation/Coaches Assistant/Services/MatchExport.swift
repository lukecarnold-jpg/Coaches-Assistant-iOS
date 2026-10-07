import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Pure builders for match exports, kept out of the views so they can be unit tested.
enum MatchExport {
    struct EventRow {
        let period: String
        let time: String
        let event: String
        let player: String
        let detail: String
    }

    /// Every field is escaped with `RosterCSV.escape`, so commas, quotes and line
    /// breaks in names, details or notes can't shift columns.
    static func eventsCSV(rows: [EventRow], notes: String) -> String {
        var lines = ["Period,Time,Event,Player,Detail"]
        for row in rows {
            lines.append([row.period, row.time, row.event, row.player, row.detail].map(RosterCSV.escape).joined(separator: ","))
        }
        if !notes.isEmpty {
            lines.append("")
            lines.append("Coaching Notes")
            lines.append(RosterCSV.escape(notes))
        }
        return lines.joined(separator: "\n")
    }

    static func notesText(title: String, opponentName: String, date: Date, notes: String) -> String {
        let header = "\(title) – vs \(opponentName) – \(date.formatted(date: .long, time: .omitted))\n\n"
        return header + (notes.isEmpty ? "No notes." : notes)
    }

    /// Restricts a string to characters safe in a filename (letters, digits, `_`, `-`).
    static func safeFilenameComponent(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "[^a-zA-Z0-9_\\-]", with: "_", options: .regularExpression)
    }

    /// e.g. ("Game_Events", "Wildcats", "csv") → "Game_Events_vs_Wildcats.csv".
    static func filename(prefix: String, opponentName: String, ext: String) -> String {
        let opponent = safeFilenameComponent(opponentName)
        return opponent.isEmpty ? "\(prefix).\(ext)" : "\(prefix)_vs_\(opponent).\(ext)"
    }

    /// Writes into a per-export folder in the temp directory so the shared file keeps
    /// its friendly name without clobbering another export of the same name.
    nonisolated static func writeTemporaryFile(filename: String, content: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Exports", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(filename)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

/// A CSV file that's only written to disk when the user actually shares it —
/// so building the share menu (which happens on every view update) is cheap.
nonisolated struct CSVExportFile: Transferable {
    let filename: String
    let content: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            SentTransferredFile(try MatchExport.writeTemporaryFile(filename: file.filename, content: file.content))
        }
    }
}

/// Plain-text counterpart of `CSVExportFile`.
nonisolated struct TextExportFile: Transferable {
    let filename: String
    let content: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { file in
            SentTransferredFile(try MatchExport.writeTemporaryFile(filename: file.filename, content: file.content))
        }
    }
}
