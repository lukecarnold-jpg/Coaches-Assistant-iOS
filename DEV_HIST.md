# Development History

This document summarizes the visible development history of **Basketball-Rotation-iOS** based on the repository state and commit trail available in the project.

## Project overview

Basketball-Rotation-iOS is an iPhone and iPad Swift app that mirrors the core Basketball Rotation experience with a local-first workflow for roster management, game tracking, training support, and exports. The app stores data on-device and does not require an account or server.

## Development milestones

### 1) Foundation and app structure
The earliest visible work established the app shell, persistence layer, and the core domain model for basketball roster/game tracking.

This likely introduced:
- SwiftUI application entry points
- local state storage
- player, game, and event models
- basic navigation between primary app areas

### 2) Roster management
Roster functionality was built out to support team administration without relying on a backend.

Implemented roster capabilities include:
- add, edit, and remove players
- optional jersey numbers
- CSV import and export

### 3) Game-day workflow
A major development theme was a complete live game workflow for coaches.

This includes:
- create/select/delete games
- configure period format and period length
- select starting lineups
- manage substitutions and on-court players
- track the live period clock with manual adjustment support
- update team and opponent scores
- log fouls and MVP votes
- mark player attendance/absence
- maintain coaching notes
- review and edit event history
- advance periods and end games

### 4) Exports and offline data handling
The app added practical export and persistence features so coaches can keep and share information while staying offline-first.

These include:
- roster CSV export
- game events CSV export
- coaching notes TXT export
- local app-support storage for persistent data

### 5) Training support
The app later gained a training area intended to support future coaching workflows.

Visible training features include:
- Gemini API key-based drill generation by age group
- “Coming Soon” placeholders for future training modules

### 6) iPhone and iPad adaptation
The interface was adapted for both phone and tablet form factors.

Notable UI behavior:
- bottom-tab navigation on iPhone
- split-view sidebar navigation on iPad

### 7) Refinement and robustness
Later work focused on usability, polish, and resilience.

Examples of refinement include:
- toast notifications
- event editing and deletion
- settings action to clear all local data
- safer container initialization with recovery from store corruption

## Commit-style summary

Based on the visible history, the project appears to have evolved in a small number of iterative passes rather than through large branching development.

### Early commits
- Established the initial app structure
- Added the first version of core persistence and models
- Introduced the main navigation framework

### Middle commits
- Expanded roster and game operations
- Added scoring, substitutions, attendance, and event logging
- Improved export functionality and data handling

### Later commits
- Added training support and AI-assisted drill generation
- Refined iPad/iPhone layouts
- Improved stability and UI polish

## Current architecture snapshot

The current app structure is centered around:
- `AppStore` for in-memory state and local persistence
- `ContentView` for top-level tab/split navigation
- SwiftData models for persistent basketball entities
- dedicated game screens for setup, details, attendance, event history, and substitutions

## Development summary

Basketball-Rotation-iOS developed from a foundational SwiftUI basketball tracker into a feature-rich local-first coaching app covering:
- roster management
- game setup and live scoring
- substitutions and clock handling
- attendance and event history
- exports and training support
- adaptive iPhone/iPad layouts

The overall trajectory suggests steady product-focused iteration with strong emphasis on offline usability and practical game-day tooling.

## Changelog-style highlights

### Added
- roster CRUD
- game creation and live tracking
- period handling and stopwatch-style clock
- substitutions and lineup management
- attendance tracking
- event history and edits
- CSV/TXT exports
- training/drill generation support
- iPad split-view and iPhone tab layouts

### Improved
- persistence reliability
- user feedback via toast messages
- local data reset flow
- app container recovery for corrupted stores

### Designed for
- coaches
- team managers
- offline use on iPhone and iPad
