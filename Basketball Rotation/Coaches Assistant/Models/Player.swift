import Foundation
import SwiftData

@Model
final class Player {
    var playerID: UUID
    var name: String
    var jerseyNumber: Int?
    var createdAt: Date

    init(name: String, jerseyNumber: Int? = nil) {
        self.playerID = UUID()
        self.name = name
        self.jerseyNumber = jerseyNumber
        self.createdAt = Date()
    }

    var displayName: String {
        if let num = jerseyNumber {
            return "#\(num) \(name)"
        }
        return name
    }
}
