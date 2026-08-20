import SwiftUI
import SwiftData

struct SubstitutionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var game: Game
    let allPlayers: [Player]

    @State private var playerOut: Player?
    @State private var playerIn: Player?

    var onCourtPlayers: [Player] {
        allPlayers.filter { game.onCourtPlayerIDs.contains($0.playerID.uuidString) }
    }

    var benchPlayers: [Player] {
        allPlayers.filter { !game.onCourtPlayerIDs.contains($0.playerID.uuidString) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Player Coming Out") {
                    if onCourtPlayers.isEmpty {
                        Text("No players on court")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(onCourtPlayers) { player in
                            Button {
                                playerOut = player
                            } label: {
                                HStack {
                                    Text(player.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if playerOut?.playerID == player.playerID {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Player Going In") {
                    if benchPlayers.isEmpty {
                        Text("No players on bench")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(benchPlayers) { player in
                            Button {
                                playerIn = player
                            } label: {
                                HStack {
                                    Text(player.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if playerIn?.playerID == player.playerID {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Substitution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        performSubstitution()
                    }
                    .disabled(playerOut == nil || playerIn == nil)
                }
            }
        }
    }

    private func performSubstitution() {
        guard let out = playerOut, let inPlayer = playerIn else { return }

        game.onCourtPlayerIDs.removeAll { $0 == out.playerID.uuidString }
        game.onCourtPlayerIDs.append(inPlayer.playerID.uuidString)

        let elapsed = game.currentElapsedSeconds()

        let outEvent = GameEvent(game: game, eventType: .substitutionOut, playerID: out.playerID, playerName: out.name, detail: "Out", periodNumber: game.currentPeriod, elapsedSeconds: elapsed)
        modelContext.insert(outEvent)
        game.events.append(outEvent)

        let inEvent = GameEvent(game: game, eventType: .substitutionIn, playerID: inPlayer.playerID, playerName: inPlayer.name, detail: "In for \(out.name)", periodNumber: game.currentPeriod, elapsedSeconds: elapsed)
        modelContext.insert(inEvent)
        game.events.append(inEvent)

        dismiss()
    }
}
