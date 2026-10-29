import Testing
@testable import Coaches_Assistant

/// Guards the additive `sport` parameter on `drillPrompt`/`DrillGenerating` —
/// Basketball's prompt (produced by the `.basketball` default) must stay
/// byte-identical to what it was before this parameter existed.
struct SportDrillPromptTests {
    @Test func basketballPromptIsByteIdenticalToTheOriginal() {
        let original = "Generate 5 basketball practice drills suitable for U12 players. For each drill, provide a short name followed by a 1-2 sentence description. Format as a numbered list with just the drill name and description, no extra headers."
        #expect(drillPrompt(ageGroup: "U12", sport: .basketball) == original)
    }

    @Test func everySportGetsItsOwnNounInThePrompt() {
        for sport in Sport.allCases {
            let prompt = drillPrompt(ageGroup: "U14", sport: sport)
            #expect(prompt.contains(sport.rules.drillNoun))
        }
    }
}
