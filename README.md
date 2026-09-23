<div align="center">

# Brick

**Physical objects that block apps on your iPhone until you go back to them.**

Swift · SwiftUI · Screen Time APIs · Core NFC · no backend, no account, no network code

</div>

---

## The idea

Blocking apps is free. Screen Time does it, Focus does it, a dozen App Store blockers do it. Nobody needs another one, because software-only blockers all fail the same way: the decision to unblock lives in the same device, the same thumb, and the same three seconds as the craving. Willpower loses at three seconds.

Brick moves the cost of unblocking out of your head and into the world.

You keep a 3D-printed brick where you work. Tapping it starts a session and applies real Screen Time restrictions. Then you leave — without the brick. Getting your apps back early means physically walking back to the object, and only after the minimum duration you set. Every session also has a planned end that clears itself, so a forgotten brick can never strand you.

Pair more than one and each becomes a station: the bedside sticker starts a different setup from the desk slab. A setup can make the way out a *walk* — desk, then hallway, then the front door, in order — or run in reverse, where the phone is blocked by default and tapping the brick buys a fixed open window that closes by itself.

Instant to enter. Expensive to leave. That asymmetry is the whole product.

## Why not the alternatives

| | Why it doesn't hold |
|---|---|
| **Screen Time passcode** | You know your own passcode. Self-binding with a secret you hold isn't binding. |
| **Focus modes** | Filters notifications. Doesn't stop you opening the app, and one tap turns it off. |
| **App blockers** | The escape hatch is always one screen away, so they escalate into guilt and paywalls. |
| **Timed lockboxes** | All-or-nothing. No per-app granularity, and your phone is also your maps and your bank. |
| **[Brick](https://getbrick.com)** | Right idea, thin execution: one global on/off, no session duration, no auto-relock, generic shield screen, and emergency unlocks capped at five that you refill *by emailing support*. |

What this does differently: sessions have real duration policy, the shield screen tells you how long is left and where your brick is, emergency unlocks are local and rate-limited rather than a support ticket, the hardware is yours to print, and the app contains no networking code at all.

## Status

Core built and tested. Membership is paid, the app builds and launches on a device, and an App
Store archive is clean — but **nothing real has been observed running yet**. The first bricks
are printed: an NFC sticker sealed inside PLA, reading through the plastic.

Both capabilities this product requires — Family Controls and NFC Tag Reading — are unavailable
to free personal Apple developer teams. That was the wall this project sat behind:

```
Personal development teams, including "Davide Ghiotto", do not support
the Family Controls (Development) capability.
```

That is now paid for. Development profiles carry both capabilities and last a year. Distribution
is a separate grant Apple makes only on request; it was approved team-wide on 2 September 2026,
so the archive exports and the build uploads. Build 1.0 (2) was then rejected by an *automated*
Family Controls check that the signed bundles contradict — `store/SUBMISSION.md` has the evidence
and `store/REVIEW-REPLY.md` the draft reply.

| Piece | State |
|---|---|
| `BrickKit` — models, session rules, persistence | 124 tests passing, runs on any platform |
| `Brick` — the SwiftUI app | Builds and runs in the Simulator; installs and launches on device |
| `BrickMonitor` — clears the shield when time is up | Compiles, embedded, never observed running |
| `BrickShield` — the blocked-app screen | Compiles, embedded, never observed running |
| Screen Time on device (authorization, shield) | Not yet exercised |
| NFC pairing and reads | Printed tags read through PLA; pairing in the app unverified on device |
| Face ID as a stand-in key | Built and tested; the prompt itself is unverified on device |
| App Store archive | Exported and uploaded; 1.0 (2) held by an automated review check |
| Store metadata, privacy policy | Drafted in `store/` |
| Stations, exit routes, reverse mode | Built and tested in `BrickKit`; screens verified in the Simulator |
| Hardware | The tag is printed and ready-to-print files are in `hardware/models/`; the cover family is sliced, never printed |

## How a session works

1. **Tap the brick.** Core NFC reads the tag's factory UID and matches it against the paired one. A foreign tag does nothing.
2. **Pick a length.** Minimum 15 minutes — `DeviceActivitySchedule` refuses anything shorter, so the UI never offers it.
3. **Shields go up.** A single named `ManagedSettingsStore` gets the encoded selection. These settings survive app termination and reboot.
4. **The end is scheduled** before the shield is trusted. If scheduling fails, the shield is rolled back rather than leaving you with no way out.
5. **Walk away.** Blocked apps show the custom shield: minutes left, and where you left your brick.
6. **It ends by itself.** `BrickMonitor` clears everything at the planned end with the app not running. Notifications for the five-minute warning and the end are queued at *start*, so they arrive even if the app is killed.
7. **Or you go back.** Tap the brick again — but only once the minimum duration has passed. Before that the app tells you the time remaining and nothing else.
8. **Or you don't.** Three emergency unlocks per rolling seven days, behind a ten-second hold. The valve has to exist; it just shouldn't be something a thumb does by reflex.

### If you have no brick yet

An NFC tag you haven't bought is a wall, so setup offers Face ID instead: it starts and ends
sessions in the same two taps. It is deliberately the weaker product and the app says so where
you choose it — the key is in your hand rather than across the room, so all that stands between
you and your apps is the minimum duration and three emergency unlocks a week. Pair a brick later
and it takes the key back.

## The interface

An instrument panel for a physical object, not a dashboard. Two zones on every screen: a
near-black machined surface carrying the state, and a warm paper card carrying the controls.
Monochrome throughout — `#0B0B0D` ink, `#EDE7DC` paper, chalk and ash and graphite between
them — with exactly one chromatic value, an oxide red, reserved for the emergency unlock.
Colour appears only where the commitment breaks.

The signature is the bezel: 72 engraved tick marks, elapsed ones lit, the rest recessed. One
tick is longer than the others — the **gate**, marking the point where the minimum duration is
satisfied and the brick becomes able to end the session. The dial shows not just how much time
is left but where the door opens, so you know before you walk back whether the walk is worth it.

## Architecture

Everything that makes the brick a commitment rather than a switch lives in [`SessionEngine.swift`](BrickKit/Sources/BrickKit/Session/SessionEngine.swift) as pure functions over state and a timestamp — no Apple frameworks, no I/O, no clock of its own. That's why the rules can be tested exhaustively in milliseconds on a Mac.

Everything Apple-framework-shaped sits behind a port:

| Port | On device | In the Simulator |
|---|---|---|
| `Shielding` | `ManagedSettingsShielding` | `PretendShielding` |
| `SessionScheduling` | `DeviceActivityScheduler` | `PretendScheduler` |
| `TagReading` | `CoreNFCTagReader` | `PretendTagReader` |
| `TagWriting` | `CoreNFCTagWriter` | `PretendTagWriter` |
| `BiometricAuthenticating` | `LocalAuthenticationBiometrics` | `PretendBiometrics` |
| `Notifying` | `UserNotificationsNotifier` | same |
| `Clock` | `SystemClock` | `TestClock` in tests |

[`AppEnvironment.swift`](Brick/Adapters/AppEnvironment.swift) is the only file that knows which is which.

**The app never learns what you blocked.** Apple hands it opaque `ApplicationToken`s, and `BrickKit` stores the encoded `FamilyActivitySelection` as bytes it never decodes. `SelectionCoder` in the app target is the single place those bytes are turned back into a selection.

### Layout

```
Brick/                    SwiftUI app
  Adapters/               the real frameworks, and their Simulator stand-ins
  Onboarding/             three honest screens, then authorization and pairing
  Home/                   idle, running session, settings
  Setups/                 a setup's rules, its walk, and the one FamilyActivityPicker
  Bricks/                 the paired stations
  Session/                start sheet, ten-second emergency hold
  Support/                theme, formatting, list chrome
BrickKit/                 the rules, testable anywhere
  Models/                 BrickTag, BlockProfile, Session, EmergencyLog
  Persistence/            BrickState + App Group-backed FileStateStore
  Ports/                  the protocols above
  Session/                SessionEngine (rules), BrickController (orchestration)
Shared/                   SelectionCoder + SelectionShield, compiled into both
BrickMonitor/             DeviceActivityMonitorExtension
BrickShield/              ShieldConfigurationExtension
hardware/                 the brick: OpenSCAD source, slice script, ready-to-print models
spikes/SpikeAShield/      the probe that proved the entitlement gate
spikes/SpikeNFC/          a bare NFC read/write lab for testing tags on device
project.yml               source of truth; Brick.xcodeproj is generated
```

## Build

```sh
xcodegen generate                                    # regenerate Brick.xcodeproj
swift test --package-path BrickKit                   # the rules, ~20ms
xcodebuild -project Brick.xcodeproj -scheme Brick \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
open Brick.xcodeproj
```

`project.yml` is the source of truth — Xcode project changes made in the IDE are lost on the next `xcodegen generate`.

## Hardware

The brick is a 42 × 42 × 10.8 mm PLA tag with BURIKO raised on the face you tap. The NFC sticker goes in at a print pause and the printer closes over it, so the finished object has no opening anywhere.

Print one from `hardware/models/`:

| File | Size | |
|---|---|---|
| [`buriko-tag`](hardware/models/buriko-tag.3mf) | 42 mm | The current tag — print this one |
| [`buriko-tag-110`](hardware/models/buriko-tag-110.3mf) | 46.2 mm | The same model at 110% |
| [`buriko_nfc_tag`](hardware/models/buriko_nfc_tag.3mf) | 42 mm | The first pass, kept for the record |

Each comes as `.stl` and as a Bambu Studio `.3mf` project for the A1 mini with the pause already placed — open it with **File → Open Project**, not Import, or the pause is dropped. Any NTAG-family sticker around 25 mm works: the app pairs on the tag's factory UID, so no sticker is special.

- **No metal near the coil.** No magnets, no metallic or carbon-fill filament — a conductive layer detunes the antenna and the phone stops seeing the tag.
- The iPhone's NFC antenna is at the **top edge of the back**, so that's the edge to tap with.

`hardware/buriko-tag.scad` is the source and `hardware/slice.sh` renders, slices and checks it at any size. `hardware/brick-cover.scad` builds three more covers — slab, puck, coaster — that have been sliced but never printed. [`hardware/README.md`](hardware/README.md) has the print steps and what each print taught.

## Privacy

Local by construction, not by promise:

- No accounts, no sync, no analytics, no crash reporting
- **No networking code at all** — `grep -r URLSession` returns nothing, and that's verifiable in a public repo
- State lives in one JSON file in an App Group container, readable only by this app and its two extensions
- The app is structurally incapable of knowing which apps you blocked

One thing no iOS app can fix, said plainly rather than buried: **deleting the app removes every restriction.** If you want that door shut, turn on Screen Time → Content & Privacy → App Deletion → Don't Allow.

## Roadmap

Next, in order:

1. Reply to App Review with the entitlement evidence, and create the App Store Connect record
   (`store/SUBMISSION.md`, `store/REVIEW-REPLY.md`)
2. Pair a printed brick and watch a shield go up and clear itself for real
3. Spike the remaining risks on device: shields surviving reboot, `DeviceActivityMonitor` firing
   when the app is dead
4. Measure read reliability through the shell across a few prints

Deliberately not planned: streaks, points, scores, or anything that makes the phone matter more. The product's value is not caring about it.

---

<div align="center">
<sub><b><a href="LICENSE">The Unlicense</a></b> — released into the public domain.<br>
This covers everything here, hardware designs included: 3D models, print profiles, tag layouts, dimensions.<br>
Copy it, sell it, print it, remix it, build a business on it. No attribution required, though it's always welcome.</sub>
</div>
