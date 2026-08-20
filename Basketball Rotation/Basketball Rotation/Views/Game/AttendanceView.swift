import SwiftUI

struct AttendanceView: View {
    @Environment(\.dismiss) private var dismiss
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
                                set: { attendance.isAbsent = $0 }
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
}
