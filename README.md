# Basketball Rotation iOS

Basketball Rotation iOS is a simple team management and live game tracking app for coaches, managers, and parents who want an easy way to manage a basketball roster during games.

The app lets you build a team roster, create games, set the starting lineup, track which players are currently on the court, record substitutions, log scoring and fouls, count MVP votes, run a game clock, and export the data to CSV files.

## What the app does

The app is designed to help you manage a single team's game activity from one place.

With the app, you can:

- add, edit, and remove players from your roster
- create and manage multiple games
- choose the starting five for a game
- track player substitutions during the game
- record player scoring with +1, +2, and +3 actions
- adjust team and opponent scores
- record and correct player fouls
- track MVP votes for players
- run, stop, reset, and manually set a game clock
- view current player stats during a game
- view a recent event log of everything that happened
- export roster data and game data as CSV files
- clear all local app data from the settings screen

## Main screens

### Roster
The **Roster** tab is where you manage your team list.

You can:
- add a player with a name and jersey number
- edit an existing player's details
- remove a player from the roster
- export the full roster as a CSV file

### Game
The **Game** tab is where live game tracking happens.

You can:
- create a new game
- select an existing game
- delete a game
- start and control the game clock
- keep score for your team and the opponent
- select the starting lineup
- substitute players in and out
- track each player's points, fouls, and MVP votes
- see which players are on the court
- see each on-court player's current shift time
- review a running list of recent game events
- export the selected game's data as CSV

### Settings
The **Settings** tab contains app-level actions.

You can:
- clear all stored players, games, and events
- manage data cleanup for the app

## CSV export

The app supports exporting two types of CSV files:

### Roster CSV
Exports the current player roster, including:
- player ID
- player name
- jersey number

### Game CSV
Exports the selected game's information, including:
- game title
- opponent
- created date
- team score
- opponent score
- event history
- player-related actions such as scoring, fouls, substitutions, and MVP votes

Exports use the native iOS file export sheet, so you can save files to the Files app, iCloud Drive, or another available location.

## Data storage

All data is stored locally on the device.

This includes:
- players
- games
- game events
- clock and score state
- player stats for each game

The app does not require an account and does not rely on a server. Data remains on the device unless you export it manually.

## Intended use

This app is useful for:
- youth basketball teams
- school teams
- club teams
- parents tracking unofficial stats
- coaches managing player rotations from the bench

## Notes

This app is focused on simple, fast game tracking rather than full league-grade statistics.

Current behavior includes:
- local-only storage
- one-device data management
- manual score and event entry
- CSV-based export for sharing or reporting

## Project summary

Basketball Rotation iOS is a lightweight SwiftUI app that helps track player rotation and game events in real time. It provides a practical way to manage a roster, follow on-court player changes, record scoring and fouls, and export game data for later review.
