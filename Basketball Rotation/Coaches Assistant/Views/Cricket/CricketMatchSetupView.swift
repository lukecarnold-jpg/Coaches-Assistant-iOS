import SwiftUI
import SwiftData

/// Creates a `CricketMatch` and a blank scorecard line for each selected player.
struct CricketMatchSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var squad: [SquadPlayer]

    @State private var opponentName = ""
    @State private var date = Date()
    @State private var venue = ""
    @State private var oversPerInnings = 20
    @State private var weBattedFirst = true
    @State private var selectedIDs: Set<UUID> = []
    @State private var didSeedSelection = false

    /// 0 = unlimited overs.
    static let overOptions = [0, 5, 6, 8, 10, 12, 15, 16, 20, 25, 30, 35, 40, 45, 50]

    init() {
        let raw = Sport.cricket.rawValue
        _squad = Query(filter: #Predicate<SquadPlayer> { $0.sport == raw }, sort: \SquadPlayer.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Match") {
                    TextField("Opponent Name", text: $opponentName)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Venue (Optional)", text: $venue)
                    Picker("Overs per Innings", selection: $oversPerInnings) {
                        ForEach(Self.overOptions, id: \.self) { overs in
                            Text(overs == 0 ? "Unlimited" : "\(overs) overs").tag(overs)
                        }
                    }
                    Toggle("We Batted First", isOn: $weBattedFirst)
                }

                Section {
                    if squad.isEmpty {
                        Text("Add players on the Roster tab to record their stats. You can still record team totals.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(squad) { player in
                            Button {
                                toggle(player)
                            } label: {
                                HStack {
                                    Image(systemName: selectedIDs.contains(player.playerID) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedIDs.contains(player.playerID) ? Sport.cricket.tint : .secondary)
                                        .accessibilityHidden(true)
                                    Text(player.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if let position = player.preferredPosition {
                                        Text(position.code)
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .accessibilityAddTraits(selectedIDs.contains(player.playerID) ? .isSelected : [])
                        }
                    }
                } header: {
                    Text("Playing Team (\(selectedIDs.count))")
                } footer: {
                    if selectedIDs.count > Sport.cricket.rules.onFieldCount {
                        Text("More than \(Sport.cricket.rules.onFieldCount) selected — fine for junior or social formats.")
                    }
                }
            }
            .navigationTitle("New Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createMatch() }
                        .disabled(opponentName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                // Pre-select the first XI so the common case is one tap.
                guard !didSeedSelection else { return }
                didSeedSelection = true
                selectedIDs = Set(squad.prefix(Sport.cricket.rules.onFieldCount).map(\.playerID))
            }
        }
    }

    private func toggle(_ player: SquadPlayer) {
        if selectedIDs.contains(player.playerID) {
            selectedIDs.remove(player.playerID)
        } else {
            selectedIDs.insert(player.playerID)
        }
    }

    private func createMatch() {
        let match = CricketMatch(
            opponentName: opponentName.trimmingCharacters(in: .whitespaces),
            date: date,
            venue: venue.trimmingCharacters(in: .whitespaces),
            oversPerInnings: oversPerInnings,
            weBattedFirst: weBattedFirst
        )
        modelContext.insert(match)
        for player in squad where selectedIDs.contains(player.playerID) {
            let line = CricketPlayerStats(match: match, playerID: player.playerID, playerName: player.name)
            modelContext.insert(line)
            match.playerStats.append(line)
        }
        dismiss()
    }
}
