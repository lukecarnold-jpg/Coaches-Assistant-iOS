import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island presentation of a live match: score, period
/// and a countdown clock that the system ticks without app updates.
struct MatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .padding()
                .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                // Inset from the rounded edges so names aren't clipped.
                DynamicIslandExpandedRegion(.leading) {
                    ScoreColumn(title: "US", score: context.state.teamScore)
                        .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ScoreColumn(title: context.attributes.opponentName, score: context.state.opponentScore)
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Label(context.attributes.sportName, systemImage: context.attributes.sportSymbol)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ClockText(state: context.state)
                            .font(.title3.monospacedDigit().bold())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isEnded ? "Final" : context.state.periodLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text("\(context.state.teamScore)–\(context.state.opponentScore)")
                    .font(.caption.monospacedDigit().bold())
                    .accessibilityLabel("Us \(context.state.teamScore), \(context.attributes.opponentName) \(context.state.opponentScore)")
            } compactTrailing: {
                ClockText(state: context.state)
                    .font(.caption.monospacedDigit())
                    .frame(maxWidth: 52)
            } minimal: {
                Text("\(context.state.teamScore)")
                    .font(.caption.monospacedDigit().bold())
                    .accessibilityLabel("Our score \(context.state.teamScore)")
            }
        }
    }
}

private struct LockScreenView: View {
    let attributes: MatchActivityAttributes
    let state: MatchActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(attributes.sportName, systemImage: attributes.sportSymbol)
                    .font(.caption.bold())
                Spacer()
                Text(state.isEnded ? "Final" : state.periodLabel)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            HStack {
                ScoreColumn(title: "US", score: state.teamScore)
                Spacer()
                ClockText(state: state)
                    .font(.title2.monospacedDigit().bold())
                Spacer()
                ScoreColumn(title: attributes.opponentName, score: state.opponentScore)
            }
        }
    }
}

private struct ScoreColumn: View {
    let title: String
    let score: Int

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: 90)
            Text("\(score)")
                .font(.title.monospacedDigit().bold())
        }
        .accessibilityElement(children: .combine)
    }
}

/// A live countdown while the clock runs (rendered by the system, so it keeps
/// ticking without app updates); the frozen remaining time otherwise.
private struct ClockText: View {
    let state: MatchActivityAttributes.ContentState

    var body: some View {
        if state.isEnded {
            Text("Final")
        } else if let endsAt = state.periodEndsAt, endsAt > .now {
            Text(timerInterval: Date.now...endsAt, countsDown: true)
                .multilineTextAlignment(.center)
        } else {
            Text(String(format: "%02d:%02d", state.remainingSeconds / 60, state.remainingSeconds % 60))
        }
    }
}

#Preview("Lock Screen", as: .content, using: MatchActivityAttributes(matchID: "preview", sportName: "Basketball", sportSymbol: "figure.basketball", opponentName: "Wildcats")) {
    MatchLiveActivity()
} contentStates: {
    MatchActivityAttributes.ContentState(teamScore: 42, opponentScore: 38, periodLabel: "3rd Quarter", remainingSeconds: 312, periodEndsAt: nil, isEnded: false)
    MatchActivityAttributes.ContentState(teamScore: 61, opponentScore: 55, periodLabel: "4th Quarter", remainingSeconds: 0, periodEndsAt: nil, isEnded: true)
}
