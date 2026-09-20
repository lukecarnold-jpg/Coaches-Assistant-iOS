import SwiftUI
import SwiftData

/// Non-Basketball equivalent of `SubstitutionView`. Reuses `PairBadge` (defined
/// alongside Basketball's `SubstitutionView`) unchanged. Excludes sent-off
/// players from the bench, and carries the outgoing player's position to
/// whoever replaces them.
struct FixtureSubstitutionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var fixture: Fixture
    let allPlayers: [SquadPlayer]

    @State private var outOrder: [SquadPlayer] = []
    @State private var inOrder: [SquadPlayer] = []

    private var sentOff: Set<UUID> { fixture.sentOffPlayerIDs }

    var onFieldPlayers: [SquadPlayer] {
        allPlayers.filter { fixture.onFieldPlayerIDs.contains($0.playerID.uuidString) }
    }

    var benchPlayers: [SquadPlayer] {
        allPlayers.filter { !fixture.onFieldPlayerIDs.contains($0.playerID.uuidString) && !sentOff.contains($0.playerID) }
    }

    var pairedCount: Int { min(outOrder.count, inOrder.count) }
    var canConfirm: Bool { pairedCount > 0 && outOrder.count == inOrder.count }

    var body: some View {
        NavigationStack {
            List {
                if pairedCount > 0 {
                    Section("Substitutions") {
                        ForEach(0..<pairedCount, id: \.self) { i in
                            HStack(spacing: 10) {
                                PairBadge(number: i + 1)
                                Text(outOrder[i].name)
                                    .font(.subheadline)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(inOrder[i].name)
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                    }
                }

                Section {
                    if onFieldPlayers.isEmpty {
                        Text("No players \(fixture.sportValue.rules.onFieldTerm.lowercased())")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(onFieldPlayers) { player in
                            let pairNum = outOrder.firstIndex(where: { $0.playerID == player.playerID }).map { $0 + 1 }
                            Button { toggleOut(player) } label: {
                                HStack(spacing: 12) {
                                    if let num = pairNum {
                                        PairBadge(number: num)
                                    } else {
                                        Circle()
                                            .stroke(.secondary.opacity(0.35), lineWidth: 1.5)
                                            .frame(width: 26, height: 26)
                                    }
                                    Text(player.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                            }
                        }
                    }
                } header: {
                    Text("Coming Off")
                } footer: {
                    if outOrder.count > inOrder.count {
                        Text("Select \(outOrder.count - inOrder.count) player(s) to come on")
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    if benchPlayers.isEmpty {
                        Text("No players on bench")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(benchPlayers) { player in
                            let pairNum = inOrder.firstIndex(where: { $0.playerID == player.playerID }).map { $0 + 1 }
                            Button { toggleIn(player) } label: {
                                HStack(spacing: 12) {
                                    if let num = pairNum {
                                        PairBadge(number: num)
                                    } else {
                                        Circle()
                                            .stroke(.secondary.opacity(0.35), lineWidth: 1.5)
                                            .frame(width: 26, height: 26)
                                    }
                                    Text(player.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                            }
                        }
                    }
                } header: {
                    Text("Coming On")
                } footer: {
                    if inOrder.count > outOrder.count {
                        Text("Select \(inOrder.count - outOrder.count) player(s) to come off")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Substitutions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(pairedCount > 1 ? "Confirm (\(pairedCount))" : "Confirm") {
                        performSubstitutions()
                    }
                    .disabled(!canConfirm)
                }
            }
        }
    }

    private func toggleOut(_ player: SquadPlayer) {
        if let idx = outOrder.firstIndex(where: { $0.playerID == player.playerID }) {
            outOrder.remove(at: idx)
        } else {
            outOrder.append(player)
        }
    }

    private func toggleIn(_ player: SquadPlayer) {
        if let idx = inOrder.firstIndex(where: { $0.playerID == player.playerID }) {
            inOrder.remove(at: idx)
        } else {
            inOrder.append(player)
        }
    }

    private func performSubstitutions() {
        let elapsed = fixture.currentElapsedSeconds()
        for (outPlayer, inPlayer) in zip(outOrder, inOrder) {
            fixture.onFieldPlayerIDs.removeAll { $0 == outPlayer.playerID.uuidString }
            fixture.onFieldPlayerIDs.append(inPlayer.playerID.uuidString)

            if let outgoingCode = fixture.lineupSlot(for: outPlayer.playerID)?.positionCode, !outgoingCode.isEmpty {
                if let incomingSlot = fixture.lineupSlot(for: inPlayer.playerID) {
                    incomingSlot.positionCode = outgoingCode
                } else {
                    let slot = FixtureLineupSlot(fixture: fixture, playerID: inPlayer.playerID, playerName: inPlayer.name, positionCode: outgoingCode)
                    modelContext.insert(slot)
                    fixture.lineupSlots.append(slot)
                }
            }

            let outEvent = FixtureEvent(
                fixture: fixture,
                eventType: .substitutionOut,
                playerID: outPlayer.playerID,
                playerName: outPlayer.name,
                detail: "Out → \(inPlayer.name)",
                periodNumber: fixture.currentPeriod,
                elapsedSeconds: elapsed
            )
            modelContext.insert(outEvent)
            fixture.events.append(outEvent)

            let inEvent = FixtureEvent(
                fixture: fixture,
                eventType: .substitutionIn,
                playerID: inPlayer.playerID,
                playerName: inPlayer.name,
                detail: "In for \(outPlayer.name)",
                periodNumber: fixture.currentPeriod,
                elapsedSeconds: elapsed
            )
            modelContext.insert(inEvent)
            fixture.events.append(inEvent)
        }
        dismiss()
    }
}
