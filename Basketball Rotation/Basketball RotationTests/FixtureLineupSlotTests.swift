import Testing
import Foundation
@testable import Basketball_Rotation

struct FixtureLineupSlotTests {
    @Test func positionIsNilWhenUnassigned() {
        let fixture = Fixture(sport: .netball, opponentName: "Magpies", periodFormat: "quarters", periodLengthMinutes: 15)
        let playerID = UUID()
        #expect(fixture.position(for: playerID) == nil)
    }

    @Test func settingAndClearingAPosition() {
        let fixture = Fixture(sport: .netball, opponentName: "Magpies", periodFormat: "quarters", periodLengthMinutes: 15)
        let playerID = UUID()
        let slot = FixtureLineupSlot(fixture: fixture, playerID: playerID, playerName: "Jordan", positionCode: "GS")
        fixture.lineupSlots.append(slot)

        #expect(fixture.position(for: playerID)?.code == "GS")

        slot.positionCode = ""
        #expect(fixture.position(for: playerID) == nil)
    }

    @Test func lineupSlotLookupFindsExistingSlot() {
        let fixture = Fixture(sport: .soccer, opponentName: "United", periodFormat: "halves", periodLengthMinutes: 45)
        let playerID = UUID()
        let slot = FixtureLineupSlot(fixture: fixture, playerID: playerID, playerName: "Green", positionCode: "MID")
        fixture.lineupSlots.append(slot)

        #expect(fixture.lineupSlot(for: playerID) === slot)
        #expect(fixture.lineupSlot(for: UUID()) == nil)
    }
}
