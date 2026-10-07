import Foundation

/// How a match's regulation time is split. Persisted as its raw value in
/// `Game.periodFormat` / `Fixture.periodFormat`, so raw values must never change.
nonisolated enum PeriodFormat: String, CaseIterable, Identifiable {
    case quarters
    case halves

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quarters: return "Quarters"
        case .halves: return "Halves"
        }
    }

    var regulationPeriods: Int {
        switch self {
        case .quarters: return 4
        case .halves: return 2
        }
    }
}

/// A sport-agnostic view of the substitution log, so the playing-time algorithm
/// is written once rather than duplicated across `Game` and `Fixture`.
nonisolated struct PlayingTimeEvent {
    enum Kind {
        case subIn
        case subOut
        case matchEnd
        case other
    }

    let kind: Kind
    let playerID: UUID?
    let periodNumber: Int
    let elapsedSeconds: Int
    let timestamp: Date
}

/// Clock, period, scoring and playing-time behaviour for timed matches (`Fixture`).
/// Kept as a protocol so the logic and the shared match UI don't depend on a
/// particular model, and can be unit tested in isolation.
nonisolated protocol TimedMatch: AnyObject {
    var date: Date { get set }
    var opponentName: String { get set }
    var notes: String { get set }
    var periodFormat: String { get set }
    var periodLengthMinutes: Int { get set }
    var currentPeriod: Int { get set }
    var teamScore: Int { get set }
    var opponentScore: Int { get set }
    var isEnded: Bool { get set }
    var isGameDayModeActive: Bool { get set }
    var elapsedSeconds: Int { get set }
    var clockIsRunning: Bool { get set }
    var clockStartedAt: Date? { get set }
    var startingLineupIDs: [String] { get set }

    /// The model's event log, projected into the shape `minutesPlayedSeconds()` needs.
    var playingTimeEvents: [PlayingTimeEvent] { get }
}

