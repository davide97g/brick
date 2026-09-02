<div align="center">

# Brick

**A single physical object that blocks apps on your iPhone until you go back to it.**

Swift · SwiftUI · Screen Time APIs · Core NFC · no backend, no account, no network code

</div>

---

## The idea

Blocking apps is free. Screen Time does it, Focus does it, a dozen App Store blockers do it. Nobody needs another one, because software-only blockers all fail the same way: the decision to unblock lives in the same device, the same thumb, and the same three seconds as the craving. Willpower loses at three seconds.

Brick moves the cost of unblocking out of your head and into the world.

You keep one 3D-printed brick where you work. Tapping it starts a session and applies real Screen Time restrictions. Then you leave — without the brick. Getting your apps back early means physically walking back to the object, and only after the minimum duration you set. Every session also has a planned end that clears itself, so a forgotten brick can never strand you.

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
Store archive is clean — but **nothing real has been observed running yet**, and there is no NFC
tag to pair.

Both capabilities this product requires — Family Controls and NFC Tag Reading — are unavailable
to free personal Apple developer teams. That was the wall this project sat behind:

```
Personal development teams, including "Davide Ghiotto", do not support
the Family Controls (Development) capability.
```

That is now paid for. Development profiles carry both capabilities and last a year. Distribution
is a separate grant that Apple makes only on request, so uploading a build is still blocked —
`store/SUBMISSION.md` has the exact error and what it needs.

| Piece | State |
|---|---|
| `BrickKit` — models, session rules, persistence | 54 tests passing, runs on any platform |
| `Brick` — the SwiftUI app | Builds and runs in the Simulator; installs and launches on device |
| `BrickMonitor` — clears the shield when time is up | Compiles, embedded, never observed running |
| `BrickShield` — the blocked-app screen | Compiles, embedded, never observed running |
| Screen Time on device (authorization, shield) | Not yet exercised |
| NFC pairing and reads | Not started — no tag yet |
| Face ID as a stand-in key | Built and tested; the prompt itself is unverified on device |
| App Store archive | Clean; export blocked on Family Controls (Distribution) |
| Store metadata, privacy policy | Drafted in `store/` |
| Hardware | Not started |

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
  Blocklist/              the one place FamilyActivityPicker is touched
  Session/                start sheet, ten-second emergency hold
BrickKit/                 the rules, testable anywhere
  Models/                 BrickTag, BlocklistConfig, Session, EmergencyLog
  Persistence/            BrickState + App Group-backed FileStateStore
  Ports/                  the protocols above
  Session/                SessionEngine (rules), BrickController (orchestration)
BrickMonitor/             DeviceActivityMonitorExtension
BrickShield/              ShieldConfigurationExtension
spikes/SpikeAShield/      the probe that proved the entitlement gate
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

A monolith, not a puck: roughly 45×45×20mm, matte PLA, flat top face with a recessed glyph as the tap target. Weight is the point — 120–200g of ballast in the base, ferrite-isolated from the tag, because a light object doesn't feel like a commitment.

- NTAG215 embedded mid-print via a Bambu Studio pause, with **≤1.2mm** of PLA above it
- Magnets and metal kept **≥8mm** from the coil — eddy currents detune the antenna
- The iPhone's NFC antenna is at the **top edge of the back**, so the tap face needs to be big enough to aim at

Models will land in `hardware/`.

## Privacy

Local by construction, not by promise:

- No accounts, no sync, no analytics, no crash reporting
- **No networking code at all** — `grep -r URLSession` returns nothing, and that's verifiable in a public repo
- State lives in one JSON file in an App Group container, readable only by this app and its two extensions
- The app is structurally incapable of knowing which apps you blocked

One thing no iOS app can fix, said plainly rather than buried: **deleting the app removes every restriction.** If you want that door shut, turn on Screen Time → Content & Privacy → App Deletion → Don't Allow.

## Roadmap

Next, in order:

1. Request Family Controls (Distribution) for all three App IDs — the one thing standing between
   a clean archive and an upload (`store/SUBMISSION.md`)
2. Buy NTAG215 tags, pair one, and watch a shield go up and clear itself for real
3. Spike the three risks on device: shields surviving reboot, tag reads through printed PLA,
   `DeviceActivityMonitor` firing when the app is dead
4. Decide how a reviewer with no tag is meant to review this
5. Print the first brick and measure read reliability through the shell

Deliberately not planned: streaks, points, scores, or anything that makes the phone matter more. The product's value is not caring about it.

---

<div align="center">
<sub><b><a href="LICENSE">The Unlicense</a></b> — released into the public domain.<br>
This covers everything here, hardware designs included: 3D models, print profiles, tag layouts, dimensions.<br>
Copy it, sell it, print it, remix it, build a business on it. No attribution required, though it's always welcome.</sub>
</div>
