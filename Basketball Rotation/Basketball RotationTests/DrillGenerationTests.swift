import Testing
@testable import Basketball_Rotation

struct DrillGenerationTests {
    @Test func parsesNumberedListIntoIndividualDrills() {
        let text = """
        1. Layup Ladder — Players work through progressively harder layup angles.
        2. Shell Defense — 4-on-4 closeout and rotation drill.
        3. Full Court Weave — Passing and conditioning drill up and down the court.
        """
        let drills = parseDrillList(from: text)
        #expect(drills.count == 3)
        #expect(drills[0] == "Layup Ladder — Players work through progressively harder layup angles.")
        #expect(drills[2].hasPrefix("Full Court Weave"))
    }

    @Test func joinsWrappedLinesIntoTheSameDrill() {
        let text = """
        1. Layup Ladder — Players work through progressively
        harder layup angles as they move up the ladder.
        2. Shell Defense — 4-on-4 closeout drill.
        """
        let drills = parseDrillList(from: text)
        #expect(drills.count == 2)
        #expect(drills[0] == "Layup Ladder — Players work through progressively harder layup angles as they move up the ladder.")
    }

    @Test func stripsLeadingNumberingFromFinalOutput() {
        let text = "1. Pick and Roll — Two-player screen and read drill."
        let drills = parseDrillList(from: text)
        #expect(drills == ["Pick and Roll — Two-player screen and read drill."])
    }

    @Test func capsAtFiveDrillsEvenIfMoreAreProvided() {
        let text = (1...8).map { "\($0). Drill \($0) — description." }.joined(separator: "\n")
        let drills = parseDrillList(from: text)
        #expect(drills.count == 5)
    }

    @Test func blankInputProducesNoDrills() {
        #expect(parseDrillList(from: "").isEmpty)
        #expect(parseDrillList(from: "   \n  \n").isEmpty)
    }

    @Test func ignoresNonNumberedHeaderLines() {
        let text = """
        Here are your drills:
        1. Fast Break — 3-on-2 transition drill.
        """
        let drills = parseDrillList(from: text)
        #expect(drills.count == 1)
        #expect(drills[0].hasSuffix("transition drill."))
    }
}
