import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var players: [Player]
    @Query private var games: [Game]

    @State private var showClearConfirm = false
    @State private var showClearSuccess = false

    var body: some View {
        Form {
            Section("Data") {
                HStack {
                    Text("Players")
                    Spacer()
                    Text("\(players.count)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Games")
                    Spacer()
                    Text("\(games.count)")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Clear All Data")
                        Spacer()
                    }
                }
            } footer: {
                Text("This permanently removes all players, games, events, and notes from this device.")
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Storage")
                    Spacer()
                    Text("Local only")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Clear All Data", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear Everything", role: .destructive) {
                clearAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. All players, games, and history will be deleted.")
        }
        .alert("Data Cleared", isPresented: $showClearSuccess) {
            Button("OK") {}
        } message: {
            Text("All data has been removed from this device.")
        }
    }

    private func clearAllData() {
        do {
            try modelContext.delete(model: GameEvent.self)
            try modelContext.delete(model: GameAttendance.self)
            try modelContext.delete(model: Game.self)
            try modelContext.delete(model: Player.self)
            showClearSuccess = true
        } catch {
            print("Failed to clear data: \(error)")
        }
    }
}
