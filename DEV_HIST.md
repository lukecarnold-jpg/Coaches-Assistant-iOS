# Development History

This document summarizes the visible development history of **Basketball-Rotation-iOS** based on the repository state and commit trail available in the project.

## Project overview

Basketball-Rotation-iOS is an iPhone and iPad Swift app that mirrors the core Basketball Rotation experience with a local-first workflow for roster management, game tracking, training support, and export features. The app stores data on-device and does not require an account or server.

## Development timeline

### Initial app foundation
The earliest visible work established the overall app shell and domain model for basketball roster and game tracking.

Key foundation areas included:
- SwiftUI app structure
- local data persistence
- core models for players, games, and events
- basic navigation between the main app sections

### Game tracking workflow
A large portion of the app’s evolution focused on building a complete game-day workflow. This includes:
- creating and selecting games
- configuring period format and period length
- starting lineup selection
- substitutions and on-court management
- live clock tracking with manual adjustment support
- scorekeeping for both teams
- foul and MVP vote logging
- attendance handling
- event history review and editing
- end-game flow and period progression

### Roster management
Roster functionality was expanded to support team administration without external services.

Implemented roster features include:
- add, edit, and remove players
- optional jersey numbers
- CSV import and export

### Training features
The app also gained a training area for future coaching support.

Visible training work includes:
- Gemini API key-based drill generation by age group
- placeholder entries for upcoming training modules

### Device adaptation
The interface was adapted for both iPhone and iPad form factors.

Notable layout behavior:
- bottom tab navigation on iPhone
- split-view sidebar navigation on iPad

### Export and local data handling
The app added several export and persistence paths to keep data useful while remaining offline-first.

These include:
- roster CSV export
- game events CSV export
- coaching notes TXT export
- local app support storage for all persistent data

### Refinement and polish
The current codebase shows follow-up work around usability and data safety, including:
- toast notifications
- event editing and deletion
- clear-all-local-data settings action
- safer app container initialization with recovery from store corruption

## Current architecture snapshot

The present app structure is centered around:
- `AppStore` for in-memory state and local persistence
- `ContentView` for top-level tab/split navigation
- SwiftData models for persistent basketball entities
- dedicated game screens for setup, details, attendance, event history, and substitutions

## Notes on repository history

The repository appears to be in an active but compact development phase with a relatively small visible commit trail. The current state suggests iterative product development focused on completing a usable coach-facing iOS experience rather than broad architectural churn.

## Summary

Basketball-Rotation-iOS developed from a foundational SwiftUI basketball tracker into a feature-complete local-first app covering:
- roster management
- game setup and live scoring
- substitutions and clock handling
- attendance and event history
- exports and training support
- adaptive iPhone/iPad layouts

This history reflects steady expansion of core coaching workflows, with emphasis on offline usability and practical game-day tools.
