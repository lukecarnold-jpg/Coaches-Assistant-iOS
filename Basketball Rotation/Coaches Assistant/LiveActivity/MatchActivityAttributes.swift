import Foundation
import ActivityKit

/// Live Activity data for a match in progress. Compiled into both the app (which
/// starts, updates and ends the activity) and the MatchLiveActivity widget
/// extension (which renders it) — this one file is a member of both targets.
///
/// Keep it small: static plus dynamic data must stay under ActivityKit's 4 KB limit.
nonisolated struct MatchActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var teamScore: Int
        var opponentScore: Int
        var periodLabel: String
        /// Remaining time in the period when the clock is stopped.
        var remainingSeconds: Int
        /// When the clock is running, the moment the period ends — the widget
        /// renders a live countdown to it without the app pushing every second.
        var periodEndsAt: Date?
        var isEnded: Bool
    }

    /// `Fixture.fixtureID`, so the app can find the activity for a match.
    var matchID: String
    /// "Basketball", "Netball", … — shown as the activity's subtitle.
    var sportName: String
    /// SF Symbol for the sport.
    var sportSymbol: String
    var opponentName: String
}
