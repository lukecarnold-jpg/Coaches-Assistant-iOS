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
    @AppStorage("selectedAIProvider") private var selectedProviderRaw = AIProvider.gemini.rawValue
    @State private var keyStore = AIAPIKeyStore.shared

    @State private var showClearConfirm = false
    @State private var showClearSuccess = false
    @State private var editingProvider: AIProvider?

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
                Picker("Provider", selection: $selectedProviderRaw) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
                ForEach(AIProvider.allCases) { provider in
                    Button {
                        editingProvider = provider
                    } label: {
                        HStack {
                            Label(provider.displayName, systemImage: "key")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(keyStore.isConfigured(provider) ? "Configured" : "Not Set")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("AI Drill Generator")
            } footer: {
                Text("Choose which provider generates drills and add its API key. Keys are stored securely in the Keychain on this device.")
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
        .sheet(item: $editingProvider) { provider in
            if provider == .custom {
                CustomProviderConfigView(currentKey: keyStore.apiKey(for: provider)) { newValue in
                    keyStore.setAPIKey(newValue, for: provider)
                }
            } else {
                APIKeyInputView(provider: provider, currentKey: keyStore.apiKey(for: provider)) { newValue in
                    keyStore.setAPIKey(newValue, for: provider)
                }
            }
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
