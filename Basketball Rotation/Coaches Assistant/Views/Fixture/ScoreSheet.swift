import SwiftUI

/// Score entry for both the team and the opponent — each sport's
/// `scoringActions` list drives the picker (e.g. Basketball's 1/2/3).
struct ScoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sport: Sport
    let title: String
    let players: [SquadPlayer]
    /// false for opponent scoring, where we don't track the opposing roster.
    var showScorer: Bool = true
    let onConfirm: (SquadPlayer?, ScoringAction) -> Void

    @State private var selectedPlayer: SquadPlayer?
    @State private var selectedActionCode: String

    init(sport: Sport, title: String, players: [SquadPlayer], showScorer: Bool = true, onConfirm: @escaping (SquadPlayer?, ScoringAction) -> Void) {
        self.sport = sport
        self.title = title
        self.players = players
        self.showScorer = showScorer
        self.onConfirm = onConfirm
        _selectedActionCode = State(initialValue: sport.rules.scoringActions.first?.code ?? "")
    }

    private var selectedAction: ScoringAction? {
        sport.rules.scoringAction(forCode: selectedActionCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Scored") {
                    Picker("Action", selection: $selectedActionCode) {
                        ForEach(sport.rules.scoringActions) { action in
                            Text("\(action.label) (\(action.points))").tag(action.code)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if showScorer {
                    Section {
                        if players.isEmpty {
                            Text("No players available — set lineup first.")
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
                    } header: {
                        Text("Scorer (Optional)")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log +\(selectedAction?.points ?? 0)") {
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
