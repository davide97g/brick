# CLAUDE.md

Working notes for Claude Code in this repo. Read before changing anything.

## What this is

An iOS app paired with one 3D-printed NFC brick. Tapping the brick starts a session that applies real Screen Time restrictions; the brick is then left behind, so the only early way out is walking back to it — and only after a minimum duration. See `README.md` for the product reasoning.

## Hard constraints

These are confirmed by experiment, not assumed. Don't re-litigate them.

- **Family Controls and NFC Tag Reading cannot be signed by a free personal Apple team.** A paid membership is required for any device build. `spikes/SpikeAShield/` is the probe that proved it.
- **The Screen Time APIs do not work in the Simulator.** Family Controls authorization always fails there. That's why every Apple-framework dependency sits behind a port with a Simulator stand-in.
- **`DeviceActivitySchedule` refuses intervals shorter than 15 minutes.** `TimeInterval.brickMinimumSession` encodes this; the UI must never offer less.
- **A shield cannot open the host app.** `ShieldActionResponse` is `.close` / `.defer` / `.none` only. Any design that needs "tap the shield to unlock" is dead on arrival.
- **Deleting the app clears all restrictions.** Unfixable from inside. It's stated in onboarding; don't pretend otherwise anywhere else.
- **`ApplicationToken`s are opaque.** The app cannot see which apps the user picked, and nothing should be written that assumes it can.

## Commands

```sh
xcodegen generate                                    # after ANY project.yml change
swift test --package-path BrickKit                   # the rules
xcodebuild -project Brick.xcodeproj -scheme Brick \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

To exercise the app in the Simulator, seed the state file directly — it's faster and more precise than tapping through:

```sh
D=$(xcrun simctl list devices booted | grep -o '[0-9A-F-]\{36\}' | head -1)
GROUP=$(xcrun simctl get_app_container $D com.davideghiotto.brick groups | awk '{print $2}')
# edit $GROUP/brick-state.json, then relaunch
xcrun simctl spawn $D defaults write com.davideghiotto.brick pretend.authorized -bool true
```

## Architecture rules

1. **Rules go in `SessionEngine`.** It is pure: static functions over `BrickState` and a `Date`, no I/O, no clock, no Apple frameworks. If a behaviour can be expressed there, it belongs there and gets a test.
2. **`BrickKit` imports Foundation and Observation. Nothing else.** No FamilyControls, no ManagedSettings, no CoreNFC, no SwiftUI. This is what keeps the rules testable on a Mac in ~20ms.
3. **`BrickController` orchestrates; it owns no rules.** It calls `SessionEngine`, then applies the result through ports.
4. **New Apple-framework dependency ⇒ new port.** Protocol + test double in `BrickKit/Sources/BrickKit/Ports/`, real adapter in `Brick/Adapters/`, wired in `AppEnvironment`.
5. **`AppEnvironment.swift` is the only file that knows real from pretend.** Never `#if targetEnvironment(simulator)` anywhere else.
6. **Extensions cannot import the app target.** Anything they share with the app goes in `BrickKit` — names in particular, via `BrickIdentifiers`. Never hardcode `"brick.session"` or the app group string.
7. **The shield must never outlive its planned end.** Three independent paths guarantee this: `BrickMonitor.intervalDidEnd`, `reconcile()` on foreground, and the one-second tick while `HomeView` is visible. Don't remove one on the grounds that another covers it.
8. **Never leave a shield up without a scheduled way down.** `startSession` rolls the shield back if scheduling throws. Preserve that ordering.

## Gotchas

- **`project.yml` is the source of truth.** `Brick.xcodeproj` is generated and committed for convenience; edits made in Xcode's project editor are lost on the next `xcodegen generate`.
- **xcodegen overwrites extension `Info.plist` files.** Declare `NSExtension` under `info.properties` in `project.yml`, never by hand-writing the plist — it will be silently replaced and the extension will fail to load with no error.
- **App Group containers work in the Simulator**, so `FileStateStore.shared()` succeeds there. The Documents fallback in `AppEnvironment` is for builds without the entitlement.
- **`FamilyActivitySelection` is stored as `Data`.** `SelectionCoder` (app target) is the only encoder/decoder. `BlocklistConfig` caches the counts so the UI can describe a selection without decoding it.
- **Screen Time access can be revoked from Settings mid-session**, silently invalidating tokens. `reapplyShieldIfNeeded()` repairs it on foreground and reports failure; the UI shows a banner rather than letting the countdown lie.
- **Extension code runs out of process under tight time and memory limits.** Keep `BrickMonitor` trivial.

## Tests

swift-testing (`@Suite` / `@Test` / `#expect`), in `BrickKit/Tests/BrickKitTests/`.

- `SessionEngineTests` — the rules, including every boundary (exactly at the minimum, minimum longer than the session, the 7-day emergency window).
- `BrickControllerTests` — orchestration through a `Harness` of recording doubles. Assert on *effects*: was the shield applied, was the schedule cancelled, was the session filed with the right reason.
- Use `TestClock` and advance it. Never sleep in a test.

Anything touching the commitment rules — durations, refusals, quotas, expiry — needs a test before it's considered done.

## Writing style

**Code comments explain why, not what.** The non-obvious things here are product decisions and Apple constraints; those deserve a comment. Mechanics don't.

**User-facing copy is flat and factual.** The product's tone depends on a refusal being a fact rather than a judgement — "Not yet." and the time remaining, never encouragement, guilt, or streak language. No gamification: no points, no scores, no plants that die. The value of this app is *not caring* about your phone; anything that makes the phone matter more is working against it.

## Definition of done

- `swift test --package-path BrickKit` passes
- Simulator build succeeds
- Behaviour verified by screenshot or by inspecting the state file — not by reasoning about the code
- Claims about what works are limited to what was actually observed; anything unrun on a device is described as unverified
