import SwiftUI

/// App root. Swaps between the landing grid and a sport home rather than pushing
/// onto a `NavigationStack` — a push would nest Basketball's own `TabView`/
/// `NavigationSplitView` inside an outer stack, and a full subtree rebuild is
/// needed anyway so each sport's `@Query` predicates re-evaluate. No "last sport"
/// is persisted, so the grid reappears on every launch.
struct RootView: View {
    @State private var selectedSport: Sport?

    var body: some View {
        Group {
            if let sport = selectedSport {
                SportChrome(sport: sport, onChangeSport: {
                    withAnimation { selectedSport = nil }
                }) {
                    destination(for: sport)
                }
                .transition(.opacity)
            } else {
                SportSelectionView { sport in
                    withAnimation { selectedSport = sport }
                }
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func destination(for sport: Sport) -> some View {
        if sport == .basketball {
            // Untouched — Basketball keeps its own models and views entirely.
            ContentView()
        } else {
            SportHomeView(sport: sport)
        }
    }
}
