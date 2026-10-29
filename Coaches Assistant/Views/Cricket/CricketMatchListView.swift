import SwiftUI
import SwiftData

/// Cricket's equivalent of `FixtureListView`. Cricket is stats-only, so each match
/// is a scorecard (`CricketMatch`) rather than a live clock/rotation `Fixture`.
struct CricketMatchListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CricketMatch.date, order: .reverse) private var matches: [CricketMatch]

    @State private var showNewMatch = false

    var body: some View {
        Group {
            if matches.isEmpty {
                ContentUnavailableView("No Matches", systemImage: "figure.cricket", description: Text("Add a match to record batting, bowling and fielding stats."))
            } else {
                List {
                    ForEach(matches) { match in
                        NavigationLink(destination: CricketMatchDetailView(match: match)) {
                            CricketMatchRowView(match: match)
                        }
                    }
                    .onDelete(perform: deleteMatches)
                }
            }
        }
        .navigationTitle("Matches")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewMatch = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New match")
            }
        }
        .sheet(isPresented: $showNewMatch) {
            CricketMatchSetupView()
        }
    }

    private func deleteMatches(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(matches[index])
        }
    }
}

struct CricketMatchRowView: View {
    let match: CricketMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("vs \(match.opponentName)")
                    .font(.headline)
                Spacer()
                if let result = match.result {
                    Text(result.summary)
                        .font(.caption.bold())
                        .foregroundStyle(result.outcome.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(result.outcome.tint.opacity(0.12), in: Capsule())
                } else {
                    Text("In Progress")
                        .font(.caption.bold())
                        .foregroundStyle(Sport.cricket.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Sport.cricket.tint.opacity(0.12), in: Capsule())
                }
            }
            HStack {
                Text(match.date, style: .date)
                Spacer()
                Text("\(match.ourScoreLine)  v  \(match.theirScoreLine)")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

extension CricketResult.Outcome {
    var tint: Color {
        switch self {
        case .won: return .green
        case .lost: return .red
        case .tied: return .orange
        }
    }
}
