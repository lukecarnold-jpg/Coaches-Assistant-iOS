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
            lines.append("\(RosterCSV.escape(player.name)),\(jersey)")
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
                for parsed in RosterCSV.parse(content) {
                    modelContext.insert(Player(name: parsed.name, jerseyNumber: parsed.jerseyNumber))
                }
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
