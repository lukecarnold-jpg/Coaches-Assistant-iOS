# Development History & Engineering Log

This document records the architectural decisions, technical iterations, engineering challenges, and implementation milestones of the **Coaches Assistant (iOS)** project.

---

## Architecture Decisions & Evolution

### 1. Data Persistence & SwiftData Modeling
- **Initial Decision**: Use Apple's modern `SwiftData` framework over legacy Core Data for native Swift concurrency, `@Model` macro support, and seamless SwiftUI integration with `@Query`.
- **Parallel Schema Design**:
  - **Basketball Dedicated Entities**:
    - `Player`: Team member (`playerID: UUID`, `name: String`, `jerseyNumber: Int?`, `createdAt: Date`).
    - `Game`: Match entity containing period counters, running clock state, lineup references, relationships to `GameEvent` and `GameAttendance`.
    - `GameAttendance`: Per-game presence tracking with an `isAbsent` boolean flag.
    - `GameEvent`: Log of atomic in-game actions (`eventType`, `timestamp`, `playerID`, `playerName`, `detail`, `periodNumber`, `elapsedSeconds`, `scoreDelta`).
  - **Multi-Sport Squad & Fixture Entities**:
    - `SquadPlayer`: Universal player entity (`sport: Sport`, `name: String`, `jerseyNumber: Int?`, `position: String?`, `createdAt: Date`).
    - `Fixture`: Universal match root (`sport: Sport`, `opponent: String`, `periodFormat: String`, `periodCount: Int`, `periodLengthMinutes: Int`, `teamScore: Int`, `opponentScore: Int`, `elapsedSeconds: Int`, `isFinished: Bool`, relationships to `FixtureEvent`, `FixtureAttendance`, `FixtureLineupSlot`).
    - `FixtureEvent`: Multi-sport event log (`eventType: String`, `actionCode: String?`, `playerID: UUID?`, `playerName: String?`, `scoreDelta: Int`, `detail: String?`, `periodNumber: Int`, `elapsedSeconds: Int`).
    - `FixtureAttendance`: Multi-sport presence tracking (`playerID: UUID`, `isAbsent: Bool`).
    - `FixtureLineupSlot`: Positional on-field slot assignment (`positionCode: String?`, `playerID: UUID?`, `orderIndex: Int`).
- **Engineering Challenges & Workarounds**:
  - *Array of UUIDs Persistence*: SwiftData serialization of native `[UUID]` arrays resolved by storing lineup identifiers (`startingLineupIDs` and `onCourtPlayerIDs`) as `[String]` (UUID strings) and mapping to `UUID` during lookups.
  - *Schema Incompatibility Fallback*: In `CoachesAssistantApp.swift`, implemented an automated fallback catch block that wipes corrupted/stale `.sqlite-wal` / `.sqlite-shm` files during development schema iterations, preventing unrecoverable launch crashes.

---

### 2. Multi-Sport Rules & Domain Abstraction
- **Problem Statement**: Hardcoding sport-specific rules, team sizes, and scoring mechanisms leads to massive code duplication and maintenance burden across multiple sports.
- **Solution (`Sport.swift`)**:
  - Declarative `Sport` enumeration supporting 15 team sports: **Basketball**, **Netball**, **Soccer**, **AFL**, **Rugby Union**, **Rugby League**, **Ice Hockey**, **Field Hockey**, **Team Handball**, **Water Polo**, **Lacrosse**, **Flag Football**, **Futsal**, **Volleyball**, and **Touch Football**.
  - `SportRules` struct defining on-field player count (5 to 18), period format (halves vs quarters), default/max period duration, on-field terminology ("On Court", "On Field", "On Ice", "In Pool", "On Ground"), drill prompt nouns, scoring action arrays (`ScoringAction`), discipline action arrays (`DisciplineAction`), and positional structures (`Position`).
  - `Removal` enum distinguishing discipline actions that incur no removal, temporary timed removals (e.g. 2-min green card, 10-min sin bin, 20s exclusion), and permanent send-offs/expulsions.

---

### 3. Event-Sourced Playing Time Calculation Engine
- **Problem Statement**: Tracking playing time via active running timers or accumulating per-second state directly into player records is brittle. App backgrounding, device restarts, paused clocks, retroactive substitution adjustments, or deleted events corrupt counters.
- **Solution**: Implemented an event-sourced calculation engine in `Game.minutesPlayedSeconds()` and `FixtureDetailView`:
  - Starting lineups initialize interval start times at global game second `0`.
  - Chronologically sorted `.substitutionIn` events open active intervals at `(period - 1) * periodLengthSeconds + elapsedSeconds`.
  - `.substitutionOut` events close active intervals and accumulate elapsed duration into the player's total.
  - Match-end events close all remaining open intervals.
  - For games still in progress, live intervals accumulate duration up to `currentElapsedSeconds()`.
  - **Equal-Share Targets**: Calculates each available (non-absent) player's proportional share of total on-court time, displaying real-time +/- deltas to help coaches maintain equitable participation.

---

