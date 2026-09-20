import SwiftUI
import SwiftData

/// Non-Basketball equivalent of `EventHistoryView`.
struct FixtureEventHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var fixture: Fixture

    @State private var editingEvent: FixtureEvent?
    @State private var editDetail = ""

    private var sport: Sport { fixture.sportValue }

    var sortedEvents: [FixtureEvent] {
        fixture.events.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        Group {
            if fixture.events.isEmpty {
                ContentUnavailableView("No Events", systemImage: "list.bullet.clipboard", description: Text("Events are logged as the fixture progresses."))
            } else {
                List {
                    ForEach(sortedEvents) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: event.symbolName(for: sport))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(event.displayName(opponentName: fixture.opponentName))
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

    private func deleteEvent(_ event: FixtureEvent) {
        switch event.eventKind {
        case .teamScore:
            fixture.teamScore = max(0, fixture.teamScore - event.scoreDelta)
        case .opponentScore:
            fixture.opponentScore = max(0, fixture.opponentScore - event.scoreDelta)
        case .substitutionIn:
            if let playerID = event.playerID {
                fixture.onFieldPlayerIDs.removeAll { $0 == playerID.uuidString }
            }
        case .substitutionOut:
            if let playerID = event.playerID, !fixture.onFieldPlayerIDs.contains(playerID.uuidString) {
                fixture.onFieldPlayerIDs.append(playerID.uuidString)
            }
        case .discipline:
            // No-op: a sin-bin/send-off removal is logged as a paired
            // `.substitutionOut`, which is undone separately when that event
            // itself is deleted.
            break
        default:
            break
        }
        fixture.events.removeAll { $0.eventID == event.eventID }
        modelContext.delete(event)
    }

    private func periodTimeLabel(_ event: FixtureEvent) -> String {
        let m = event.elapsedSeconds / 60
        let s = event.elapsedSeconds % 60
        let label = fixture.periodFormat == "quarters" ? "Q\(event.periodNumber)" : "H\(event.periodNumber)"
        return "\(label) \(String(format: "%02d:%02d", m, s))"
    }
}
