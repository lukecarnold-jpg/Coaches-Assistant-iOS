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
                                Text(event.eventType)
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
        game.events.removeAll { $0.eventID == event.eventID }
        modelContext.delete(event)
    }

    private func periodTimeLabel(_ event: GameEvent) -> String {
        let m = event.elapsedSeconds / 60
        let s = event.elapsedSeconds % 60
        let label = game.periodFormat == "quarters" ? "Q\(event.periodNumber)" : "H\(event.periodNumber)"
        return "\(label) \(String(format: "%02d:%02d", m, s))"
    }
}
