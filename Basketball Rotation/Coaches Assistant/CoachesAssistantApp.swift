import SwiftUI
import SwiftData

/// Set when the on-disk store couldn't be opened and was moved aside rather than
/// deleted. Settings surfaces this so a failed migration is never silent.
enum StoreRecoveryStatus {
    static var wasReset = false
    static var recoveredStoreURL: URL?
}

@main
struct CoachesAssistantApp: App {
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Player.self,
            Game.self,
            GameEvent.self,
            GameAttendance.self,
            SquadPlayer.self,
            Fixture.self,
            FixtureEvent.self,
            FixtureAttendance.self,
            FixtureLineupSlot.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // If the store is corrupt or schema-incompatible, move it aside rather
            // than delete it — a failed migration should never silently destroy a
            // coach's existing data. The recovered file is left on disk for support
            // purposes; SettingsView surfaces that this happened.
            let storeURL = config.url
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let recoveredURL = storeURL.deletingLastPathComponent().appendingPathComponent("store-recovered-\(timestamp).sqlite")
            let related: [(URL, String)] = [
                (storeURL, ".sqlite"),
                (storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"), "-shm"),
                (storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"), "-wal"),
            ]
            for (url, suffix) in related {
                let destination = recoveredURL.deletingPathExtension().appendingPathExtension(suffix.replacingOccurrences(of: ".", with: ""))
                try? FileManager.default.moveItem(at: url, to: destination)
            }
            StoreRecoveryStatus.wasReset = true
            StoreRecoveryStatus.recoveredStoreURL = recoveredURL
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(selectedColorScheme)
        }
        .modelContainer(sharedModelContainer)
    }

    private var selectedColorScheme: ColorScheme? {
        switch AppearanceMode(rawValue: appearanceMode) ?? .system {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
