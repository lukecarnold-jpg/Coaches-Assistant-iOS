import Testing
import UIKit
@testable import Coaches_Assistant

/// Guards against inventing SF Symbol names that don't exist on this SDK —
/// `figure.netball`, for example, does not exist and must never be used.
struct SportSymbolTests {

    @Test func everySportSymbolResolves() {
        for sport in Sport.allCases {
            #expect(UIImage(systemName: sport.rules.systemImage) != nil, "Missing symbol for \(sport.rawValue): \(sport.rules.systemImage)")
        }
    }

    @Test func everyDisciplineSymbolResolves() {
        for sport in Sport.allCases {
            for action in sport.rules.disciplineActions {
                #expect(UIImage(systemName: action.systemImage) != nil, "Missing symbol for \(sport.rawValue) discipline action \(action.code): \(action.systemImage)")
            }
        }
    }
}
