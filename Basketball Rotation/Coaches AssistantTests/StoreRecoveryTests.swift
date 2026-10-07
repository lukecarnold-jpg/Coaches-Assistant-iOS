import Testing
import Foundation
@testable import Coaches_Assistant

@MainActor
struct StoreRecoveryTests {
    @Test func movesStoreAndSidecarsTogether() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = dir.appendingPathComponent("default.store")
        for suffix in ["", "-wal", "-shm"] {
            try Data(suffix.utf8).write(to: URL(fileURLWithPath: store.path + suffix))
        }

        let recovered = try #require(StoreRecoveryStatus.moveStoreAside(at: store, timestamp: "T1"))
        #expect(recovered.lastPathComponent == "store-recovered-T1.store")
        for suffix in ["", "-wal", "-shm"] {
            #expect(FileManager.default.fileExists(atPath: recovered.path + suffix), "missing \(suffix)")
            #expect(!FileManager.default.fileExists(atPath: store.path + suffix))
        }
    }

    @Test func missingSidecarsAreNotAnError() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = dir.appendingPathComponent("default.store")
        try Data().write(to: store)
        let recovered = StoreRecoveryStatus.moveStoreAside(at: store, timestamp: "T2")
        #expect(recovered != nil)
    }
}
