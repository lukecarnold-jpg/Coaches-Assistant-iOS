import SwiftUI
import UIKit

// Building blocks for `FixtureDetailView` (every timed sport). Each takes any
// `TimedMatch`, so they stay independent of a particular model.

// MARK: - Scoreboard

struct MatchScoreboard<Match: TimedMatch>: View {
    let match: Match
    let tint: Color
    let onTeamMinus: () -> Void
    let onTeamPlus: () -> Void
    let onOpponentMinus: () -> Void
    let onOpponentPlus: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 46

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(match.isEnded ? "Final" : match.periodLabel)
                    .font(.caption.bold())
                    .foregroundStyle(match.isEnded ? Color.gray : tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(match.isEnded ? Color.gray.opacity(0.15) : tint.opacity(0.1), in: Capsule())

                if match.isGameDayModeActive && !match.isEnded {
                    GameDayModeBadge()
                }
            }

            HStack(spacing: 0) {
                scoreColumn(
                    title: "US",
                    score: match.teamScore,
                    plusTint: tint,
                    teamLabel: "our team",
                    onMinus: onTeamMinus,
                    onPlus: onTeamPlus
                )

                Text("–")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                scoreColumn(
                    title: match.opponentName,
                    score: match.opponentScore,
                    plusTint: .orange,
                    teamLabel: match.opponentName,
                    onMinus: onOpponentMinus,
                    onPlus: onOpponentPlus
                )
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func scoreColumn(title: String, score: Int, plusTint: Color, teamLabel: String, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(score)")
                .font(.system(size: scoreSize, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityLabel("\(title) score \(score)")
            if !match.isEnded {
                HStack(spacing: 8) {
                    Button(action: onMinus) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Subtract a point from \(teamLabel)")
                    .disabled(score == 0)

                    Button(action: onPlus) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(plusTint)
                    }
                    .accessibilityLabel("Add score for \(teamLabel)")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct GameDayModeBadge: View {
    var body: some View {
        Label("Game Day Mode", systemImage: "sun.max.fill")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Color.indigo, in: Capsule())
            .accessibilityHint("The screen stays awake while the game is live.")
    }
}

// MARK: - Clock

/// Remaining/elapsed display plus start/stop, reset (confirmed) and manual set.
/// Stops the clock automatically once the period's time is up.
struct MatchClockSection<Match: TimedMatch>: View {
    let match: Match
    /// Called after the coach confirms a reset — the owner logs the event.
    let onReset: () -> Void

    @State private var showResetConfirm = false
    @State private var showManualClock = false
    @ScaledMetric(relativeTo: .title) private var clockSize: CGFloat = 30

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let elapsed = match.currentElapsedSeconds(now: context.date)
            let remaining = match.remainingSeconds(at: elapsed)
            VStack(spacing: 8) {
                HStack {
                    clockReading(formatClock(remaining), caption: "Remaining")
                    Divider().frame(height: 42)
                    clockReading(formatClock(elapsed), caption: "Elapsed")
                }

                if !match.isEnded {
                    HStack(spacing: 16) {
                        Button {
                            match.toggleClock()
                        } label: {
                            Label(match.clockIsRunning ? "Stop" : "Start", systemImage: match.clockIsRunning ? "stop.fill" : "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(match.clockIsRunning ? .red : .green)
                        .disabled(!match.clockIsRunning && remaining == 0)

                        Button {
                            showResetConfirm = true
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title2)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Reset clock")
                        // Attached to the button so the iPhone popover points at it.
                        .confirmationDialog("Reset Clock", isPresented: $showResetConfirm) {
                            Button("Reset to \(formatClock(match.periodLengthSeconds))", role: .destructive) {
                                onReset()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("The clock for the \(match.periodLabel) will go back to the start. This is recorded in the event history.")
                        }

                        Button {
                            showManualClock = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.title2)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Set clock manually")
                    }
                }

                if remaining == 0 && !match.isEnded {
                    Text("\(match.periodLabel) time is up")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .onChange(of: remaining == 0) { _, expired in
                if expired && match.clockIsRunning {
                    match.stopClock()
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            }
        }
        .sheet(isPresented: $showManualClock) {
            ManualClockView(
                periodLengthSeconds: match.periodLengthSeconds,
                initialRemaining: match.remainingSeconds(at: match.currentElapsedSeconds())
            ) { minutes, seconds in
                match.setRemainingTime(minutes: minutes, seconds: seconds)
            }
        }
    }

    private func clockReading(_ value: String, caption: String) -> some View {
        VStack {
            Text(value)
                .font(.system(size: clockSize, weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct ManualClockView: View {
    @Environment(\.dismiss) private var dismiss
    let periodLengthSeconds: Int
    let onApply: (_ minutes: Int, _ seconds: Int) -> Void

    @State private var minutes: String
    @State private var seconds: String

    init(periodLengthSeconds: Int, initialRemaining: Int, onApply: @escaping (_ minutes: Int, _ seconds: Int) -> Void) {
        self.periodLengthSeconds = periodLengthSeconds
        self.onApply = onApply
        _minutes = State(initialValue: String(initialRemaining / 60))
        _seconds = State(initialValue: String(format: "%02d", initialRemaining % 60))
    }

    private var parsed: (minutes: Int, seconds: Int)? {
        guard let m = Int(minutes.isEmpty ? "0" : minutes), let s = Int(seconds.isEmpty ? "0" : seconds) else { return nil }
        return (m, s)
    }

    /// Mirrors `TimedMatch.isValidRemainingTime` without needing the match itself.
    private var isValid: Bool {
        guard let parsed else { return false }
        return parsed.minutes >= 0 && (0...59).contains(parsed.seconds) && parsed.minutes * 60 + parsed.seconds <= periodLengthSeconds
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("MM", text: $minutes)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Minutes remaining")
                        Text(":")
                        TextField("SS", text: $seconds)
                            .keyboardType(.numberPad)
                            .accessibilityLabel("Seconds remaining")
                    }
                    .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                } header: {
                    Text("Set Remaining Time")
                } footer: {
                    if !isValid {
                        Text("Enter seconds from 0–59 and no more than \(formatClock(periodLengthSeconds)) in total.")
                            .foregroundStyle(.red)
                    }
                }
            }
            .numberPadDismissal()
            .navigationTitle("Set Clock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if let parsed {
                            onApply(parsed.minutes, parsed.seconds)
                        }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

// MARK: - Banners & sections

struct MatchNoticeBanner: View {
    let systemImage: String
    // LocalizedStringResource so interpolated messages land in the String Catalog
    // as single translatable entries rather than concatenated fragments.
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

struct LineupBanner: View {
    let starterCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text("Set Starting Lineup")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Tap to select your \(starterCount) starters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding()
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// Banner shown when the available pool can't fill a bench.
struct NoSubstitutesBanner: View {
    let availableCount: Int
    let requiredCount: Int

    var body: some View {
        MatchNoticeBanner(
            systemImage: "person.2.slash.fill",
            title: availableCount < requiredCount ? "Playing Short-Handed" : "No Substitutes Available",
            message: availableCount < requiredCount
                ? "Only \(availableCount) of \(requiredCount) players available — no bench to substitute from."
                : "Exactly \(requiredCount) players available — no bench to substitute from."
        )
    }
}

struct CoachingNotesSection: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coaching Notes")
                .font(.headline)
            TextEditor(text: $text)
                .frame(minHeight: 100)
                .padding(4)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Coaching notes")
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(isDisabled ? 0.05 : 0.1), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(isDisabled ? color.opacity(0.4) : color)
        }
        .disabled(isDisabled)
    }
}

// MARK: - List rows

/// Row-sized button for lists and forms. On recent iOS releases the default list
/// button style tints the whole label with the accent colour, overriding the
/// row's own `.primary`/`.secondary` text styles so names look like links. This
/// keeps the label's own styling, makes the full row tappable, and dims on press.
struct ListRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

extension ButtonStyle where Self == ListRowButtonStyle {
    static var listRow: ListRowButtonStyle { ListRowButtonStyle() }
}

// MARK: - Keyboard

extension View {
    /// Number pads have no return key, so add a keyboard "Done" button and let
    /// scrolling dismiss the keyboard — otherwise it can cover the tab bar with no
    /// way to close it.
    func numberPadDismissal() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
    }
}

// MARK: - Game Day Mode

extension View {
    /// Keeps the screen awake while a live match is in Game Day Mode, and restores
    /// normal auto-lock when the screen goes away or the match ends.
    func keepsScreenAwake(_ isActive: Bool) -> some View {
        self
            .onAppear { UIApplication.shared.isIdleTimerDisabled = isActive }
            .onChange(of: isActive) { _, active in UIApplication.shared.isIdleTimerDisabled = active }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
