import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .compact {
            TabView {
                NavigationStack {
                    RosterView()
                }
                .tabItem { Label("Roster", systemImage: "person.3.fill") }

                NavigationStack {
                    GameListView()
                }
                .tabItem { Label("Games", systemImage: "sportscourt.fill") }

                NavigationStack {
                    TrainingView()
                }
                .tabItem { Label("Training", systemImage: "figure.basketball") }

                NavigationStack {
                    SettingsView()
                }
                .tabItem { Label("Settings", systemImage: "gear") }
            }
        } else {
            SidebarNavigationView()
        }
    }
}

struct SidebarNavigationView: View {
    @State private var selectedTab: SidebarTab? = .roster

    enum SidebarTab: String, CaseIterable, Hashable {
        case roster   = "Roster"
        case games    = "Games"
        case training = "Training"
        case settings = "Settings"

        var systemImage: String {
            switch self {
            case .roster:   return "person.3.fill"
            case .games:    return "sportscourt.fill"
            case .training: return "figure.basketball"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.systemImage)
                    .tag(tab)
            }
            .navigationTitle("Basketball Rotation")
        } detail: {
            NavigationStack {
                switch selectedTab {
                case .roster:   RosterView()
                case .games:    GameListView()
                case .training: TrainingView()
                case .settings: SettingsView()
                case nil:       RosterView()
                }
            }
        }
    }
}
