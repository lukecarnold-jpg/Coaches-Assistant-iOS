import SwiftUI

/// Home for one sport: a TabView on iPhone and a NavigationSplitView sidebar on
/// iPad, scoped via `init(sport:)` so each tab's `@Query` predicate can be built
/// correctly. `SettingsView` is reused directly since it's app-level (AI provider,
/// appearance), not sport-scoped.
struct SportHomeView: View {
    let sport: Sport
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .compact {
                TabView {
                    NavigationStack { SquadRosterView(sport: sport) }
                        .tabItem { Label("Roster", systemImage: "person.3.fill") }

                    if sport.rules.isStatsOnly {
                        NavigationStack { CricketMatchListView() }
                            .tabItem { Label("Matches", systemImage: "list.bullet.rectangle.fill") }

                        NavigationStack { CricketSeasonStatsView() }
                            .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                    } else {
                        NavigationStack { FixtureListView(sport: sport) }
                            .tabItem { Label(sport.rules.matchTermPlural, systemImage: "sportscourt.fill") }
                    }

                    NavigationStack { SportTrainingView(sport: sport) }
                        .tabItem { Label("Training", systemImage: "figure.run") }

                    NavigationStack { SettingsView() }
                        .tabItem { Label("Settings", systemImage: "gear") }
                }
            } else {
                SportSidebarNavigationView(sport: sport)
            }
        }
        .environment(\.sport, sport)
    }
}

private struct SportSidebarNavigationView: View {
    let sport: Sport
    @State private var selectedTab: SportTab? = .roster

    enum SportTab: String, CaseIterable, Hashable {
        case roster    = "Roster"
        case fixtures  = "Fixtures"
        case matches   = "Matches"
        case stats     = "Stats"
        case training  = "Training"
        case settings  = "Settings"

        var systemImage: String {
            switch self {
            case .roster:   return "person.3.fill"
            case .fixtures: return "sportscourt.fill"
            case .matches:  return "list.bullet.rectangle.fill"
            case .stats:    return "chart.bar.fill"
            case .training: return "figure.run"
            case .settings: return "gear"
            }
        }

        /// Sidebar label — the match tab uses the sport's own term ("Games").
        func title(for sport: Sport) -> String {
            self == .fixtures ? sport.rules.matchTermPlural : rawValue
        }

        /// Stats-only sports (Cricket) record scorecards instead of live fixtures.
        static func tabs(for sport: Sport) -> [SportTab] {
            sport.rules.isStatsOnly
                ? [.roster, .matches, .stats, .training, .settings]
                : [.roster, .fixtures, .training, .settings]
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SportTab.tabs(for: sport), id: \.self, selection: $selectedTab) { tab in
                Label(tab.title(for: sport), systemImage: tab.systemImage)
                    .tag(tab)
            }
            .navigationTitle(sport.rules.displayName)
        } detail: {
            NavigationStack {
                switch selectedTab {
                case .roster:   SquadRosterView(sport: sport)
                case .fixtures: FixtureListView(sport: sport)
                case .matches:  CricketMatchListView()
                case .stats:    CricketSeasonStatsView()
                case .training: SportTrainingView(sport: sport)
                case .settings: SettingsView()
                case nil:       SquadRosterView(sport: sport)
                }
            }
        }
    }
}
