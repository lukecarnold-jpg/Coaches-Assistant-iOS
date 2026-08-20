import SwiftUI
import SwiftData

struct LineupSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var game: Game
    let players: [Player]

    @State private var selectedIDs: Set<UUID> = []

    private let maxLineupSize = 5

    var body: some View {
        NavigationStack {
            List(players, selection: $selectedIDs) { player in
                HStack {
                    Image(systemName: selectedIDs.contains(player.playerID) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIDs.contains(player.playerID) ? .blue : .secondary)
                    Text(player.displayName)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleSelection(player.playerID)
                }
            }
            .navigationTitle("Starting Lineup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set Lineup") {
                        applyLineup()
                    }
                    .disabled(selectedIDs.count != maxLineupSize)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("\(selectedIDs.count) / \(maxLineupSize) selected")
                    .font(.subheadline)
                    .foregroundStyle(selectedIDs.count == maxLineupSize ? .green : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.regularMaterial)
            }
        }
        .onAppear {
            selectedIDs = Set(game.onCourtPlayerIDs)
            if selectedIDs.isEmpty {
                selectedIDs = Set(game.startingLineupIDs)
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else if selectedIDs.count < maxLineupSize {
            selectedIDs.insert(id)
        }
    }

    private func applyLineup() {
        let newIDs = Array(selectedIDs)
        game.startingLineupIDs = newIDs
        game.onCourtPlayerIDs = newIDs

        let playerNames = players.filter { selectedIDs.contains($0.playerID) }.map { $0.name }.joined(separator: ", ")
        let event = GameEvent(
            game: game,
            eventType: .substitutionIn,
            detail: "Starting lineup: \(playerNames)",
            periodNumber: game.currentPeriod,
            elapsedSeconds: game.currentElapsedSeconds()
        )
        modelContext.insert(event)
        game.events.append(event)
        dismiss()
    }
}
