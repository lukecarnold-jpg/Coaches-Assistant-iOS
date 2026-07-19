# Basketball Rotation iOS

Basketball Rotation iOS mirrors the core Basketball-Rotation app experience for iPhone and iPad with local-first roster, game, and training workflows.

## Features

- Team roster management
  - Add, edit, remove players
  - Optional jersey numbers
  - CSV export and CSV import
- Game management
  - Create/select/delete games
  - Period format setup (quarters or halves) with configurable period length
  - Starting lineup selection (5 players)
  - Substitutions
  - Live period clock (start/stop/reset/manual time set) with remaining + elapsed display
  - Team and opponent score adjustments
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
  - Age-group drill generation via Gemini API key input
  - “Coming Soon” training-module placeholders
- Adaptive device support
  - iPhone uses bottom tab navigation
  - iPad uses split-view sidebar navigation

## Data storage

All app data is stored locally on-device in app support storage:

- players
- games
- game events
- attendance, notes, scores, timer, and period state

No account or server is required.

## Main screens

- **Roster**: player management + CSV import/export
- **Game**: live tracking, lineup/subs, period flow, stats, notes, event management, exports
- **Training**: age-group drill generation and upcoming-module placeholders
- **Settings**: clear all local data
