import ActivityKit
import Foundation

/// Starts, updates and ends the Lock Screen / Dynamic Island Live Activity for a
/// live match. Driven from `FixtureDetailView` whenever the match state changes.
@MainActor
enum MatchLiveActivityController {
    /// How long a finished match's final score stays on the Lock Screen.
    static let finalScoreLingers: TimeInterval = 15 * 60

    /// The activity content for a match. Deterministic (no "now") so it can be
    /// used to detect changes: a running clock is expressed as the moment the
    /// period ends, which the widget turns into a system-rendered countdown.
    nonisolated static func state(for fixture: Fixture) -> MatchActivityAttributes.ContentState {
        let periodEndsAt: Date? = {
            guard fixture.clockIsRunning, let startedAt = fixture.clockStartedAt, !fixture.isEnded else { return nil }
            return startedAt.addingTimeInterval(TimeInterval(fixture.periodLengthSeconds - fixture.elapsedSeconds))
        }()
        return MatchActivityAttributes.ContentState(
            teamScore: fixture.teamScore,
            opponentScore: fixture.opponentScore,
            periodLabel: fixture.periodLabel,
            remainingSeconds: fixture.remainingSeconds(at: min(fixture.elapsedSeconds, fixture.periodLengthSeconds)),
            periodEndsAt: periodEndsAt,
            isEnded: fixture.isEnded
        )
    }

    nonisolated static func attributes(for fixture: Fixture) -> MatchActivityAttributes {
        MatchActivityAttributes(
            matchID: fixture.fixtureID.uuidString,
            sportName: fixture.rules.displayName,
            sportSymbol: fixture.rules.systemImage,
            opponentName: fixture.opponentName
        )
    }

    /// Brings the Live Activity in line with the match: starts one the first time
    /// the clock runs, updates it on every change, and ends it at full time.
    static func sync(_ fixture: Fixture) {
        let matchID = fixture.fixtureID.uuidString
        let isEnded = fixture.isEnded
        let content = ActivityContent(state: state(for: fixture), staleDate: nil)

        if activity(for: matchID) != nil {
            Task { await apply(content, toMatch: matchID, ending: isEnded) }
            return
        }

        // Only start once the match is actually underway, and only if the person
        // allows Live Activities for the app.
        guard !isEnded, fixture.clockIsRunning, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            _ = try Activity.request(attributes: attributes(for: fixture), content: content)
        } catch {
            print("Couldn't start Live Activity: \(error)")
        }
    }

    nonisolated private static func activity(for matchID: String) -> Activity<MatchActivityAttributes>? {
        Activity<MatchActivityAttributes>.activities.first { $0.attributes.matchID == matchID }
    }

    /// `Activity` isn't Sendable, so it's looked up and updated in one concurrent
    /// context; only the match ID and plain (Sendable) content cross actors.
    @concurrent
    nonisolated private static func apply(_ content: ActivityContent<MatchActivityAttributes.ContentState>, toMatch matchID: String, ending: Bool) async {
        guard let existing = activity(for: matchID) else { return }
        if ending {
            await existing.end(content, dismissalPolicy: .after(.now.addingTimeInterval(finalScoreLingers)))
        } else {
            await existing.update(content)
        }
    }
}
