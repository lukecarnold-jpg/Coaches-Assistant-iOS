import SwiftUI
import SwiftData

struct PlayingTimeView: View {
    @Query(sort: \Player.name) private var allPlayers: [Player]
    @Bindable var game: Game

    private var presentPlayers: [Player] {
        let absentIDs = Set(game.attendances.filter { $0.isAbsent }.map { $0.playerID })
        return allPlayers.filter { !absentIDs.contains($0.playerID) }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            let totals = game.minutesPlayedSeconds()
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
                                if game.isOnCourt(row.player) {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 8, height: 8)
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
