import SwiftUI
import SwiftData

/// List of a sport's matches ("Games" for Basketball, "Fixtures" elsewhere).
struct FixtureListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var fixtures: [Fixture]

    let sport: Sport

    @State private var showNewFixture = false

    init(sport: Sport) {
        self.sport = sport
        let raw = sport.rawValue
        _fixtures = Query(filter: #Predicate<Fixture> { $0.sport == raw }, sort: \Fixture.date, order: .reverse)
    }

    var body: some View {
        Group {
            if fixtures.isEmpty {
                ContentUnavailableView("No \(sport.rules.matchTermPlural)", systemImage: "sportscourt", description: Text("Create a \(sport.rules.matchTerm.lowercased()) to start tracking."))
            } else {
                List {
                    ForEach(fixtures) { fixture in
                        NavigationLink(destination: FixtureDetailView(fixture: fixture)) {
                            FixtureRowView(fixture: fixture)
                        }
                    }
                    .onDelete(perform: deleteFixtures)
                }
            }
        }
        .navigationTitle(sport.rules.matchTermPlural)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewFixture = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New \(sport.rules.matchTerm.lowercased())")
            }
        }
        .sheet(isPresented: $showNewFixture) {
            FixtureSetupView(sport: sport)
        }
    }

    private func deleteFixtures(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(fixtures[index])
        }
    }
}

struct FixtureRowView: View {
    let fixture: Fixture

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("vs \(fixture.opponentName)")
                    .font(.headline)
                Spacer()
                if fixture.isEnded {
                    Text("Final")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.15), in: Capsule())
                } else {
                    Text(fixture.periodLabel)
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                }
            }
            HStack {
                Text(fixture.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(fixture.teamScore) – \(fixture.opponentScore)")
                    .font(.subheadline.bold())
            }
        }
        .padding(.vertical, 2)
    }
}
