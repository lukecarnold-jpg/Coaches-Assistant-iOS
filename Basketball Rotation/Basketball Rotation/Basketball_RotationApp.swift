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
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // If the store is corrupt or schema-incompatible, wipe and restart clean.
            let storeURL = config.url
            let related = [storeURL,
                           storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"),
                           storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")]
            related.forEach { try? FileManager.default.removeItem(at: $0) }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
