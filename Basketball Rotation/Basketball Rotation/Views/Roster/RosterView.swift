import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RosterView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Player.name) private var players: [Player]

    @State private var showAddPlayer = false
    @State private var editingPlayer: Player?
    @State private var showImportPicker = false
    @State private var showExportSheet = false
    @State private var csvExportContent = ""
    @State private var searchText = ""
    @State private var importError: String?
    @State private var showImportError = false

    var filteredPlayers: [Player] {
        if searchText.isEmpty { return players }
        return players.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if players.isEmpty {
                ContentUnavailableView("No Players", systemImage: "person.slash", description: Text("Add players to your roster to get started."))
            } else {
                List {
                    ForEach(filteredPlayers) { player in
                        Button {
                            editingPlayer = player
                        } label: {
                            HStack {
                                if let num = player.jerseyNumber {
                                    Text("#\(num)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 36, alignment: .leading)
                                }
                                Text(player.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                                    .font(.caption)
                            }
                        }
                    }
                    .onDelete(perform: deletePlayers)
                }
                .searchable(text: $searchText, prompt: "Search players")
            }
        }
        .navigationTitle("Roster")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button { showImportPicker = true } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }
                    Button { exportCSV() } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                Button { showAddPlayer = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddPlayer) {
            PlayerEditView(player: nil)
        }
        .sheet(item: $editingPlayer) { player in
            PlayerEditView(player: player)
        }
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(items: [csvExportContent])
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            handleImport(result: result)
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    private func deletePlayers(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredPlayers[index])
        }
    }

    private func exportCSV() {
        var lines = ["Name,Jersey Number"]
        for player in players {
            let jersey = player.jerseyNumber.map { String($0) } ?? ""
            lines.append("\(csvEscape(player.name)),\(jersey)")
        }
        csvExportContent = lines.joined(separator: "\n")
        showExportSheet = true
    }

    private func handleImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                parseAndImportCSV(content)
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        }
    }

    private func parseAndImportCSV(_ content: String) {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return }

        let header = lines[0].lowercased()
        let nameIndex = csvColumnIndex(header: header, candidates: ["name", "player"]) ?? 0
        let jerseyIndex = csvColumnIndex(header: header, candidates: ["jersey", "number", "#"])

        for line in lines.dropFirst() {
            let cols = csvParseLine(line)
            guard cols.indices.contains(nameIndex) else { continue }
            let name = cols[nameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let jerseyNum: Int? = jerseyIndex.flatMap { cols.indices.contains($0) ? Int(cols[$0].trimmingCharacters(in: .whitespacesAndNewlines)) : nil }
            modelContext.insert(Player(name: name, jerseyNumber: jerseyNum))
        }
    }

    private func csvColumnIndex(header: String, candidates: [String]) -> Int? {
        let cols = csvParseLine(header)
        for (i, col) in cols.enumerated() {
            let trimmed = col.trimmingCharacters(in: .whitespacesAndNewlines)
            if candidates.contains(where: { trimmed.contains($0) }) { return i }
        }
        return nil
    }

    private func csvParseLine(_ line: String) -> [String] {
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

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
