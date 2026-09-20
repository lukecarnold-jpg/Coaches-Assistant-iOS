import Foundation
import SwiftData

/// Per-fixture player→position assignment. A separate entity (mirroring
/// `FixtureAttendance`'s shape) rather than an encoded field on `onFieldPlayerIDs`,
/// because a position's lifetime is independent of on-field status — a benched
/// substitute still has a position — and it would otherwise need to stay in sync
/// across every substitution/lineup mutation site. Created lazily: only once a
/// position is actually assigned.
@Model
final class FixtureLineupSlot {
    var slotID: UUID
    var playerID: UUID
    var playerName: String
    var positionCode: String
    var fixture: Fixture?

    init(fixture: Fixture?, playerID: UUID, playerName: String, positionCode: String) {
        self.slotID = UUID()
        self.playerID = playerID
        self.playerName = playerName
        self.positionCode = positionCode
        self.fixture = fixture
    }
}
