import SwiftUI
import SwiftData

struct SubstitutionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var game: Game
    let allPlayers: [Player]

    // Ordered selection lists — pair index is the position in each array
    @State private var outOrder: [Player] = []
    @State private var inOrder: [Player] = []

    var onCourtPlayers: [Player] {
        allPlayers.filter { game.onCourtPlayerIDs.contains($0.playerID.uuidString) }
    }

    var benchPlayers: [Player] {
        allPlayers.filter { !game.onCourtPlayerIDs.contains($0.playerID.uuidString) }
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
                    if onCourtPlayers.isEmpty {
                        Text("No players on court")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(onCourtPlayers) { player in
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

    // MARK: - Helpers

    private func toggleOut(_ player: Player) {
        if let idx = outOrder.firstIndex(where: { $0.playerID == player.playerID }) {
            outOrder.remove(at: idx)
        } else {
            outOrder.append(player)
        }
    }

    private func toggleIn(_ player: Player) {
        if let idx = inOrder.firstIndex(where: { $0.playerID == player.playerID }) {
            inOrder.remove(at: idx)
        } else {
            inOrder.append(player)
        }
    }

    private func performSubstitutions() {
        let elapsed = game.currentElapsedSeconds()
        for (outPlayer, inPlayer) in zip(outOrder, inOrder) {
            game.onCourtPlayerIDs.removeAll { $0 == outPlayer.playerID.uuidString }
            game.onCourtPlayerIDs.append(inPlayer.playerID.uuidString)

            let outEvent = GameEvent(
                game: game,
                eventType: .substitutionOut,
                playerID: outPlayer.playerID,
                playerName: outPlayer.name,
                detail: "Out → \(inPlayer.name)",
                periodNumber: game.currentPeriod,
                elapsedSeconds: elapsed
            )
            modelContext.insert(outEvent)
            game.events.append(outEvent)

            let inEvent = GameEvent(
                game: game,
                eventType: .substitutionIn,
                playerID: inPlayer.playerID,
                playerName: inPlayer.name,
                detail: "In for \(outPlayer.name)",
                periodNumber: game.currentPeriod,
                elapsedSeconds: elapsed
            )
            modelContext.insert(inEvent)
            game.events.append(inEvent)
        }
        dismiss()
    }
}

struct PairBadge: View {
    let number: Int

    private static let colors: [Color] = [.blue, .green, .orange, .purple, .red]
    private var color: Color { Self.colors[(number - 1) % Self.colors.count] }

    var body: some View {
        Text("\(number)")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(color, in: Circle())
    }
}
