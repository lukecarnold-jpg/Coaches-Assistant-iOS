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

    var sortedPlayers: [Player] {
        players.sorted {
            switch ($0.jerseyNumber, $1.jerseyNumber) {
            case (let a?, let b?): return a < b
            case (nil, nil):       return $0.name < $1.name
            case (_?, nil):        return true
            case (nil, _?):        return false
            }
        }
    }

    var body: some View {
        NavigationStack {
            List(sortedPlayers) { player in
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
        let previousIDs = Set(game.onCourtPlayerIDs)

        if previousIDs.isEmpty {
            // First time the lineup is set for this game — record it as a single
            // "starting lineup" event rather than five individual sub-ins.
            game.startingLineupIDs = Array(selectedIDStrings)
            game.onCourtPlayerIDs = Array(selectedIDStrings)

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
        } else {
            // Adjusting the lineup mid-game — log a proper in/out event per player so
            // playing-time tracking and event history stay accurate. `startingLineupIDs`
            // is left untouched since it records who actually started the game.
            let leaving = previousIDs.subtracting(selectedIDStrings)
            let entering = selectedIDStrings.subtracting(previousIDs)
            let elapsed = game.currentElapsedSeconds()

            for idString in leaving {
                guard let player = players.first(where: { $0.playerID.uuidString == idString }) else { continue }
                let event = GameEvent(
                    game: game,
                    eventType: .substitutionOut,
                    playerID: player.playerID,
                    playerName: player.name,
                    detail: "Out (lineup change)",
                    periodNumber: game.currentPeriod,
                    elapsedSeconds: elapsed
                )
                modelContext.insert(event)
                game.events.append(event)
            }
            for idString in entering {
                guard let player = players.first(where: { $0.playerID.uuidString == idString }) else { continue }
                let event = GameEvent(
                    game: game,
                    eventType: .substitutionIn,
                    playerID: player.playerID,
                    playerName: player.name,
                    detail: "In (lineup change)",
                    periodNumber: game.currentPeriod,
                    elapsedSeconds: elapsed
                )
                modelContext.insert(event)
                game.events.append(event)
            }
            game.onCourtPlayerIDs = Array(selectedIDStrings)
        }
        dismiss()
    }
}
