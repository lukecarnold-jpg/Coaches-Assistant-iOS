import SwiftUI
import SwiftData

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var players: [Player]
    @Query private var games: [Game]
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""

    @State private var showClearConfirm = false
    @State private var showClearSuccess = false
    @State private var showAPIKeyInput = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
            }

            Section {
                Button {
                    showAPIKeyInput = true
                } label: {
                    Label(geminiAPIKey.isEmpty ? "Add API Key" : "Update API Key", systemImage: "key")
                }
            } header: {
                Text("Training")
            } footer: {
                Text("A Gemini API key is required to generate basketball drills. It is stored locally on this device.")
            }

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
        .sheet(isPresented: $showAPIKeyInput) {
            APIKeyInputView(apiKey: $geminiAPIKey)
        }
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
