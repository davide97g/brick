# Brick

A single physical NFC brick that blocks apps on iOS until you go back to it.

You leave the brick where you work. Tapping it starts a session and applies Screen Time
restrictions; then you walk away without it. Getting your apps back early means physically
returning to the object — and only after the minimum duration you set. Every session has a
planned end that clears itself, so a forgotten brick can never strand you.

Not a Brick (getbrick.com) clone: sessions have real duration policy, the shield screen tells
you where your brick is, emergency unlocks are local and rate-limited rather than gated behind
emailing support, and the app contains no networking code at all.

## Status

Core is built and tested. **Nothing real runs yet** — both required capabilities (Family
Controls and NFC Tag Reading) are unavailable to free personal Apple developer teams, so a paid
Apple Developer Program membership is required to run this on a device.

- `BrickKit` — models, session rules, persistence. 36 tests, no Apple frameworks, runs anywhere.
- `Brick` — the SwiftUI app. Builds and runs in the Simulator against pretend adapters.
- `BrickMonitor` — clears the shield at a session's planned end with the app not running.
- `BrickShield` — the blocked-app screen: time left, and where your brick is.
- `spikes/SpikeAShield` — the minimal probe that proved the entitlement gate.

Both extensions compile and are embedded correctly, but neither has been observed running:
that needs a device, which needs the membership.

## Design

The rules that make the brick a commitment rather than a switch all live in
`BrickKit/Sources/BrickKit/Session/SessionEngine.swift`, as pure functions over state and a
timestamp. Everything Apple-framework-shaped sits behind a port:

| Port | Real adapter | Simulator |
|---|---|---|
| `Shielding` | `ManagedSettingsShielding` | `PretendShielding` |
| `SessionScheduling` | `DeviceActivityScheduler` | `PretendScheduler` |
| `TagReading` | `CoreNFCTagReader` | `PretendTagReader` |
| `TagWriting` | `CoreNFCTagWriter` | `PretendTagWriter` |
| `Notifying` | `UserNotificationsNotifier` | same |

`Brick/Adapters/AppEnvironment.swift` is the only file that knows which is which.

The app never learns what you blocked: Apple hands it opaque tokens, and BrickKit stores the
encoded selection as bytes it never decodes.

## Build

```sh
xcodegen generate                 # regenerate Brick.xcodeproj from project.yml
swift test --package-path BrickKit
open Brick.xcodeproj
```

## Hardware

A 3D-printed monolith (Bambu Lab A1) with an NTAG215 embedded mid-print, ≤1.2mm of PLA above
the tag, ballast in the base for heft. Models to follow in `hardware/`.
