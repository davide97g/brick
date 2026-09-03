# Many tags, routes, households, and the reverse

The design of the current version. Everything below is built, tested in
`BrickKit` and verified by screenshot in the Simulator; nothing has been
exercised on a device.

Four changes, one foundation. The foundation is that a brick stops being *the*
brick: the app pairs a set of tags, and a tag points at a profile that says what
it blocks and for how long. Everything else — exit routes, household tags,
reverse mode — is a rule on top of that set.

## What is being added

| | What it is | Rests on |
|---|---|---|
| **Stations** | Several paired tags, each named and placed, each pointing at a profile. Tap the bedside tag, get the night profile. | the set |
| **Exit routes** | Getting out early means tapping an ordered list of tags — desk, then hallway, then front door. The walk is the price. | the set |
| **Household** | One physical tag paired independently by several phones. No sync, no account: same UID, N devices, N unrelated sessions. | the set |
| **Reverse** | A profile that is blocked by default. Tapping the tag buys a fixed open window, then the shield comes back by itself. | a new session kind |

Deliberately not in scope: policy written onto the tag's NDEF payload, swappable
hardware pucks, phone cradles, a message on the shield. They were considered and
dropped.

## The model

### Profiles

`BlocklistConfig` becomes `BlockProfile`, and the state holds several:

```swift
public struct BlockProfile: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String              // "Deep work", "Dinner", "Night"
    public var selectionData: Data?      // still opaque, still never decoded here
    public var appCount, categoryCount, webDomainCount: Int
    public var defaultDuration: TimeInterval
    public var minimumDuration: TimeInterval
    public var mode: ProfileMode         // .block (today's product) or .reverse
    public var exitRoute: [String]       // tag UIDs, in order; empty = "the tag that started it"
    public var routeWindow: TimeInterval // how long a partly-walked route stays valid
}

public enum ProfileMode: String, Codable, Sendable { case block, reverse }
```

Nothing about the selection changes: it stays `Data` that BrickKit never looks
inside, and `SelectionCoder` in the app target stays the only decoder.

### Tags

`BrickTag` gains a name and a profile it belongs to. `placeNote` stays what it
is — the line the shield reads out.

```swift
public struct BrickTag {
    public var uid: String
    public var ndefID: UUID
    public var name: String        // "desk slab"   — what the user calls it
    public var placeNote: String   // "on the desk" — where the shield says it is
    public var profileID: UUID?    // which profile a tap starts; nil = ask
    public var pairedAt: Date
}
```

A tag with `profileID == nil` prompts for a profile when tapped. That is the
honest default for a sticker stuck somewhere new.

### State

```swift
public struct BrickState {
    public var tags: [BrickTag]              // was `tag: BrickTag?`
    public var profiles: [BlockProfile]      // was `blocklist: BlocklistConfig`
    public var unlock: UnlockMethod          // unchanged
    public var activeSession: Session?       // unchanged shape, new fields
    public var armedProfileID: UUID?         // reverse mode: whose standing shield is up
    public var routeProgress: RouteProgress? // a partly-walked exit
    public var history: [Session]
    public var emergency: EmergencyLog
}
```

### Sessions

```swift
public enum SessionKind: String, Codable, Sendable {
    case block    // shield up, ends by clearing
    case permit   // shield down, ends by re-applying
}

public struct Session {
    // existing: id, startedAt, plannedEnd, endedAt, endReason
    public var kind: SessionKind
    public var profileID: UUID
    public var startedByTag: String?      // UID, for cross-key routes and the record
    public var grantedByEmergency: Bool   // a permit spent from the quota
}
```

## Migration

`BrickState.init(from:)` decodes field by field and `load()` swallows a throw and
returns empty state, so a mistake here silently unpairs every existing user. The
old keys must keep decoding:

- `tag` (single, optional) → append to `tags` as the first tag, named "Brick".
- `blocklist` → one `BlockProfile` named "Brick", `mode: .block`, empty route,
  and its `id` becomes the tag's `profileID`.
- `activeSession` decoded without `kind`/`profileID` → `.block`, pointed at the
  migrated profile.
- Everything new is `decodeIfPresent` with a default.

`StateStoreTests` gets a fixture of the *current* on-disk JSON, byte for byte,
and asserts that loading it yields one tag, one profile, and an intact session.
That test is the whole safety net; write it first.

## Rules

All of it in `SessionEngine`, pure, tested. Rule 9 holds: `validateEnd` stays the
one gate, and every new way out is an identity check that calls it.

### Starting

`validateStart(state:profile:duration:now:)` — as today, plus:

- the tag that was tapped must belong to the profile being started, or the
  profile must have been chosen explicitly in the app;
- a `.reverse` profile cannot be started as a block session, and vice versa;
- while `armedProfileID != nil`, a block session is refused. One shield at a
  time in v1 (see *Limits* below).

### Exit routes

```swift
public struct RouteProgress: Codable, Equatable, Sendable {
    public var sessionID: UUID
    public var stepsDone: Int
    public var lastTapAt: Date
}

public enum RouteOutcome: Equatable, Sendable {
    case advanced(remaining: Int, nextUID: String)
    case completed(Session)
}
```

`validateRouteTap(state:scannedUID:now:) throws -> RouteOutcome`:

1. `try validateEnd(state:now:)` first. Before the gate, a route tap is refused
   the same as any other tap — "Not yet." and the time. No partial credit for
   walking early.
2. Resolve the route: `profile.exitRoute` if non-empty, otherwise the single UID
   the session was started by (which is the plain one-tap product).
3. Stale progress — `now - lastTapAt > profile.routeWindow` — resets to step 0
   before matching. The route has to be one walk, not a week of drive-bys.
