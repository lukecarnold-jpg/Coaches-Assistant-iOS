# CLAUDE.md

Guidance for working in this repo. The app is a native iPhone/iPad app (Swift 6, SwiftUI, SwiftData, Swift Testing) for youth and amateur coaches.

## Layout

- `Coaches Assistant/` — app sources (`Models/`, `Services/`, `Views/`, `LiveActivity/`)
- `Coaches AssistantTests/` — unit tests (Swift Testing)
- `Coaches AssistantUITests/` — UI tests (XCUITest)
- `MatchLiveActivity/` — Live Activity widget extension
- `.github/workflows/ci.yml` — CI, runs on every push and on PRs to `main`

`STRUCTURE.md` is the file-by-file map. Read it before exploring the codebase.

## Build and test

```bash
xcodebuild test \
  -project "Coaches Assistant.xcodeproj" \
  -scheme "Coaches Assistant" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

Requires full Xcode 26 or newer (`xcode-select` must point at Xcode, not the Command Line Tools). To list schemes and targets without building: `xcodebuild -list -project "Coaches Assistant.xcodeproj"`.

## Documentation must stay in sync

Three docs describe this project. Update them in the same change as the code they describe. Do not leave them for later.

- **`README.md`** — user-facing features, supported sports and rules, build and run steps. Update when a feature, sport rule, setup step, or requirement changes.
- **`STRUCTURE.md`** — directory layout, file responsibilities, runtime flows. Update when files are added, removed, renamed, or moved between folders, or when a runtime flow changes.
- **`DEV_HIST.md`** — architecture decisions and the milestone/changelog table. Add an entry for each significant decision or release-level change. Do not log routine fixes.

Before finishing a change, check each of the three against what you changed. If one needs no update, say so in the summary rather than skipping the check silently.

## Conventions

- Keep Swift 6 strict concurrency clean. Do not introduce new `@unchecked Sendable` or `nonisolated(unsafe)` without a comment explaining why.
- API keys live in the Keychain (`KeychainHelper`). Never write them to logs, files, or fixtures.
- Logic that is not view code (clock math, playing-time rotation, scoring, CSV parsing, rule tables) belongs in `Models/` or `Services/` with a unit test. The UI tests are for flows, not arithmetic.
- Match the surrounding code's comment density and naming. Comments explain why, not what.

## Git

- Do not commit to `main`. Branch first.
- Commit messages and PR descriptions end with the attribution lines the session specifies.