### 4. Wall-Clock Delta Game Clock & Shift Timers
- **Challenge**: Standard `Timer.publish` timers in iOS drift when the main thread is busy and pause when the app is suspended in the background.
- **Implementation**:
  - When the clock is started, `clockStartedAt` records the exact wall clock `Date()`.
  - `currentElapsedSeconds()` calculates:
    $$\text{Elapsed} = \text{elapsedSeconds} + \text{Int}(\text{Date}().\text{timeIntervalSince}(\text{clockStartedAt}))$$
  - When paused, the calculated delta is committed into `elapsedSeconds`, and `clockStartedAt` is cleared.
  - UI updates leverage SwiftUI `TimelineView(.periodic(from: .now, by: 1.0))` to re-render without manual timer subscription boilerplate.
  - **Shift & Bench Timers**: Tracks each on-court player's shift duration since their last sub-in against the game clock, as well as bench duration since their last sub-off.

---

### 5. Multi-Player Paired Substitution Workflow & UX
- **UX Goal**: In amateur and youth team sports, coaches frequently substitute multiple players simultaneously (e.g. 3 off, 3 on) and must ensure the correct number of players remain on the field without confusion.
- **Implementation**:
  - `SubstitutionView` and `FixtureSubstitutionView` track two independent ordered collections: `outOrder: [Player]` (selected from court) and `inOrder: [Player]` (selected from bench).
  - Uses a visual `PairBadge` system with distinct colors (Blue, Green, Orange, Purple, Red) matching the $i$-th outgoing player with the $i$-th incoming player.
  - Confirms substitutions atomically, generating paired `.substitutionOut` and `.substitutionIn` events timestamped to the exact current match second.

---

### 6. Event History, Score Sync & Undo Rollback Integrity
- **Challenge**: If a coach mistakenly logs a score, card, or substitution, simply deleting the event record from the database could leave scoreboard totals or on-court rosters in an inconsistent state.
- **Implementation**:
  - `GameEvent` and `FixtureEvent` explicitly store `scoreDelta: Int` (e.g. `+1`, `+2`, `+3`, `+4`, `+5`, `+6`, or adjustments).
  - Deleting a team or opponent score event subtracts the exact stored `scoreDelta` from `teamScore` / `opponentScore`.
  - Deleting a `.substitutionIn` event automatically removes the player from the on-court roster.
  - Deleting a `.substitutionOut` event restores the benched player back to the active lineup.

---

### 7. Pre-Game Attendance & Automatic Defensive Benching
- **Requirement**: Ensure coaches do not inadvertently sub absent players onto the field.
- **Implementation**:
  - Every game creates attendance records for all roster players on initialization.
  - If a player is toggled as **Absent** while currently on court, the app immediately evicts them from the active lineup and logs an automatic substitution out event with detail `"Marked absent"`.

---

### 8. AI Practice Drill Generator Multi-Provider Integration
- **Evolution**:
  1. *Version 1.0 (Gemini-only)*: Initial prototype using Google Generative Language API (`gemini-3.8-flash`) with API keys stored under a single service identifier.
  2. *Version 1.1 (Multi-Provider Abstraction)*:
     - Introduced `AIProvider` enum (`.gemini`, `.claude`, `.openAI`, `.custom`).
     - Created `DrillGenerating` protocol: `func generateDrills(ageGroup: String, apiKey: String) async throws -> [String]` and sport-specific prompt variants.
     - Built `AIAPIKeyStore` with automated Keychain migration for existing users upgrading from legacy single-provider storage.
  3. *Provider Endpoints*:
     - **Google Gemini**: Direct REST calls to `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent`.
     - **Anthropic Claude**: Messages API to `https://api.anthropic.com/v1/messages` using `claude-haiku-4-5`.
     - **OpenAI ChatGPT**: Responses API to `https://api.openai.com/v1/responses` using `gpt-5.6-luna`.
     - **Custom Provider**: Universal OpenAI-compatible Chat Completions API (`{baseURL}/chat/completions`) allowing connection to Ollama (`http://localhost:11434/v1`), LM Studio, OpenRouter, Groq, or self-hosted LLMs.
  4. *Parsing Pipeline (`parseDrillList`)*:
     - Robust regular expression and string scanning pipeline that strips markdown numbering, handles multi-line wrapped descriptions from models, ignores prelude text (e.g., *"Here are 5 drills for U12..."*), and caps output to 5 items.

---

### 9. Selective Local-Data Deletion & Privacy Architecture
- **Data Management Engine (`DataDeletionSheet.swift`)**:
  - Allows coaches to selectively delete players, fixtures/games, or event logs for the active sport without affecting data in other sports.
  - Includes a global "Delete All Data" option with confirmation alerts to reset the entire database cleanly.
  - Cascading deletion ensures all associated events and attendance records are purged cleanly during fixture/game removal.
- **Zero-Cloud Privacy**: Complete local execution with no user tracking, analytics, or required remote accounts.

---

