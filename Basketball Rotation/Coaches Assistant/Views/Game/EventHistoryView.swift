import SwiftUI
import SwiftData

struct EventHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var game: Game

    @State private var editingEvent: GameEvent?
    @State private var editDetail = ""

    var sortedEvents: [GameEvent] {
        game.events.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        Group {
            if game.events.isEmpty {
                ContentUnavailableView("No Events", systemImage: "list.bullet.clipboard", description: Text("Events are logged as the game progresses."))
            } else {
                List {
                    ForEach(sortedEvents) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: event.eventKind.systemImage)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(event.displayName(opponentName: game.opponentName))
                                    .font(.subheadline.bold())
                                if !event.playerName.isEmpty {
                                    Text("· \(event.playerName)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(periodTimeLabel(event))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            if !event.detail.isEmpty {
                                Text(event.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 30)
                            }
                            Text(event.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 30)
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteEvent(event)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editDetail = event.detail
                                editingEvent = event
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Event History")
        .sheet(item: $editingEvent) { event in
            NavigationStack {
                Form {
                    Section("Edit Detail") {
                        TextField("Detail", text: $editDetail)
                    }
                }
                .navigationTitle("Edit Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editingEvent = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            event.detail = editDetail
                            editingEvent = nil
                        }
                    }
                }
            }
        }
    }

    private func deleteEvent(_ event: GameEvent) {
        switch event.eventKind {
        case .teamScore:
            game.teamScore = max(0, game.teamScore - event.scoreDelta)
        case .opponentScore:
            game.opponentScore = max(0, game.opponentScore - event.scoreDelta)
        case .substitutionIn:
            // Undo the player coming on court. Starting-lineup events have no single
            // playerID (they set the whole lineup at once) so they're left alone here.
            if let playerID = event.playerID {
                game.onCourtPlayerIDs.removeAll { $0 == playerID.uuidString }
            }
        case .substitutionOut:
            // Undo the player leaving court — put them back on.
            if let playerID = event.playerID, !game.onCourtPlayerIDs.contains(playerID.uuidString) {
                game.onCourtPlayerIDs.append(playerID.uuidString)
            }
        default:
            break
        }
        game.events.removeAll { $0.eventID == event.eventID }
        modelContext.delete(event)
    }

    private func periodTimeLabel(_ event: GameEvent) -> String {
        "\(game.shortPeriodLabel(forPeriod: event.periodNumber)) \(formatClock(event.elapsedSeconds))"
    }
}
