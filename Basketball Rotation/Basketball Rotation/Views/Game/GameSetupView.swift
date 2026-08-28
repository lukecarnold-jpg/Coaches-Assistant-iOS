import SwiftUI
import SwiftData

struct GameSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Player.name) private var players: [Player]

    @State private var opponentName = ""
    @State private var periodFormat = "quarters"
    @State private var periodLengthMinutes = 10

    var body: some View {
        NavigationStack {
            Form {
                Section("Opponent") {
                    TextField("Opponent Name", text: $opponentName)
                }

                Section("Period Format") {
                    Picker("Format", selection: $periodFormat) {
                        Text("Quarters").tag("quarters")
                        Text("Halves").tag("halves")
                    }
                    .pickerStyle(.segmented)

                    Picker("Minutes per Period", selection: $periodLengthMinutes) {
                        ForEach(1...25, id: \.self) { minutes in
                            Text("\(minutes) minutes")
                                .tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGame()
                    }
                    .disabled(opponentName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func createGame() {
        let game = Game(
            opponentName: opponentName.trimmingCharacters(in: .whitespaces),
            periodFormat: periodFormat,
            periodLengthMinutes: periodLengthMinutes
        )
        modelContext.insert(game)

        // Create attendance records for all players
        for player in players {
            let attendance = GameAttendance(game: game, playerID: player.playerID, playerName: player.name)
            modelContext.insert(attendance)
            game.attendances.append(attendance)
        }

        dismiss()
    }
}