nonisolated extension TimedMatch {
    var periodFormatValue: PeriodFormat {
        PeriodFormat(rawValue: periodFormat) ?? .quarters
    }

    /// Regulation periods. Overtime periods beyond this are allowed.
    var totalPeriods: Int { periodFormatValue.regulationPeriods }

    var periodLengthSeconds: Int { periodLengthMinutes * 60 }

    var isInOvertime: Bool { currentPeriod > totalPeriods }

    // MARK: - Period labels

    var periodLabel: String { periodLabel(forPeriod: currentPeriod) }

    func periodLabel(forPeriod period: Int) -> String {
        let regulation = totalPeriods
        if period > regulation {
            return "OT \(period - regulation)"
        }
        switch periodFormatValue {
        case .quarters:
            switch period {
            case 1: return "1st Quarter"
            case 2: return "2nd Quarter"
            case 3: return "3rd Quarter"
            default: return "4th Quarter"
            }
        case .halves:
            return period == 1 ? "1st Half" : "2nd Half"
        }
    }

    /// Compact label for event rows: "Q3", "H2", "OT1".
    func shortPeriodLabel(forPeriod period: Int) -> String {
        if period > totalPeriods {
            return "OT\(period - totalPeriods)"
        }
        switch periodFormatValue {
        case .quarters: return "Q\(period)"
        case .halves: return "H\(period)"
        }
    }

    // MARK: - Clock

    /// Elapsed seconds in the current period, capped at the period length so a clock
    /// left running into a break never credits extra playing time.
    func currentElapsedSeconds(now: Date = Date()) -> Int {
        var elapsed = elapsedSeconds
        if clockIsRunning, let startedAt = clockStartedAt {
            elapsed += Int(now.timeIntervalSince(startedAt))
        }
        return min(max(0, elapsed), periodLengthSeconds)
    }

    func remainingSeconds(at elapsed: Int) -> Int {
        max(0, periodLengthSeconds - elapsed)
    }

    /// True once a running clock has reached the end of the period.
    func clockHasExpired(now: Date = Date()) -> Bool {
        currentElapsedSeconds(now: now) >= periodLengthSeconds
    }

    func startClock(now: Date = Date()) {
        guard !clockIsRunning, !isEnded, !clockHasExpired(now: now) else { return }
        clockIsRunning = true
        clockStartedAt = now
    }

    func stopClock(now: Date = Date()) {
        guard clockIsRunning else { return }
        elapsedSeconds = currentElapsedSeconds(now: now)
        clockIsRunning = false
        clockStartedAt = nil
    }

    func toggleClock(now: Date = Date()) {
        if clockIsRunning {
            stopClock(now: now)
        } else {
            startClock(now: now)
        }
    }

    func resetClock() {
        elapsedSeconds = 0
        clockIsRunning = false
        clockStartedAt = nil
    }

    /// Validates a manually entered remaining time. Seconds must be 0–59 and the
    /// total can't exceed the period length.
    func isValidRemainingTime(minutes: Int, seconds: Int) -> Bool {
        minutes >= 0 && (0...59).contains(seconds) && minutes * 60 + seconds <= periodLengthSeconds
    }

    /// Sets the clock from a "time remaining" value, clamped to the period. Stops the clock.
    func setRemainingTime(minutes: Int, seconds: Int) {
        let clampedSeconds = min(max(0, seconds), 59)
        let remaining = min(max(0, minutes * 60 + clampedSeconds), periodLengthSeconds)
        elapsedSeconds = periodLengthSeconds - remaining
        clockIsRunning = false
        clockStartedAt = nil
    }

    /// Moves to the next period (including overtime). Callers log the event.
    func moveToNextPeriod() {
        stopClock()
        currentPeriod += 1
        elapsedSeconds = 0
    }

    /// Ends the match. Callers log the event.
    func markEnded() {
        stopClock()
        isEnded = true
        isGameDayModeActive = false
    }

    // MARK: - Score

    /// Applies a signed score change, never dropping below zero. Returns the delta
    /// actually applied — 0 means nothing changed and no event should be logged.
    @discardableResult
    func applyScore(team: Bool, delta: Int) -> Int {
        let previous = team ? teamScore : opponentScore
        let updated = max(0, previous + delta)
        if team {
            teamScore = updated
        } else {
            opponentScore = updated
        }
        return updated - previous
    }

    // MARK: - Playing time

    /// Total seconds each player has spent on court/field, reconstructed from the
    /// substitution event log rather than tracked live — so it stays correct even if
    /// events are edited or deleted after the fact.
    ///
    /// Cumulative "match seconds" are derived from each event's period and elapsed
    /// time, assuming a fixed period length (overtime periods use the same length).
    func minutesPlayedSeconds(now: Date = Date()) -> [UUID: Int] {
        var totals: [UUID: Int] = [:]
        var intervalStart: [UUID: Int] = [:]
        let periodLength = periodLengthSeconds

        func matchSeconds(period: Int, elapsed: Int) -> Int {
            max(0, period - 1) * periodLength + min(max(0, elapsed), periodLength)
        }

        for idString in startingLineupIDs {
            if let id = UUID(uuidString: idString) {
                intervalStart[id] = 0
            }
        }

        for event in playingTimeEvents.sorted(by: { $0.timestamp < $1.timestamp }) {
            let g = matchSeconds(period: event.periodNumber, elapsed: event.elapsedSeconds)
            switch event.kind {
            case .subIn:
                guard let playerID = event.playerID else { continue }
                intervalStart[playerID] = g
            case .subOut:
                guard let playerID = event.playerID, let start = intervalStart.removeValue(forKey: playerID) else { continue }
                totals[playerID, default: 0] += max(0, g - start)
            case .matchEnd:
                for (playerID, start) in intervalStart {
                    totals[playerID, default: 0] += max(0, g - start)
                }
                intervalStart.removeAll()
            case .other:
                break
            }
        }

        if !isEnded {
            let live = matchSeconds(period: currentPeriod, elapsed: currentElapsedSeconds(now: now))
            for (playerID, start) in intervalStart {
                totals[playerID, default: 0] += max(0, live - start)
            }
        }

        return totals
    }
}

/// "MM:SS" for clock and playing-time displays.
nonisolated func formatClock(_ seconds: Int) -> String {
    let safe = max(0, seconds)
    return String(format: "%02d:%02d", safe / 60, safe % 60)
}
