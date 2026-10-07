import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Roster for one sport, with search and CSV import/export. The Position column
/// is optional, so position-less (e.g. Basketball) CSVs import unchanged.
struct SquadRosterView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var players: [SquadPlayer]

    let sport: Sport

    @State private var showAddPlayer = false
    @State private var editingPlayer: SquadPlayer?
    @State private var showImportPicker = false
    @State private var searchText = ""
    @State private var importError: String?
    @State private var showImportError = false
    @State private var importSummary: String?

    init(sport: Sport) {
        self.sport = sport
        let raw = sport.rawValue
        _players = Query(filter: #Predicate<SquadPlayer> { $0.sport == raw }, sort: \SquadPlayer.name)
    }

    var filteredPlayers: [SquadPlayer] {
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
                                if let position = player.preferredPosition {
                                    Text(position.code)
                                        .font(.caption.bold())
                                        .foregroundStyle(sport.tint)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(sport.tint.opacity(0.15), in: Capsule())
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.listRow)
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
            SquadPlayerEditView(sport: sport, player: nil)
        }
        .sheet(item: $editingPlayer) { player in
            SquadPlayerEditView(sport: sport, player: player)
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
        var lines = ["Name,Jersey Number,Position"]
        for player in players {
            let jersey = player.jerseyNumber.map { String($0) } ?? ""
            lines.append("\(RosterCSV.escape(player.name)),\(jersey),\(RosterCSV.escape(player.preferredPositionCode))")
        }
        let safeSport = MatchExport.safeFilenameComponent(sport.rules.displayName)
        return CSVExportFile(filename: "\(safeSport)_Roster.csv", content: lines.joined(separator: "\n"))
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
                    // Only keep position codes this sport actually defines.
                    let code = player.positionCode.flatMap { sport.rules.position(forCode: $0.uppercased())?.code } ?? ""
                    modelContext.insert(SquadPlayer(sport: sport, name: player.name, jerseyNumber: player.jerseyNumber, preferredPositionCode: code))
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
