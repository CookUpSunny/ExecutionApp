# Execution App — Agent operating contract

## Product
Native iOS SwiftUI app. EXECUTION — Do or Die. Designed for winning. Shorten the time between thought and execution. Preserve the red/black/white identity, accessible UI, and constructive accountability. Existing brand artwork, when available, supersedes placeholder icons.

## Operating loop
Read PLANS.md and BUILD_LOG.md before coding. Inspect git status and preserve unrelated changes. Select the highest-priority unfinished milestone with dependencies met. Implement a small vertical slice, run its relevant tests and build, inspect diff and edge cases, fix failures, record evidence, and commit only scoped work on the dedicated development branch. Repeat while the active goal and budget allow. Never manufacture test results. Do not repeat the same failing approach more than twice without a new hypothesis. If an independent milestone is possible, log the blocker and proceed; otherwise stop with a precise unblock request.

## Boundaries
Work only in this repository. Use a dedicated branch or worktree; never force push, rewrite history, merge into main, publish releases, upload to TestFlight, change billing, access credentials, or disable sandbox protections. Do not use destructive commands or install unapproved system software. Prefer native Apple frameworks and no new third-party runtime dependencies. Keep iOS 18 fallback behavior where possible; gate newer APIs with availability checks. Do not invent functionality or claim unsupported Apple capabilities. Never add persistent background timers or critical-alert entitlements as a shortcut. Notification permission is optional; respect device settings. Do not expose private commitment data in widgets without user control.

## Verification
On a Mac with Xcode and XcodeGen, run xcodegen generate, xcodebuild -list, and xcodebuild -showdestinations -scheme Execution. Pick an installed iOS simulator and run xcodebuild -scheme Execution -destination 'platform=iOS Simulator,id=<actual UUID>' CODE_SIGNING_ALLOWED=NO test. Record exact commands and results. If the environment lacks Xcode, distinguish source-only checks from actual iOS compilation; never mark the latter passed. Always run git diff --check. If possible, launch and exercise the app on a simulator, capture screenshots and log the locations. Maintain a resumable log and final handoff.
