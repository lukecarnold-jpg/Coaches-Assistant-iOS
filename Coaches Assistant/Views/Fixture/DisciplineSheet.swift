import SwiftUI

/// Action + player picker for discipline events (fouls, cards, sin bins,
/// free kicks…). The caller applies the removal — this sheet just returns the
/// chosen action and (optional) player.
struct DisciplineSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sport: Sport
    let players: [SquadPlayer]
    let onConfirm: (SquadPlayer?, DisciplineAction) -> Void

    @State private var selectedPlayer: SquadPlayer?
    @State private var selectedActionCode: String

    init(sport: Sport, players: [SquadPlayer], onConfirm: @escaping (SquadPlayer?, DisciplineAction) -> Void) {
        self.sport = sport
        self.players = players
        self.onConfirm = onConfirm
        _selectedActionCode = State(initialValue: sport.rules.disciplineActions.first?.code ?? "")
    }

    private var selectedAction: DisciplineAction? {
        sport.rules.disciplineAction(forCode: selectedActionCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Action") {
                    Picker("Action", selection: $selectedActionCode) {
                        ForEach(sport.rules.disciplineActions) { action in
                            Text(action.label).tag(action.code)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Player (Optional)") {
                    if players.isEmpty {
                        Text("No players available.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(players) { player in
                            Button {
                                selectedPlayer = selectedPlayer?.playerID == player.playerID ? nil : player
                            } label: {
                                HStack {
                                    Text(player.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedPlayer?.playerID == player.playerID {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(sport.tint)
                                    }
                                }
                            }
                            .buttonStyle(.listRow)
                        }
                    }
                }
            }
            .navigationTitle(sport.rules.disciplineActions.count == 1 ? sport.rules.disciplineActions[0].label : "Discipline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        if let action = selectedAction {
                            onConfirm(selectedPlayer, action)
                        }
                        dismiss()
                    }
                    .disabled(selectedAction == nil)
                }
            }
        }
    }
}
