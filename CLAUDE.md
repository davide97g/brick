# CLAUDE.md

Working notes for Claude Code in this repo. Read before changing anything.

## What this is

An iOS app paired with a set of 3D-printed NFC bricks. Tapping one starts a session that applies real Screen Time restrictions; the brick is then left behind, so the only early way out is walking back to it — and only after a minimum duration. A tag points at a *setup* (`BlockProfile`), so the bedside sticker can mean something different from the desk slab, and a setup can name an *exit route*: several tags to tap, in order, before a session ends early. A setup can also run in reverse — blocked by default, tapping buys a fixed open window. See `README.md` for the product reasoning and `docs/MULTI-TAG.md` for the design.

## Hard constraints

These are confirmed by experiment, not assumed. Don't re-litigate them.

- **Family Controls and NFC Tag Reading cannot be signed by a free personal Apple team.** `spikes/SpikeAShield/` is the probe that proved it. The membership is now paid, so device builds sign; profiles carry both capabilities and last a year.
- **Family Controls for *distribution* is a separate grant.** Apple gives it per App ID on request, and `xcodebuild -exportArchive` fails without it. Development is unaffected. See `store/SUBMISSION.md`.
- **The Screen Time APIs do not work in the Simulator.** Family Controls authorization always fails there. That's why every Apple-framework dependency sits behind a port with a Simulator stand-in.
- **`DeviceActivitySchedule` refuses intervals shorter than 15 minutes.** `TimeInterval.brickMinimumSession` encodes this; the UI must never offer less.
- **A shield cannot open the host app.** `ShieldActionResponse` is `.close` / `.defer` / `.none` only. Any design that needs "tap the shield to unlock" is dead on arrival.
- **Deleting the app clears all restrictions.** Unfixable from inside. It's stated in onboarding; don't pretend otherwise anywhere else.
- **Biometrics are a weaker key, never a stronger one.** `UnlockMethod.biometric` exists so an
  app with no printed brick is usable at all. It changes *who holds the key*, nothing else: the
  minimum duration, the emergency quota and the scheduled end are identical. Never present it as
  equivalent to the brick, and never make it the default.
- **`ApplicationToken`s are opaque.** The app cannot see which apps the user picked, and nothing should be written that assumes it can. This is also why a permit cannot be partial: one app cannot be lifted out of a selection.
- **One shield at a time.** One `ManagedSettingsStore`, one `DeviceActivityName`, so one running thing. Setups decide *what* the single session blocks; they do not run concurrently, and a block session is refused while a reverse setup is standing.
- **The 15-minute floor applies in both directions.** A permit is a `DeviceActivitySchedule` too, so there is no two-minute peek to be had.

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

9. **The gate is one rule, not two.** `SessionEngine.validateEnd` owns "has the minimum passed";
   the route check adds identity on top of it. A new way out adds an *identity* check and
   calls `validateEnd` — it never re-implements the gate. An unpaired tag is refused on identity
   before the gate, because that answer is true whatever the clock says; everything about the
   *exit*, including route progress, sits behind the gate.

10. **Reverse mirrors rule 8: never lift a shield without a scheduled way back.** `grantPermit`
    files the permit and schedules its return *before* clearing, and rolls both back if
    scheduling throws. `SessionEngine.expiryAction` is the single answer to "does this ending
    clear the shield or re-apply it", and the monitor extension, `reconcile()` and the tick all
    ask it rather than deciding for themselves.

11. **`Shared/` is compiled into the app *and* `BrickMonitor`.** Reverse mode makes the extension
    apply a shield, not only clear one, so `SelectionCoder` and `SelectionShield` live there.
    It is the one place FamilyControls code is shared without going through BrickKit.

## Gotchas

- **`project.yml` is the source of truth.** `Brick.xcodeproj` is generated and committed for convenience; edits made in Xcode's project editor are lost on the next `xcodegen generate`.
- **xcodegen overwrites extension `Info.plist` files.** Declare `NSExtension` under `info.properties` in `project.yml`, never by hand-writing the plist — it will be silently replaced and the extension will fail to load with no error.
- **App Group containers work in the Simulator**, so `FileStateStore.shared()` succeeds there. The Documents fallback in `AppEnvironment` is for builds without the entitlement.
- **`FamilyActivitySelection` is stored as `Data`.** `SelectionCoder` (in `Shared/`) is the only encoder/decoder. `BlockProfile` caches the counts so the UI can describe a selection without decoding it.
- **Screen Time access can be revoked from Settings mid-session**, silently invalidating tokens. `reapplyShieldIfNeeded()` repairs it on foreground and reports failure; the UI shows a banner rather than letting the countdown lie.
- **Extension code runs out of process under tight time and memory limits.** Keep `BrickMonitor` trivial.
- **`BrickState` decodes field by field.** `load()` swallows any decode error and returns an
  empty state, so one new non-optional field would silently unpair every existing user. Add
  fields to `init(from:)` with `decodeIfPresent` and a default. `StateMigrationTests` pins the
  shipped file shape — a single `tag` and a single `blocklist` — byte for byte, including a
  session that was running when the update landed. Those legacy keys are read and never written
  back: one migration, at the first load.
- **Store submission state lives in `store/`.** `SUBMISSION.md` is the running record of what is done, blocked and unverified; `METADATA.md` holds the listing copy and review notes. Update them when any of it changes.
- **Don't put persistent chrome inside a paged `TabView`.** A `PaperCard` placed in each page slides a second copy of itself into view on every swipe, and its bottom safe-area inset doesn't resolve, so it renders cropped. Keep the card and the dots outside the `TabView`; only content pages swipe.
- **App Review has no brick, and may have no enrolled face.** `DemoTagAccess` +
  `SwitchingTagReader`/`SwitchingTagWriter`/`SwitchingBiometrics` swap in the pretend tag *and*
  the pretend prompt on device when the code in `store/METADATA.md` is entered under
  Settings → App Review. It must stay visible in the UI while on: an app that silently stopped needing the object would be lying about what it is.
- **Verify every page, not the first one.** The onboarding card bug survived a screenshot pass because only page 0 was captured. `-uiPreview` covers the screens behind a tap: `start`, `settings`, `setups`, `blocklist` (the first setup), `route`, `bricks`, `brick`, `onboard<N>`.
- **Type scales: use `brickText(_:weight:relativeTo:)`, never `.font(.system(size:))`.** A raw
  system size ignores the reader's text-size setting for ever. Chrome that must not grow past a
  point (the home header, the big readouts) clamps with `dynamicTypeSize(...)`; layouts that
  would overflow at accessibility sizes scroll (`CenteredScroll`) or restack. Verify with
  `xcrun simctl ui <device> content_size accessibility-extra-extra-extra-large`.
- **Shapes are greedy.** A bare `Capsule()` or a `GeometryReader` inside a control takes all the
  height it is offered. Size a control by its label and put the shapes in `.background`.
- **Reverse mode inverts the two zones rather than adding a colour.** `Surface.standard` / `Surface.reversed` in `Theme.swift`; the root's `preferredColorScheme` follows, or the status bar stays white on paper.

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
