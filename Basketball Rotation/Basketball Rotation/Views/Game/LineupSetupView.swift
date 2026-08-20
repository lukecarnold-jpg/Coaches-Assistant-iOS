import SwiftUI
import SwiftData

struct LineupSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var game: Game
    let players: [Player]

    // Selection stored as UUIDString to match game's [String] arrays
    @State private var selectedIDStrings: Set<String> = []

    private let maxLineupSize = 5

    var body: some View {
        NavigationStack {
            List(players) { player in
                let idString = player.playerID.uuidString
                HStack {
                    Image(systemName: selectedIDStrings.contains(idString) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIDStrings.contains(idString) ? .blue : .secondary)
                    Text(player.displayName)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleSelection(idString)
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
                    .disabled(selectedIDStrings.count != maxLineupSize)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("\(selectedIDStrings.count) / \(maxLineupSize) selected")
                    .font(.subheadline)
                    .foregroundStyle(selectedIDStrings.count == maxLineupSize ? .green : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.regularMaterial)
            }
        }
        .onAppear {
            if !game.onCourtPlayerIDs.isEmpty {
                selectedIDStrings = Set(game.onCourtPlayerIDs)
            } else {
                selectedIDStrings = Set(game.startingLineupIDs)
            }
        }
    }

    private func toggleSelection(_ idString: String) {
        if selectedIDStrings.contains(idString) {
            selectedIDStrings.remove(idString)
        } else if selectedIDStrings.count < maxLineupSize {
            selectedIDStrings.insert(idString)
        }
    }

    private func applyLineup() {
        let newIDs = Array(selectedIDStrings)
        game.startingLineupIDs = newIDs
        game.onCourtPlayerIDs = newIDs

        let playerNames = players
            .filter { selectedIDStrings.contains($0.playerID.uuidString) }
            .map { $0.name }
            .joined(separator: ", ")

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
