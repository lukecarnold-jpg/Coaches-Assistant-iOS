import SwiftUI
import SwiftData

/// App root. Swaps between the landing grid and a sport home rather than pushing
/// onto a `NavigationStack` — a push would nest the sport home's own `TabView`/
/// `NavigationSplitView` inside an outer stack, and a full subtree rebuild is
/// needed anyway so each sport's `@Query` predicates re-evaluate. No "last sport"
/// is persisted, so the grid reappears on every launch.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSport: Sport?

    var body: some View {
        content
            .onChange(of: scenePhase) { _, phase in
                // Autosave runs on its own schedule; flush explicitly when leaving the
                // foreground so a mid-game score isn't lost if the app is then killed.
                guard phase != .active, modelContext.hasChanges else { return }
                do {
                    try modelContext.save()
                } catch {
                    print("Failed to save on background: \(error)")
                }
            }
    }

    private var content: some View {
        Group {
            if let sport = selectedSport {
                SportChrome(sport: sport, onChangeSport: {
                    withAnimation { selectedSport = nil }
                }) {
                    SportHomeView(sport: sport)
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
}
