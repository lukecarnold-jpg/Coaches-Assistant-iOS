# Coaches Assistant iOS

Coaches Assistant iOS mirrors the core Coaches-Assistant app experience for iPhone and iPad with local-first roster, game, and training workflows.

## Features

- Team roster management
  - Add, edit, remove players
  - Optional jersey numbers
  - CSV export and CSV import
- Game management
  - Create/select/delete games
  - Period format setup (quarters or halves) with configurable period length
  - Starting lineup selection (5 players), ordered by jersey number
  - Substitutions, including multi-player substitutions in a single action
  - Live period clock (start/stop/reset/manual time set) with remaining + elapsed display
  - Team and opponent score adjustments, with optional per-player scorer selection
  - Foul logging and MVP vote tracking
  - Attendance management (mark absent players per game)
  - Coaching notes per game with TXT export
  - Event history with edit/delete support
  - Advance period and end-game workflow
- Exports
  - Roster CSV
  - Game events CSV (includes game notes)
  - Coaching notes TXT
- Training tab
  - Age-group drill generation using a Gemini API key
  - “Coming Soon” training-module placeholders
- Settings
  - Appearance theme (system/light/dark)
  - Gemini API key management (stored locally on-device)
  - Data summary (player and game counts) and app version/storage info
  - Clear all local data
- Adaptive device support
  - iPhone uses bottom tab navigation
  - iPad uses split-view sidebar navigation

## Data storage

All app data is persisted locally on-device using SwiftData:

- players
- games
- game events
- attendance

App settings (appearance theme, Gemini API key) are stored locally via `AppStorage`. No account or server is required.

## Main screens

- **Roster**: player management + CSV import/export
- **Game**: live tracking, lineup/subs, period flow, stats, notes, event management, exports
- **Training**: age-group drill generation and upcoming-module placeholders
- **Settings**: appearance, API key, data overview, clear all local data
