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
    @Query private var squadPlayers: [SquadPlayer]
    @Query private var fixtures: [Fixture]
    @Query private var cricketMatches: [CricketMatch]
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("selectedAIProvider") private var selectedProviderRaw = AIProvider.gemini.rawValue
    @State private var keyStore = AIAPIKeyStore.shared

    @State private var showDeleteSheet = false
    @State private var showDeleteSuccess = false
    @State private var editingProvider: AIProvider?
    @State private var showKeySaveError = false

    var body: some View {
        Form {
            if StoreRecoveryStatus.wasReset {
                Section {
                    Text("Your previous data couldn't be opened after an update and was set aside rather than deleted. Contact support if you need it recovered.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

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
                HStack {
                    Text("Other Sports — Players")
                    Spacer()
                    Text("\(squadPlayers.count)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Other Sports — Fixtures")
                    Spacer()
                    Text("\(fixtures.count)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Cricket — Matches")
                    Spacer()
                    Text("\(cricketMatches.count)")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteSheet = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Data…")
                        Spacer()
                    }
                }
            } footer: {
                Text("Selectively delete players, squads, games, fixtures, and events, or remove all data from this device.")
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
                    if !keyStore.setAPIKey(newValue, for: provider) { showKeySaveError = true }
                }
            } else {
                APIKeyInputView(provider: provider, currentKey: keyStore.apiKey(for: provider)) { newValue in
                    if !keyStore.setAPIKey(newValue, for: provider) { showKeySaveError = true }
                }
            }
        }
        .sheet(isPresented: $showDeleteSheet) {
            DataDeletionSheet {
                showDeleteSuccess = true
            }
        }
        .alert("Couldn't Save API Key", isPresented: $showKeySaveError) {
            Button("OK") {}
        } message: {
            Text("The key couldn't be stored in the Keychain. Please try again.")
        }
        .alert("Data Deleted", isPresented: $showDeleteSuccess) {
            Button("OK") {}
        } message: {
            Text("The selected data has been removed from this device.")
        }
    }
}
