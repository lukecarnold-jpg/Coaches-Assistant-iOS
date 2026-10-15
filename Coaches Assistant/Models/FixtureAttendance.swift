import Foundation
import SwiftData

@Model
final class FixtureAttendance {
    var attendanceID: UUID
    var playerID: UUID
    var playerName: String
    var isAbsent: Bool
    var fixture: Fixture?

    init(fixture: Fixture?, playerID: UUID, playerName: String) {
        self.attendanceID = UUID()
        self.playerID = playerID
        self.playerName = playerName
        self.isAbsent = false
        self.fixture = fixture
    }
}
