import SwiftUI
import SwiftData

struct GameListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Game.date, order: .reverse) private var games: [Game]

    @State private var showNewGame = false

    var body: some View {
        Group {
            if games.isEmpty {
                ContentUnavailableView("No Games", systemImage: "sportscourt", description: Text("Create a game to start tracking."))
            } else {
                List {
                    ForEach(games) { game in
                        NavigationLink(destination: GameDetailView(game: game)) {
                            GameRowView(game: game)
                        }
                    }
                    .onDelete(perform: deleteGames)
                }
            }
        }
        .navigationTitle("Games")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewGame = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewGame) {
            GameSetupView()
        }
    }

    private func deleteGames(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(games[index])
        }
    }
}

struct GameRowView: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("vs \(game.opponentName)")
                    .font(.headline)
                Spacer()
                if game.isEnded {
                    Text("Final")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.15), in: Capsule())
                } else {
                    Text(game.periodLabel)
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                }
            }
            HStack {
                Text(game.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(game.teamScore) – \(game.opponentScore)")
                    .font(.subheadline.bold())
            }
        }
        .padding(.vertical, 2)
    }
}
