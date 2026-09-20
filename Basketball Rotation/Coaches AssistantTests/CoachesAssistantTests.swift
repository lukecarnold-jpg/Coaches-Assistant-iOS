import Testing
@testable import Coaches_Assistant

struct CoachesAssistantTests {

    @Test func deletionTargetAllCasesCoversAllSports() {
        let cases = DeletionTarget.allCases
        #expect(cases.contains(.basketballPlayers))
        #expect(cases.contains(.basketballGames))
        for sport in Sport.allCases where sport != .basketball {
            #expect(cases.contains(.squadPlayers(sport)))
            #expect(cases.contains(.fixtures(sport)))
        }
        #expect(cases.count == 2 + 2 * (Sport.allCases.count - 1))
    }

    @Test func deletionTargetIDsAreUnique() {
        let cases = DeletionTarget.allCases
        let ids = Set(cases.map(\.id))
        #expect(ids.count == cases.count)
    }
}
