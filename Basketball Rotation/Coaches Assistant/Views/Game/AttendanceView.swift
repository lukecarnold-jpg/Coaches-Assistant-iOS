import SwiftUI
import SwiftData

struct AttendanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var game: Game

    var sortedAttendances: [GameAttendance] {
        game.attendances.sorted { $0.playerName < $1.playerName }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Mark players as absent. Absent players will not appear in lineup or substitution options.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if sortedAttendances.isEmpty {
                    Text("No players on roster. Add players first.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedAttendances) { attendance in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(attendance.playerName)
                                    .strikethrough(attendance.isAbsent)
                                    .foregroundStyle(attendance.isAbsent ? .secondary : .primary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { attendance.isAbsent },
                                set: { setAbsent($0, for: attendance) }
                            ))
                            .labelsHidden()
                        }
                    }
                }
            }
            .navigationTitle("Attendance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // Marking a player absent while they're on court benches them immediately —
    // otherwise attendance and the on-court roster silently disagree.
    private func setAbsent(_ isAbsent: Bool, for attendance: GameAttendance) {
        attendance.isAbsent = isAbsent
        guard isAbsent, game.onCourtPlayerIDs.contains(attendance.playerID.uuidString) else { return }

        game.onCourtPlayerIDs.removeAll { $0 == attendance.playerID.uuidString }
        let event = GameEvent(
            game: game,
            eventType: .substitutionOut,
            playerID: attendance.playerID,
            playerName: attendance.playerName,
            detail: "Marked absent",
            periodNumber: game.currentPeriod,
            elapsedSeconds: game.currentElapsedSeconds()
        )
        modelContext.insert(event)
        game.events.append(event)
    }
}
