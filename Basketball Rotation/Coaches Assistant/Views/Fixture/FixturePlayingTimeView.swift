import SwiftUI
import SwiftData

/// Non-Basketball equivalent of `PlayingTimeView`.
struct FixturePlayingTimeView: View {
    @Query private var allPlayers: [SquadPlayer]
    @Bindable var fixture: Fixture

    init(fixture: Fixture) {
        self.fixture = fixture
        let raw = fixture.sport
        _allPlayers = Query(filter: #Predicate<SquadPlayer> { $0.sport == raw }, sort: \SquadPlayer.name)
    }

    private var presentPlayers: [SquadPlayer] {
        let absentIDs = Set(fixture.attendances.filter { $0.isAbsent }.map { $0.playerID })
        return allPlayers.filter { !absentIDs.contains($0.playerID) }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            let totals = fixture.minutesPlayedSeconds()
            let rows = presentPlayers
                .map { (player: $0, seconds: totals[$0.playerID] ?? 0) }
                .sorted { $0.seconds > $1.seconds }

            Group {
                if rows.isEmpty {
                    ContentUnavailableView("No Players", systemImage: "person.3", description: Text("Add players to the roster to track playing time."))
                } else {
                    List(rows, id: \.player.playerID) { row in
                        HStack {
                            HStack(spacing: 8) {
                                if fixture.isOnField(row.player) {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 8, height: 8)
                                        .accessibilityLabel("Currently playing")
                                }
                                Text(row.player.displayName)
                            }
                            Spacer()
                            Text(formatTime(row.seconds))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Playing Time")
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
