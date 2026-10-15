import SwiftUI
import SwiftData

/// Mark players absent for a match; absent on-field players are benched.
struct FixtureAttendanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var fixture: Fixture

    private var sport: Sport { fixture.sportValue }

    var sortedAttendances: [FixtureAttendance] {
        fixture.attendances.sorted { $0.playerName < $1.playerName }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Mark players as absent. Absent players will not appear in \(sport.rules.onFieldTerm.lowercased()) or substitution options.")
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

    private func setAbsent(_ isAbsent: Bool, for attendance: FixtureAttendance) {
        attendance.isAbsent = isAbsent
        guard isAbsent, fixture.onFieldPlayerIDs.contains(attendance.playerID.uuidString) else { return }

        fixture.onFieldPlayerIDs.removeAll { $0 == attendance.playerID.uuidString }
        let event = FixtureEvent(
            fixture: fixture,
            eventType: .substitutionOut,
            playerID: attendance.playerID,
            playerName: attendance.playerName,
            detail: "Marked absent",
            periodNumber: fixture.currentPeriod,
            elapsedSeconds: fixture.currentElapsedSeconds()
        )
        modelContext.insert(event)
        fixture.events.append(event)
    }
}
