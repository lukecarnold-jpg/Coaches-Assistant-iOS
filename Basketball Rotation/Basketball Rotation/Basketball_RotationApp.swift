import SwiftUI
import SwiftData

@main
struct Basketball_RotationApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Player.self,
            Game.self,
            GameEvent.self,
            GameAttendance.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
