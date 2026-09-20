# Development History

`Coaches-Assistant-iOS` is the iPhone and iPad Swift companion to the Coaches Assistant app. It was developed as a local-first coaching tool for managing rosters, tracking live games, and supporting day-to-day team operations without requiring a backend service.

## Project evolution

### Early foundation
The project began with the core app structure and data model for basketball workflow management.

This foundation introduced:
- SwiftUI app navigation
- local persistence
- player, game, and event models
- the basic screens needed to move between roster, game, training, and settings areas

### Roster tools
Roster management was expanded so coaches could maintain team data directly on device.

Key roster features include:
- add, edit, and remove players
- optional jersey numbers
- CSV import and export

### Game workflow
A major focus of development was making the app useful on game day.

The game workflow now supports:
- creating and selecting games
- choosing period format and period length
- setting a starting lineup
- substitutions and on-court player management
- live clock tracking with manual time control
- team and opponent scoring
- foul logging and MVP vote tracking
- attendance management
- coaching notes
- editable event history
- advancing periods and ending games

### Exports and offline storage
The app was designed to stay useful even without network access.

It includes:
- roster CSV export
- game event CSV export
- coaching notes TXT export
- on-device app support storage for all saved data

### Training support
The training area was added to support future coaching workflows.

It currently includes:
- age-group drill generation using a Gemini API key
- placeholder content for upcoming training modules

### iPhone and iPad support
The interface was adapted for both phone and tablet layouts.

- iPhone uses bottom-tab navigation
- iPad uses split-view sidebar navigation

### Polish and reliability
Later work improved usability and stability.

Notable refinements include:
- toast notifications
- event editing and deletion
- a clear-all-local-data action in Settings
- safer app startup with recovery if the local store becomes corrupted

### Settings and appearance
Settings grew into a dedicated control center for app-wide preferences.

- appearance theme picker (system/light/dark)
- Gemini API key input moved from Training into Settings
- at-a-glance player/game counts and app version/storage info

### Game-day refinements
Further game workflow polish focused on faster, more accurate live tracking.

- multi-player substitutions in a single action
- optional per-player scorer selection when adjusting the score
- starting lineup selection ordered by jersey number

### Project restructuring
The Xcode project was reorganized under a single `Coaches Assistant/` directory (replacing an earlier, duplicate `BasketballRotationiOS` layout), consolidating the app target, models, views, and test targets under one consistent structure.

## Current focus

The current codebase suggests a product-oriented app that emphasizes:
- practical coach workflows
- offline use
- quick game-day interaction
- simple local data management
- adaptive UI across iPhone and iPad

## At a glance

`Coaches-Assistant-iOS` is a local-first basketball coaching app that helps teams:
- manage players
- track live games
- record events and attendance
- export useful game data
- prepare drills and training ideas

The project has grown steadily from a basic SwiftUI tracker into a polished coaching tool with a clear focus on simplicity and reliability.
