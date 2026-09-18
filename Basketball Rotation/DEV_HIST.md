# Development History & Engineering Log

This document records the architectural decisions, technical iterations, engineering challenges, and implementation milestones of the **Basketball Rotation** iOS project.

---

## Architecture Decisions & Evolution

### 1. Data Persistence & SwiftData Modeling
- **Initial Decision**: Use Apple's modern `SwiftData` framework over legacy Core Data for native Swift concurrency, `@Model` macro support, and seamless SwiftUI integration with `@Query`.
- **Schema Design**:
  - `Player`: Entity representing a team member (`playerID: UUID`, `name: String`, `jerseyNumber: Int?`, `createdAt: Date`).
  - `Game`: Aggregate root for matches containing format metadata, period counters, running clock state, lineup references, and relationships to `GameEvent` and `GameAttendance`.
  - `GameAttendance`: Per-game presence tracking with an `isAbsent` boolean flag.
  - `GameEvent`: Log of atomic in-game actions (`eventType`, `timestamp`, `playerID`, `playerName`, `detail`, `periodNumber`, `elapsedSeconds`, `scoreDelta`).
- **Engineering Challenges & Workarounds**:
  - *Array of UUIDs Persistence*: SwiftData historically encounters serialization bugs when persisting native `[UUID]` arrays. Resolved by storing lineup identifiers (`startingLineupIDs` and `onCourtPlayerIDs`) as `[String]` (UUID strings) and mapping to `UUID` during lookups.
  - *Custom Enum Persistence*: Custom `Codable` Swift enums inside `@Model` classes can fail during schema migrations across OS updates. Resolved by storing raw `String` values on `GameEvent.eventType` and providing a computed non-persisted property `eventKind: GameEventType`.
  - *Schema Incompatibility Fallback*: In `Basketball_RotationApp.swift`, implemented an automated fallback catch block that wipes corrupted/stale `.sqlite-wal` / `.sqlite-shm` files during development schema iterations, preventing unrecoverable launch crashes.

---

### 2. Event-Sourced Playing Time Calculation Engine
- **Problem Statement**: Tracking playing time via active running timers or accumulating per-second state directly into player records is brittle. App backgrounding, phone restarts, paused clocks, retroactive substitution adjustments, or deleted events easily corrupt counters.
- **Solution**: Implemented an event-sourced calculation engine in `Game.minutesPlayedSeconds()`.
  - The starting lineup initializes interval start times at global game second `0`.
  - Chronologically sorted `.substitutionIn` events open an active interval at `(period - 1) * periodLengthSeconds + elapsedSeconds`.
  - `.substitutionOut` events close active intervals and accumulate elapsed duration into the player's total.
  - `.gameEnd` events close all remaining open intervals.
  - For games still in progress, live intervals accumulate duration up to `currentElapsedSeconds()`.
- **Benefits**:
  - 100% deterministic and idempotent.
  - Allows editing, adding, or deleting substitution events after the fact while remaining mathematically consistent.
  - Covered thoroughly by unit tests in `PlayingTimeTests.swift`.

---

### 3. Wall-Clock Delta Game Clock
- **Challenge**: Standard `Timer.publish` timers in iOS drift when the main thread is busy, and stop running when the app is suspended in the background.
- **Implementation**:
  - When the clock is started, `clockStartedAt` records the exact wall clock `Date()`.
  - `currentElapsedSeconds()` calculates:
    $$\text{Elapsed} = \text{elapsedSeconds} + \text{Int}(\text{Date}().\text{timeIntervalSince}(\text{clockStartedAt}))$$
  - When paused, the calculated delta is committed into `elapsedSeconds`, and `clockStartedAt` is cleared.
  - UI updates leverage SwiftUI `TimelineView(.periodic(from: .now, by: 1.0))` to re-render without manual timer subscription boilerplate.

---

### 4. Paired Substitution Workflow & UX
- **UX Goal**: In amateur and youth basketball, coaches frequently substitute multiple players simultaneously (e.g. 2 off, 2 on) and must ensure exactly 5 players remain on court without confusion.
- **Implementation**:
  - `SubstitutionView` tracks two independent ordered collections: `outOrder: [Player]` (selected from court) and `inOrder: [Player]` (selected from bench).
  - Uses a visual `PairBadge` system with distinct colors (Blue, Green, Orange, Purple, Red) matching the $i$-th outgoing player with the $i$-th incoming player.
  - Confirms substitutions atomically, generating paired `.substitutionOut` and `.substitutionIn` events timestamped to the exact current game second.

---

### 5. Event History, Score Sync & Undo Rollback Integrity
- **Challenge**: If a coach mistakenly logs a score, foul, or substitution, simply deleting the event record from the database could leave scoreboard totals or on-court rosters in an inconsistent state.
- **Implementation in `EventHistoryView.swift`**:
  - `GameEvent` explicitly stores `scoreDelta: Int` (e.g. `+1`, `+2`, `+3`, or `-1`).
  - Deleting a `.teamScore` or `.opponentScore` event subtracts the exact stored `scoreDelta` from `game.teamScore` / `game.opponentScore`.
  - Deleting a `.substitutionIn` event automatically removes the player from `game.onCourtPlayerIDs`.
  - Deleting a `.substitutionOut` event restores the benched player back to `game.onCourtPlayerIDs`.

