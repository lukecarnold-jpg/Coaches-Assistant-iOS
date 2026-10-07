import SwiftUI
import SwiftData

/// Granular categories of data that can be selected for deletion.
nonisolated enum DeletionTarget: Hashable, Identifiable {
    case basketballPlayers
    case basketballGames
    case squadPlayers(Sport)
    case fixtures(Sport)

    var id: String {
        switch self {
        case .basketballPlayers:
            return "basketball_players"
        case .basketballGames:
            return "basketball_games"
        case .squadPlayers(let sport):
            return "squad_players_\(sport.rawValue)"
        case .fixtures(let sport):
            return "fixtures_\(sport.rawValue)"
        }
    }

    static var allCases: [DeletionTarget] {
        var targets: [DeletionTarget] = [.basketballPlayers, .basketballGames]
        for sport in Sport.allCases where sport != .basketball {
            targets.append(.squadPlayers(sport))
            targets.append(.fixtures(sport))
        }
        return targets
    }
}

/// A modal sheet presenting selectable data categories for deletion, including an option for all data.
struct DataDeletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var players: [Player]
    @Query private var games: [Game]
    @Query private var squadPlayers: [SquadPlayer]
    @Query private var fixtures: [Fixture]
    @Query private var cricketMatches: [CricketMatch]

    @State private var selectedTargets: Set<DeletionTarget> = []
    @State private var showConfirmDialog = false

    var onDataDeleted: () -> Void

    private var allTargets: [DeletionTarget] {
        DeletionTarget.allCases
    }

    private var isAllSelected: Bool {
        !allTargets.isEmpty && selectedTargets.count == allTargets.count
    }

    private var totalDataCount: Int {
        players.count + games.count + squadPlayers.count + fixtures.count + cricketMatches.count
    }

    private var totalSelectedCount: Int {
        var count = 0
        if selectedTargets.contains(.basketballPlayers) { count += players.count }
        if selectedTargets.contains(.basketballGames) { count += games.count }
        for sport in Sport.allCases where sport != .basketball {
            if selectedTargets.contains(.squadPlayers(sport)) {
                count += squadPlayers.filter { $0.sport == sport.rawValue }.count
            }
            if selectedTargets.contains(.fixtures(sport)) {
                count += matchCount(for: sport)
            }
        }
        return count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        toggleAll()
                    } label: {
                        HStack {
                            Image(systemName: isAllSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isAllSelected ? .red : .secondary)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("All Data")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Select everything across all sports")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(totalDataCount)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Selecting All Data will remove all players, squads, games, fixtures, cricket matches, and events on this device.")
                }

                sportSection(for: .basketball)

                ForEach(Sport.allCases.filter { $0 != .basketball }) { sport in
                    sportSection(for: sport)
                }
            }
            .navigationTitle("Delete Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .destructive) {
                        showConfirmDialog = true
                    } label: {
                        Text(selectedTargets.isEmpty ? "Delete" : "Delete (\(totalSelectedCount))")
                            .fontWeight(.semibold)
                    }
                    .disabled(selectedTargets.isEmpty)
                }
            }
            .confirmationDialog(
                "Delete Selected Data",
                isPresented: $showConfirmDialog,
                titleVisibility: .visible
            ) {
                Button(
                    isAllSelected ? "Delete All Data" : "Delete Selected Data (\(totalSelectedCount) items)",
                    role: .destructive
                ) {
                    performDeletion()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    isAllSelected
                    ? "This permanently removes all players, squads, games, fixtures, and events from this device. This cannot be undone."
                    : "This permanently removes the selected items and their associated event history. This cannot be undone."
                )
            }
        }
    }

    @ViewBuilder
    private func sportSection(for sport: Sport) -> some View {
        Section {
            if sport == .basketball {
                targetRow(
                    target: .basketballPlayers,
                    title: "Players",
                    count: players.count,
                    icon: "person.2"
                )
                targetRow(
                    target: .basketballGames,
                    title: "Games & History",
                    count: games.count,
                    icon: "clock.arrow.circlepath"
                )
            } else {
                let sportSquad = squadPlayers.filter { $0.sport == sport.rawValue }

                targetRow(
                    target: .squadPlayers(sport),
                    title: "Squad Players",
                    count: sportSquad.count,
                    icon: "person.2"
                )
                targetRow(
                    target: .fixtures(sport),
                    title: sport.rules.isStatsOnly ? "Matches & Stats" : "Fixtures & History",
                    count: matchCount(for: sport),
                    icon: "clock.arrow.circlepath"
                )
            }
        } header: {
            HStack {
                Label(sport.rules.displayName, systemImage: sport.rules.systemImage)
                    .foregroundStyle(sport.tint)
                Spacer()
                Button(isSportFullySelected(sport) ? "Deselect" : "Select") {
                    toggleSport(sport)
                }
                .font(.caption)
                .textCase(nil)
            }
        }
    }

    private func targetRow(target: DeletionTarget, title: String, count: Int, icon: String) -> some View {
        Button {
            toggleTarget(target)
        } label: {
            HStack {
                Image(systemName: selectedTargets.contains(target) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedTargets.contains(target) ? .red : .secondary)
                    .font(.title3)
                Label(title, systemImage: icon)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Fixtures for timed sports; scorecards for stats-only Cricket.
    private func matchCount(for sport: Sport) -> Int {
        sport.rules.isStatsOnly ? cricketMatches.count : fixtures.filter { $0.sport == sport.rawValue }.count
    }

    private func isSportFullySelected(_ sport: Sport) -> Bool {
        let targets = sportTargets(for: sport)
        return targets.allSatisfy { selectedTargets.contains($0) }
    }

    private func sportTargets(for sport: Sport) -> [DeletionTarget] {
        if sport == .basketball {
            return [.basketballPlayers, .basketballGames]
        } else {
            return [.squadPlayers(sport), .fixtures(sport)]
        }
    }

    private func toggleSport(_ sport: Sport) {
        let targets = sportTargets(for: sport)
        if isSportFullySelected(sport) {
            for target in targets {
                selectedTargets.remove(target)
            }
        } else {
            for target in targets {
                selectedTargets.insert(target)
            }
        }
    }

    private func toggleTarget(_ target: DeletionTarget) {
        if selectedTargets.contains(target) {
            selectedTargets.remove(target)
        } else {
            selectedTargets.insert(target)
        }
    }

    private func toggleAll() {
        if isAllSelected {
            selectedTargets.removeAll()
        } else {
            selectedTargets = Set(allTargets)
        }
    }

    private func performDeletion() {
        do {
            if isAllSelected {
                try modelContext.delete(model: GameEvent.self)
                try modelContext.delete(model: GameAttendance.self)
                try modelContext.delete(model: Game.self)
                try modelContext.delete(model: Player.self)
                try modelContext.delete(model: FixtureLineupSlot.self)
                try modelContext.delete(model: FixtureEvent.self)
                try modelContext.delete(model: FixtureAttendance.self)
                try modelContext.delete(model: Fixture.self)
                try modelContext.delete(model: SquadPlayer.self)
                try modelContext.delete(model: CricketPlayerStats.self)
                try modelContext.delete(model: CricketMatch.self)
            } else {
                if selectedTargets.contains(.basketballGames) {
                    for game in games {
                        for event in game.events {
                            modelContext.delete(event)
                        }
                        for attendance in game.attendances {
                            modelContext.delete(attendance)
                        }
                        modelContext.delete(game)
                    }
                }
                if selectedTargets.contains(.basketballPlayers) {
                    for player in players {
                        modelContext.delete(player)
                    }
                }

                for sport in Sport.allCases where sport != .basketball {
                    if sport.rules.isStatsOnly, selectedTargets.contains(.fixtures(sport)) {
                        for match in cricketMatches {
                            for line in match.playerStats {
                                modelContext.delete(line)
                            }
                            modelContext.delete(match)
                        }
                    } else if selectedTargets.contains(.fixtures(sport)) {
                        let matchingFixtures = fixtures.filter { $0.sport == sport.rawValue }
                        for fixture in matchingFixtures {
                            for slot in fixture.lineupSlots {
                                modelContext.delete(slot)
                            }
                            for event in fixture.events {
                                modelContext.delete(event)
                            }
                            for attendance in fixture.attendances {
                                modelContext.delete(attendance)
                            }
                            modelContext.delete(fixture)
                        }
                    }
                    if selectedTargets.contains(.squadPlayers(sport)) {
                        let matchingPlayers = squadPlayers.filter { $0.sport == sport.rawValue }
                        for player in matchingPlayers {
                            modelContext.delete(player)
                        }
                    }
                }
            }
            try modelContext.save()
            onDataDeleted()
            dismiss()
        } catch {
            print("Failed to delete selected data: \(error)")
        }
    }
}
