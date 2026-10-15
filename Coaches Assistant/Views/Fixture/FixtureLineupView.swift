import SwiftUI
import SwiftData

/// Starting lineup picker. The max lineup size comes from
/// `sport.rules.onFieldCount`, and the "Set Lineup" guard allows fewer than the max
/// (`1...max`, not `== max`) — otherwise a send-off would make the lineup
/// permanently un-settable, since the team is deliberately short-handed from
/// that point on. Sent-off players are excluded from selection entirely.
struct FixtureLineupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var fixture: Fixture
    let players: [SquadPlayer]

    @State private var selectedIDStrings: Set<String> = []

    private var sport: Sport { fixture.sportValue }
    private var maxLineupSize: Int { sport.rules.onFieldCount }

    private var eligiblePlayers: [SquadPlayer] {
        let sentOff = fixture.sentOffPlayerIDs
        return players.filter { !sentOff.contains($0.playerID) }
    }

    var sortedPlayers: [SquadPlayer] {
        eligiblePlayers.sorted {
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
            List {
                Section {
                    ForEach(sortedPlayers) { player in
                        let idString = player.playerID.uuidString
                        // A real button (not a tap gesture) so VoiceOver announces
                        // the row as selectable and reports its selected state.
                        Button {
                            toggleSelection(idString)
                        } label: {
                            HStack {
                                Image(systemName: selectedIDStrings.contains(idString) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIDStrings.contains(idString) ? sport.tint : .secondary)
                                    .accessibilityHidden(true)
                                Text(player.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.listRow)
                        .accessibilityAddTraits(selectedIDStrings.contains(idString) ? .isSelected : [])
                    }
                }

                if sport.rules.hasPositions && !selectedIDStrings.isEmpty {
                    Section("Positions") {
                        ForEach(sortedPlayers.filter { selectedIDStrings.contains($0.playerID.uuidString) }) { player in
                            HStack {
                                Text(player.displayName)
                                Spacer()
                                PositionPicker(sport: sport, selection: positionBinding(for: player))
                                    .labelsHidden()
                            }
                        }
                    }
                }
            }
            .navigationTitle("\(sport.rules.onFieldTerm) Lineup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set Lineup") {
                        applyLineup()
                    }
                    .disabled(selectedIDStrings.isEmpty)
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
            if !fixture.onFieldPlayerIDs.isEmpty {
                selectedIDStrings = Set(fixture.onFieldPlayerIDs)
            } else {
                selectedIDStrings = Set(fixture.startingLineupIDs)
            }
        }
    }

    private func positionBinding(for player: SquadPlayer) -> Binding<String> {
        Binding(
            get: { fixture.position(for: player.playerID)?.code ?? player.preferredPositionCode },
            set: { newCode in setPosition(newCode, for: player) }
        )
    }

    private func setPosition(_ code: String, for player: SquadPlayer) {
        if let slot = fixture.lineupSlot(for: player.playerID) {
            slot.positionCode = code
        } else if !code.isEmpty {
            let slot = FixtureLineupSlot(fixture: fixture, playerID: player.playerID, playerName: player.name, positionCode: code)
            modelContext.insert(slot)
            fixture.lineupSlots.append(slot)
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
        let previousIDs = Set(fixture.onFieldPlayerIDs)

        if previousIDs.isEmpty {
            // First time the lineup is set — record it as a single "starting
            // lineup" event rather than N individual sub-ins.
            fixture.startingLineupIDs = Array(selectedIDStrings)
            fixture.onFieldPlayerIDs = Array(selectedIDStrings)

            let playerNames = players
                .filter { selectedIDStrings.contains($0.playerID.uuidString) }
                .map { $0.name }
                .joined(separator: ", ")

            let event = FixtureEvent(
                fixture: fixture,
                eventType: .substitutionIn,
                detail: "Starting lineup: \(playerNames)",
                periodNumber: fixture.currentPeriod,
                elapsedSeconds: fixture.currentElapsedSeconds()
            )
            modelContext.insert(event)
            fixture.events.append(event)
        } else {
            let leaving = previousIDs.subtracting(selectedIDStrings)
            let entering = selectedIDStrings.subtracting(previousIDs)
            let elapsed = fixture.currentElapsedSeconds()

            for idString in leaving {
                guard let player = players.first(where: { $0.playerID.uuidString == idString }) else { continue }
                let event = FixtureEvent(
                    fixture: fixture,
                    eventType: .substitutionOut,
                    playerID: player.playerID,
                    playerName: player.name,
                    detail: "Out (lineup change)",
                    periodNumber: fixture.currentPeriod,
                    elapsedSeconds: elapsed
                )
                modelContext.insert(event)
                fixture.events.append(event)
            }
            for idString in entering {
                guard let player = players.first(where: { $0.playerID.uuidString == idString }) else { continue }
                let event = FixtureEvent(
                    fixture: fixture,
                    eventType: .substitutionIn,
                    playerID: player.playerID,
                    playerName: player.name,
                    detail: "In (lineup change)",
                    periodNumber: fixture.currentPeriod,
                    elapsedSeconds: elapsed
                )
                modelContext.insert(event)
                fixture.events.append(event)
            }
            fixture.onFieldPlayerIDs = Array(selectedIDStrings)
        }
        dismiss()
    }
}