---

### 6. Pre-Game Attendance & Automatic Defensive Benching
- **Requirement**: Ensure coaches do not inadvertently sub absent players onto the court.
- **Implementation in `AttendanceView.swift`**:
  - Every game creates `GameAttendance` records for all roster players on initialization.
  - If a player is toggled as **Absent** while currently listed in `game.onCourtPlayerIDs`, the app immediately evicts them from the active lineup and logs an automatic `.substitutionOut` event with detail `"Marked absent"`.

---

### 7. AI Practice Drill Generator Multi-Provider Integration
- **Evolution**:
  1. *Version 1.0 (Gemini-only)*: Initial prototype using Google Generative Language API (`gemini-3.8-flash`) with API keys stored under a single service identifier.
  2. *Version 1.1 (Multi-Provider Abstraction)*:
     - Introduced `AIProvider` enum (`.gemini`, `.claude`, `.openAI`, `.custom`).
     - Created `DrillGenerating` protocol: `func generateDrills(ageGroup: String, apiKey: String) async throws -> [String]`.
     - Built `AIAPIKeyStore` with automated Keychain migration for existing users upgrading from the legacy single-provider store.
  3. *Provider Endpoints*:
     - **Google Gemini**: Direct REST calls to `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent`.
     - **Anthropic Claude**: Messages API to `https://api.anthropic.com/v1/messages` using `claude-haiku-4-5-20251001`.
     - **OpenAI ChatGPT**: Responses API to `https://api.openai.com/v1/responses` using `gpt-5.6-luna`.
     - **Custom Provider**: Universal OpenAI-compatible Chat Completions API (`{baseURL}/chat/completions`) allowing seamless connection to Ollama (`http://localhost:11434/v1`), LM Studio, OpenRouter, Groq, or self-hosted LLMs.
  4. *Parsing Pipeline (`parseDrillList`)*:
     - Robust regular expression and string scanning pipeline that strips markdown numbering, handles multi-line wrapped descriptions from models, ignores prelude text (e.g., *"Here are 5 drills for U12..."*), and caps output to 5 items.

---

### 8. Roster CSV Parsing & Export Engine
- **Decoupled Architecture**: `RosterCSV` is structured as a pure Swift module independent of SwiftUI or SwiftData, allowing full test coverage.
- **Capabilities**:
  - Delimiter and quote handling for escaped strings (e.g. `"Smith, Jr."`).
  - Tolerates variable header naming (`Name`, `Player`, `Jersey Number`, `Jersey`, `#`, `Number`).
  - Automatic column index detection.

---

### 9. Adaptive Navigation Architecture
- **Responsive Layout**: `ContentView` inspects `horizontalSizeClass`.
  - **Compact Width (iPhone)**: Renders a traditional 4-tab `TabView` with bottom navigation items (`Roster`, `Games`, `Training`, `Settings`).
  - **Regular Width (iPad / macOS Catalyst)**: Renders a `NavigationSplitView` with a persistent sidebar, supporting multitasking and split-screen layouts.

---

### 10. Comprehensive Swift Testing Migration
- Replaced legacy unit tests with Swift's native `Testing` framework (`import Testing`, `@Test`, `#expect`).
- **Test Suite Coverage**:
  - `DrillGenerationTests`: 6 test cases verifying line wrapping, numbering stripping, cap limits, and empty string handling.
  - `GameClockTests`: 5 test cases testing clamp math, quarter/half overtime label formatting, stopped vs running elapsed time calculations.
  - `PlayingTimeTests`: 3 test cases asserting complex multi-period substitution intervals, live clock accumulation, and game-end interval closures.
  - `RosterCSVTests`: 7 test cases validating column discovery, quote escaping, malformed rows, and header variations.
  - `Basketball_RotationUITests`: UI test cases verifying launch performance and UI element existence.

---

## Milestone & Changelog Summary

| Milestone | Key Implementations & Enhancements |
| :--- | :--- |
| **v1.0.0** | Core SwiftData models (`Player`, `Game`, `GameEvent`, `GameAttendance`), live scoreboard with point buttons, running game clock, starting lineup selection, basic substitution logging, roster CRUD. |
| **v1.1.0** | Event-sourced playing time calculation engine, paired substitution interface with color badges, event history timeline with swipe-to-delete and undo score/lineup rollback. |
| **v1.2.0** | Roster CSV import/export engine, game event CSV export, coaching notes text export, attendance tracking with defensive on-court eviction. |
| **v1.3.0** | Multi-provider AI drill generator (Gemini, Claude, OpenAI, and Custom OpenAI-compatible endpoints), Keychain credential store with automatic legacy migration, appearance theme switcher. |
| **v1.4.0** | Adaptive iPad `NavigationSplitView` sidebar layout, Swift Testing test suite (25 unit and UI test cases), performance optimization, and comprehensive documentation. |