### 10. Native File Export with ShareLink
- **Modern ShareSheet Architecture**:
  - Converted CSV and TXT exports to use SwiftUI's native `ShareLink` and custom `Transferable` file representations.
  - Eliminates deprecated `UIActivityViewController` presentation bugs on iPad and Mac Catalyst.
  - Exports full RFC-compliant roster CSVs, game event CSVs (including coaching notes), and clean plain text coaching notes.

---

### 11. Adaptive Navigation Architecture
- **Responsive Layout**:
  - `RootView` acts as top-level coordinator switching seamlessly between the 15-sport selection grid and the active sport home.
  - `SportChrome` injects consistent top navigation with title, icon, and quick sport switcher.
  - Inspects `horizontalSizeClass` to render a compact `TabView` on iPhone and a `NavigationSplitView` persistent sidebar on iPad and macOS.

---

### 12. Comprehensive Swift Testing Suite
- Replaced legacy XCTest cases with Swift's modern native `Testing` framework (`@Test`, `#expect`, `@Suite`).
- **Test Suite Coverage (30+ Test Cases)**:
  - `SportRulesTests`: Validates rule definitions, scoring point values, period structures, and discipline actions for all 15 sports.
  - `SportSymbolTests`: Validates SF Symbol identifiers mapped across all sports.
  - `SportDrillPromptTests`: Asserts prompt construction accuracy across sports and age groups.
  - `SquadRosterCSVTests`: Verifies multi-sport CSV generation, parsing, header discovery, and position preservation.
  - `FixtureLineupSlotTests`: Validates on-field slot initialization, assignment, and occupancy constraints.
  - `FixturePlayingTimeTests`: Validates event-driven minute calculation across multi-period fixtures.
  - `DrillGenerationTests`: Verifies LLM response parsing, numbered prefix removal, line wrapping, and cap limits.
  - `GameClockTests`: Tests clock math, clamp boundaries, and period label formatting.
  - `PlayingTimeTests`: Asserts complex substitution intervals, live clock accumulation, and end-of-game interval closures.
  - `RosterCSVTests`: Validates CSV column discovery, quote escaping, and malformed row tolerance.
  - `CoachesAssistantUITests`: Verifies app launch performance and key UI element existence.

---

### 13. Game Day Mode Flag
- **Goal**: Provide a persisted signal that a match is currently live, as groundwork for eventually suppressing in-app sounds, haptics, or alerts while a coach is mid-game.
- **Implementation**:
  - Added `isGameDayModeActive: Bool` to both `Game` and `Fixture`, defaulting to `true` on creation.
  - `GameDetailView.endGame()` and `FixtureDetailView.endFixture()` clear the flag back to `false` alongside setting `isEnded`.
  - Surfaced as an indigo "Game Day Mode" capsule badge next to the period-label badge on both scoreboards while active.
- **Note**: The app has no sounds, haptics, or local/push notifications of its own yet, so this flag currently has no behavioral effect — it exists purely as a check-point for future sound/haptic features to gate on.

---

## Milestone & Changelog Summary

| Milestone | Key Implementations & Enhancements |
| :--- | :--- |
| **v1.0.0** | Core SwiftData models (`Player`, `Game`, `GameEvent`, `GameAttendance`), live scoreboard with point buttons, running game clock, starting lineup selection, basic substitution logging, roster CRUD. |
| **v1.1.0** | Event-sourced playing time calculation engine, paired substitution interface with color badges, event history timeline with swipe-to-delete and undo score/lineup rollback. |
| **v1.2.0** | Roster CSV import/export engine, game event CSV export, coaching notes text export, attendance tracking with defensive on-court eviction. |
| **v1.3.0** | Multi-provider AI drill generator (Gemini, Claude, OpenAI, and Custom OpenAI-compatible endpoints), Keychain credential store with automatic legacy migration, appearance theme switcher. |
| **v1.4.0** | Adaptive iPad `NavigationSplitView` sidebar layout, Swift Testing test suite, performance optimization, and comprehensive documentation. |
| **v2.0.0** | Multi-sport architecture (`Sport`, `SportRules`), initial multi-sport support for Netball, Soccer, AFL, Rugby Union, and Rugby League alongside Basketball with sport-specific scoring and positions. |
| **v2.1.0** | Rebranded app and project from "Basketball Rotation" to "Coaches Assistant", updated multi-sport cluster app icon and asset catalogs. |
| **v2.2.0** | Added selective local-data deletion modal in Settings for independent removal of players, games, or events per sport without affecting other sports. |
| **v2.3.0** | Expanded multi-sport support to **15 team sports** (adding Ice Hockey, Field Hockey, Team Handball, Water Polo, Lacrosse, Flag Football, Futsal, Volleyball, Touch Football) with specialized scoring, cards, sin bins, and positional pickers. |
| **v2.4.0** | Integrated native SwiftUI `ShareLink` for CSV and TXT file exports, expanded Swift Testing suite with dedicated multi-sport rule, symbol, drill prompt, and squad tests. |
| **v2.5.0** | Added `isGameDayModeActive` flag to `Game`/`Fixture` with on-scoreboard badge, auto-active for the duration of a live match and cleared on End Game/Fixture — groundwork for future in-app sound/alert suppression. |
