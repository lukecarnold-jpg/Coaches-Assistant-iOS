import SwiftUI
import SwiftData

/// Set when the on-disk store couldn't be opened and was moved aside rather than
/// deleted. Settings surfaces this so a failed migration is never silent.
enum StoreRecoveryStatus {
    static var wasReset = false
    static var recoveredStoreURL: URL?

    /// SQLite keeps uncommitted pages in sidecar files named by appending `-wal` /
    /// `-shm` to the *full* store filename (e.g. `default.store-wal`). All three must
    /// move together or the recovered copy is missing its most recent writes.
    static let sidecarSuffixes = ["", "-wal", "-shm"]

    /// Moves the store and its sidecars to `store-recovered-<timestamp>.<ext>` in the
    /// same directory. Returns the recovered main-file URL, or nil if nothing moved.
    @discardableResult
    static func moveStoreAside(at storeURL: URL, timestamp: String, fileManager: FileManager = .default) -> URL? {
        let directory = storeURL.deletingLastPathComponent()
        let ext = storeURL.pathExtension.isEmpty ? "store" : storeURL.pathExtension
        let recoveredURL = directory.appendingPathComponent("store-recovered-\(timestamp).\(ext)")
        var movedMain = false
        for suffix in sidecarSuffixes {
            let source = URL(fileURLWithPath: storeURL.path + suffix)
            let destination = URL(fileURLWithPath: recoveredURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            do {
                try fileManager.moveItem(at: source, to: destination)
                if suffix.isEmpty { movedMain = true }
            } catch {
                print("Store recovery: failed to move \(source.lastPathComponent): \(error)")
            }
        }
        return movedMain ? recoveredURL : nil
    }
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
            CricketMatch.self,
            CricketPlayerStats.self,
        ])
        // UI tests launch with `-uiTesting` so each run starts empty and never
        // touches a real on-disk store.
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            LegacyBasketballMigration.migrateIfNeeded(context: container.mainContext)
            return container
        } catch {
            // If the store is corrupt or schema-incompatible, move it aside rather
            // than delete it — a failed migration should never silently destroy a
            // coach's existing data. The recovered file is left on disk for support
            // purposes; SettingsView surfaces that this happened.
            print("ModelContainer failed to open store: \(error)")
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let recoveredURL = StoreRecoveryStatus.moveStoreAside(at: config.url, timestamp: timestamp)
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
