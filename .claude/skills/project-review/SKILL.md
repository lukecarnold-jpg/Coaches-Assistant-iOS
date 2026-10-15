---
name: project-review
description: Review the Coaches Assistant iOS app and produce a prioritized list (P0/P1/P2) of bugs, security and reliability issues, test gaps, and improvements. Use when asked to review the project, audit the codebase, find bugs, or give a priority list of fixes.
---

# Project review

Produce a verified, prioritized review of the Coaches Assistant iOS app. This is a read-only task.

## How to run it

Run the review in a subagent pinned to the Opus model, so the depth and cost are consistent each time. Use the Agent tool with `model: "opus"` and pass it the full brief in the "Review brief" section below, with the repo path `/Users/lukearnold/Documents/Dev/untitled folder/Coaches-Assistant-iOS`.

Run it in the foreground so its result comes back to you directly. Then relay its priority list to the user. Do not paraphrase away file paths or line numbers.

If the Agent tool is unavailable, do the review yourself with the same brief and say that it was not run on Opus.

## Review brief

The app is a Swift 6 / SwiftUI / SwiftData app (iPhone and iPad) for youth coaches. It covers rosters, the live game clock, playing-time rotations, scoring, discipline, AI practice drills (Gemini, Claude, OpenAI, and custom endpoints), Cricket scorecards, and a Live Activity.

Layout: app sources are in `Coaches Assistant/`, unit tests in `Coaches AssistantTests/`, UI tests in `Coaches AssistantUITests/`, and the widget in `MatchLiveActivity/`. `STRUCTURE.md` maps the files. Read it first.

Rules for the reviewer:
- Read the code directly. Do not modify any files.
- Do not run `xcodebuild`. Reading is enough.
- Report only what you have verified by reading the code.

Look for issues in this order of importance:
1. **Correctness:** wrong state transitions, clock and timer math, off-by-one errors in rotations and playing time, score or stat errors, undo and rollback integrity, SwiftData model problems (relationships, deletion, migration and recovery), Swift 6 concurrency and isolation problems, force unwraps or crashes on bad input, and CSV import and export edge cases.
2. **Security and privacy:** API key handling (Keychain only), secrets written to logs or files, keys placed in URLs, and unvalidated custom endpoint URLs.
3. **Reliability:** errors that are silently swallowed, Live Activities that are never ended, and timers that are never invalidated.
4. **Test gaps:** important logic with no unit test.
5. **Improvements:** dead code, duplicated logic that could drift apart, SwiftUI performance problems (such as heavy work in `body`), and accessibility gaps.

For each finding, give:
- the file path and line number,
- what goes wrong and the input or sequence that triggers it,
- a concrete fix,
- a confidence level of high, medium, or low.

Do not report style nits.

## Output format

One priority list, most important first, in three groups:
- **P0 (fix now):** real bugs, crashes, or data loss.
- **P1 (should fix):** likely bugs, security issues, and reliability problems.
- **P2 (improvements).**

Keep each item to two to four lines. End with a short "Ruled out" section listing up to five things that were checked and found fine, so coverage is visible.