4. The scanned UID must equal the expected step. A wrong tag throws
   `wrongTag`, and progress resets to 0. Cheating by tapping the last tag first
   costs the whole route.
5. Last step → `.completed`, and the caller closes with `.tappedBrick`.

`routeWindow` defaults to 10 minutes. It is a profile setting because a house
and an office are different distances.

Cross-key is a route of length one pointing at a different tag: start at the
desk, only the kitchen tile ends it. No special case.

### Reverse

Two verbs instead of one:

- **Arm** a reverse profile: apply the shield, set `armedProfileID`, no session.
  Reboot-safe, since ManagedSettings persists. Nothing is scheduled.
- **Disarm**: only from the app, only after tapping any tag of that profile,
  and only after `minimumDuration` has passed since arming. Otherwise reverse
  mode is a toggle.
- **Permit**: tap a tag of the armed profile. Clear the shield, schedule the
  re-apply, file a `.permit` session. Ends by itself.

Rule 8 mirrored: **never lift a shield without a scheduled way back.** Order in
`grantPermit` is schedule first, clear second — the opposite of `startSession`,
for the same reason. If scheduling throws, the shield stays up and the permit
is refused.

The quota is what makes a permit cost something. `EmergencyLog` already models a
rolling window; reverse mode reuses it with `allowance` per profile and a window
of a day rather than a week. Out of permits means blocked until the window
rolls — that is the product working, not a bug, and the copy says so flatly.

`BrickMonitor.intervalDidEnd` has to branch:

```
if activeSession.kind == .permit  -> re-apply the armed profile's selection
else                              -> clear, as today
```

Which means the monitor extension needs to decode a `FamilyActivitySelection`,
and `SelectionCoder` lives in the app target that extensions cannot import
(rule 6). It does not move into BrickKit either — BrickKit imports Foundation
and Observation and nothing else (rule 2). So: a new `Shared/SelectionShield.swift`
listed under *both* the `Brick` and `BrickMonitor` targets in `project.yml`.
Keep it tiny; the monitor runs under tight limits.

Failure direction is worth stating: a missed callback in block mode strands the
user *blocked*, which is why three paths guarantee the clear. A missed callback
in reverse strands them *unblocked* — the safer failure, but `reconcile()` must
still re-arm on foreground, and the one-second tick in `HomeView` covers the
visible case.

## Interface

- **Profiles** replace the single blocklist screen: a list, each row a name, the
  selection summary, the durations, its tags, and a mode badge. Adding a profile
  is the same picker flow that exists today.
- **Tags** get a manager: pair, name, place note, assign a profile, and reorder
  the exit route by dragging. Unpair per tag; the last tag unpairing falls back
  to the biometric path exactly as today.
- **Pair an existing tag** — no NDEF write when the tag already carries an
  identity, so a second phone can pair the household tag without disturbing the
  first. This is the whole of household mode: no sync, no account, no network.
- **Routes on the shield.** The shield already reads state directly. With a
  route it says the next step: "3 taps left — the kitchen tile." Same flat tone,
  same buttonless screen.
- **Reverse looks reversed.** The palette has exactly one chromatic value and it
  is spoken for, so the signal is not a new colour: the two zones swap. Paper
  becomes the field, the near-black machined surface becomes the card, and the
  bezel fills the other way — ticks going *out* as the open window burns down.
  Same instrument, read upside down. A user glancing at the phone knows which
  world they are in before reading a word.

## Limits of v1

Say these out loud rather than discovering them:

- **One shield at a time.** One `ManagedSettingsStore`, one `DeviceActivityName`,
  so one running thing. Profiles decide *what* the one session blocks; they do
  not run concurrently. Lifting this later means a store per profile.
- **A permit cannot be partial.** Tokens are opaque, so the app cannot lift one
  app out of a selection. A permit opens the whole profile. A two-tier standing
  set is possible later with a second named store; it is not in this version.
- **15 minutes is still the floor**, permits included — `DeviceActivitySchedule`
  refuses less. A "two minute peek" is not available, and the UI must not offer
  one.
- **Deleting the app still clears everything**, in both directions.

## Order of work

1. **BrickKit foundation.** Model, migration, engine rules for stations and
   routes. Tests before UI. The app keeps compiling by reading `profiles.first`.
2. **Profiles and tags UI.** The two new screens; verify by screenshot, every
   page, not just the first.
3. **Routes.** Route editing, the shield's next-step copy, the refusal copy.
4. **Reverse.** Arm/disarm/permit in the engine, the monitor branch, the shared
   selection file in `project.yml`, the inverted theme.
5. **Household.** Pair-an-existing-tag, and the copy that explains one tag and
   two phones. Mostly documentation of something already true.
6. **Hardware.** Printed covers for the stickers, so a tag can sit anywhere and
   still look like part of the product.

## Tests

New suites, all in `BrickKit/Tests/BrickKitTests/`, all with `TestClock`:

- `StateMigrationTests` — the current JSON, verbatim, still loads. A file with
  unknown future keys still loads. An empty file yields empty state.
- `RouteTests` — the gate refuses a route tap before the minimum; a correct
  sequence completes; a wrong tag resets progress; a stale window resets
  progress; a one-step route equals today's behaviour; cross-key refuses the
  starting tag.
- `ProfileTests` — a tag starts its own profile; a tag with no profile refuses
  to start unattended; durations are per profile; the minimum floor holds.
- `ReverseTests` — arming applies; a permit schedules before it clears; a
  scheduling failure leaves the shield up and refuses the permit; the permit
  ends by re-applying; the quota refuses the next permit and says when it
  returns; disarming before the minimum is refused.
- `BrickControllerTests` — the same, through the recording doubles, asserting on
  effects: which store was applied, what was scheduled, what was filed.
