import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RosterView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Player.name) private var players: [Player]

    @State private var showAddPlayer = false
    @State private var editingPlayer: Player?
    @State private var showImportPicker = false
    @State private var searchText = ""
    @State private var importError: String?
    @State private var showImportError = false
    @State private var importSummary: String?

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
                    ShareLink(item: rosterExport, preview: SharePreview(rosterExport.filename, image: Image(systemName: "tablecells"))) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Import or export")
                Button { showAddPlayer = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add player")
            }
        }
        .sheet(isPresented: $showAddPlayer) {
            PlayerEditView(player: nil)
        }
        .sheet(item: $editingPlayer) { player in
            PlayerEditView(player: player)
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            handleImport(result: result)
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
        .alert("Import Complete", isPresented: Binding(get: { importSummary != nil }, set: { if !$0 { importSummary = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importSummary ?? "")
        }
    }

    private func deletePlayers(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredPlayers[index])
        }
    }

    private var rosterExport: CSVExportFile {
        var lines = ["Name,Jersey Number"]
        for player in players {
            let jersey = player.jerseyNumber.map { String($0) } ?? ""
            lines.append("\(RosterCSV.escape(player.name)),\(jersey)")
        }
        return CSVExportFile(filename: "Basketball_Roster.csv", content: lines.joined(separator: "\n"))
    }

    private func handleImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let content = try RosterCSV.readImportedFile(at: url)
                let parsed = RosterCSV.parse(content)
                guard !parsed.isEmpty else {
                    importError = "No players were found in that file. Make sure it has a Name column."
                    showImportError = true
                    return
                }
                let existing = players.map { RosterCSV.PlayerKey(name: $0.name, jerseyNumber: $0.jerseyNumber) }
                let plan = RosterCSV.importPlan(for: parsed, existing: existing)
                for player in plan.toAdd {
                    modelContext.insert(Player(name: player.name, jerseyNumber: player.jerseyNumber))
                }
                importSummary = RosterCSV.importSummary(plan)
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        }
    }
}
