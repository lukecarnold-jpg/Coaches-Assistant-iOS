import SwiftUI
import SwiftData

/// Non-Basketball equivalent of `GameSetupView`. Seeds period format/length
/// from the sport's rules and caps the minutes picker at `rules.maxPeriodMinutes`
/// (soccer 45 / rugby 40 / AFL 30 — all of which overflow Basketball's fixed
/// 1...25 range). Attendance is fanned out only to this sport's squad.
struct FixtureSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var players: [SquadPlayer]

    let sport: Sport

    @State private var opponentName = ""
    @State private var periodFormat: String
    @State private var periodLengthMinutes: Int

    init(sport: Sport) {
        self.sport = sport
        let raw = sport.rawValue
        _players = Query(filter: #Predicate<SquadPlayer> { $0.sport == raw }, sort: \SquadPlayer.name)
        _periodFormat = State(initialValue: sport.rules.periodFormat)
        _periodLengthMinutes = State(initialValue: sport.rules.defaultPeriodMinutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Opponent") {
                    TextField("Opponent Name", text: $opponentName)
                }

                Section("Period Format") {
                    Picker("Format", selection: $periodFormat) {
                        Text("Quarters").tag("quarters")
                        Text("Halves").tag("halves")
                    }
                    .pickerStyle(.segmented)

                    Picker("Minutes per Period", selection: $periodLengthMinutes) {
                        ForEach(1...sport.rules.maxPeriodMinutes, id: \.self) { minutes in
                            Text("\(minutes) minutes")
                                .tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("New Fixture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createFixture()
                    }
                    .disabled(opponentName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func createFixture() {
        let fixture = Fixture(
            sport: sport,
            opponentName: opponentName.trimmingCharacters(in: .whitespaces),
            periodFormat: periodFormat,
            periodLengthMinutes: periodLengthMinutes
        )
        modelContext.insert(fixture)

        for player in players {
            let attendance = FixtureAttendance(fixture: fixture, playerID: player.playerID, playerName: player.name)
            modelContext.insert(attendance)
            fixture.attendances.append(attendance)
        }

        dismiss()
    }
}
