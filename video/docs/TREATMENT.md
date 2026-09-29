# The Walk — treatment and style bible (director's cut v2, under discussion)

## The idea in one paragraph

The trailer is **one session, from the tap to the walk back**. A phone touches a brick; the apps go
dark; the brick stays where it is and the phone leaves it behind. From above, the flat is a hairline
floor plan, and the only thing that changes in it is the distance between two small shapes. The dial
counts; while it does, the drawing opens its front door onto the world outside, in fast cuts. Then the
gate comes round, and the kick drum turns into footsteps: the way out is walking back.
Everything else the app does fits in the last thirteen seconds, because the idea is the whole product.

## Tone

- **An instrument panel, not an ad.** The app's own words, the app's own palette, no adjectives. A
  refusal is shown as a fact ("Not yet." and the time left), never as a lesson.
- **Stillness is part of the rhythm.** The walk is slow; the tap is instant. That asymmetry is the edit:
  the tap is one frame, the walk back is eight bars.
- **Nothing that makes the phone matter more.** No streaks, no scores, no "you did it", no confetti on
  the unlock. The shield lifting is the end of an errand, not a reward.
- **Honest.** Every number on screen is true of the app: 15-minute floor, 10-second emergency hold,
  three a rolling week, 72 ticks. Staging is invented; facts are not. The shield is drawn, because it
  cannot be screenshotted, and drawn the way it actually looks.
- **Not slop.** No neon, no glowing brains, no particle nebulae, no lens flares, no stock people or
  footage, no third-party app icons. The outside world in Act 3 is drawn in the same hairline pen as the
  floor plan, never photographed.

## Palette (`src/lib/theme.ts`, mirrors `Brick/Support/Theme.swift`)

- **ink** `#0B0B0D` / **inkRaised** `#141416`: the field while a session runs.
- **paper** `#EDE7DC` / **paperEdge** `#DCD4C6`: the floor plan, the hero surface, reverse mode.
- **chalk** `#F2F2F0` text on ink, **ash** `#9C9CA1` secondary, **graphite** `#3A3A3E` recessed ticks
  and hairlines; **inkOnPaper** `#17171A`, **ashOnPaper** `#6B675F`, **chalkline** `#C7BEAE` on paper.
- **oxide** `#B4614F`: exactly once, the emergency hold ring in Act 3. Nowhere else, including the card.
- Ink plates and paper plates alternate: on the phone is ink, in the room is paper.

## Type

- **SF Pro** (system-ui in headless Chrome on macOS) — the font the app ships in. Light weights at
  display sizes, -0.02 em tracking.
- **Engraved labels**: 500 weight, uppercase, wide tracking (the app's `engraved()`).
- **Readouts**: ultralight, tabular numerals (the app's `readout()`): countdowns, distance in metres.
- One message per frame, ≥ 84 px at 1080p for lines meant to be read.

## Motifs

- **The dial**: 72 ticks, elapsed lit, one long tick at the gate. The film's clock in Act 3; ticks
  advance on beats.
- **The ring**: the engraved ring on the brick's face is where the NFC ripple starts.
- **The distance**: mono metres between phone and brick, growing in Act 2, counting down in Act 4.
- **The dotted path**: the phone's route on the plan; drawn out in Act 2, redrawn back in Act 4.
- **The hero brick**: the real tag STL in black PLA, raking light on paper. Black on paper is also the
  app's own contrast.

## Music

Suno, **instrumental only**, minimal deep house at 112 BPM (walking cadence). No voice anywhere: every
line is on-screen type, so the words stay the app's words and the music never argues with them. A felt-
piano motif carries the memory the vocal hook would have. Pack in `docs/SUNO.md`. Cuts on downbeats, taps
on the one, footsteps = kick in Act 4. All times come from `data/audio.json` once the song exists; until
then `src/lib/timeline.ts` runs a synthetic grid. With no vocal, the analysis is beats, sections, drum
onsets and envelopes only: no word alignment.

## The song and the cut

`song/piano-motif.mp3` (Suno, 3:29, 111 BPM tracked, snare on 2 and 4, 4-bar phrases with the bass out
on the 4th bar). `analysis/edit.py` cuts it to **90.42 s, 42 bars**, splicing only on phrase downbeats:

| Trailer | Song bars | What the music does | Act |
|---|---|---|---|
| 0:00–0:26 | 0–12 | piano motif alone for 8 bars; the kick enters on bar 8 (0:17.4) | reflex, tap, leave |
| 0:26–0:34.7 | 20–24 | end of the first groove; bar 23 is a one-bar drum stop (0:32.5) | leave: "Not yet." on the stop |
| 0:34.7–0:52 | 64–72 | build: drums, no bass, thinning in the last 3 bars | time: dial + the world outside |
| 0:52–1:09.4 | 72–80 | the drop, bass back at full | walk back; the gate passes on the drop |
| 1:09.4–1:18 | 80–84 | drop continued | montage |
| 1:18–1:30.4 | 91–end | hard cut to the piano motif alone, decay to silence | card |

## Plate-by-plate (42 bars, 1:30.4)

| # | Bars · time | Act | Picture | Sound | Type |
|---|---|---|---|---|---|
| 0 | 0–4 · 0:00–0:08.8 | Reflex | Ink. Only the phone reacts, no hand: it lights, the grid blooms, it dims — three times, each faster, as if by itself. | Clock tick, pad, piano motif alone | "Willpower loses at three seconds." |
| 1 | 4–10 · 0:08.8–0:21.7 (tap 0:17.4) | The tap | Hero brick on paper, raking light. The phone descends; the NFC ring ripples from the engraved ring. Downbeat: grid goes to ink, the ticks sweep in. | Glass ping on the tap; the kick enters on the next one | "Instant to enter." |
| 2 | 10–16 · 0:21.7–0:34.7 (stop 0:32.5) | Leave it | Crane up: the brick becomes a square in the floor plan (desk, hall, kitchen). The phone travels away on a dotted path; distance grows. A thumb tries an app: the shield, "Not yet. 52 min". | Groove. The refusal is a stop: the beat drops out for one bar | "Expensive to leave." then "Not yet." |
| 3 | 16–24 · 0:34.7–0:52 | Time | The dial is the clock: ticks advance per beat. The plan's front door opens and the drawing pulls out into the world, fast cuts one per beat, all in the same hairline pen: grass hatched and moving in wind, a pitch with a ball's arc, a running track, a bike wheel turning, a table set for two, two dots on a street converging. Cuts back to the dial between runs. Emergency: the oxide ring fills over 10 s. The gate approaches. | Build; hats thicken as the cuts speed up | "Until 20:55, the brick does nothing." / "Emergency: hold for ten seconds. Three a week." |
| 4 | 24–32 · 0:52–1:09.4 | Walk back | Gate passes = drop. Kick as footsteps; the path redraws back, distance counts down; tap; shield lifts, grid returns. | Drop: full kit, kick as footsteps | "The only way out is the walk back." |
| 5 | 32–42 · 1:09.4–1:30.4 (card 1:18) | Everything else + card | Beat-cut plates: desk slab = Deep work, bedside sticker = Sleep · route 1→2→3 · reverse (paper field, "open until 21:40") · "Nothing leaves your phone." / "Print it yourself." + tag exploded. Then: brick, **buriko**, "A session you walk away from.", App Store badge once live. | Outro: piano motif returns alone, ring-out | wordmark, subtitle |

## Built so far

- **Act 0** (`src/scenes/Act0Reflex.tsx`): the phone, front-on and centred, wakes three times on the
  intro's beats (notification + buzz, grid blooms, dark; faster each time). It slides left when the line
  arrives on beat 8. Icons are abstract grey tiles.
- **Act 1** (`src/scenes/Act1Tap.tsx`):
  - Bars 4–7: the real tag STL in black PLA on paper, with a slow camera orbit and the spec line
    "42 × 42 × 10.8 mm · PLA · NTAG215 inside".
  - Bar 7: the phone glides in from the right and hovers, antenna end over the tag.
  - The last half beat: it drops 20 mm and touches on the first kick (0:17.4). Three rings leave the
    tag and the camera dips.
  - Two beats later: a cut to the app's own running screen (idle → Bricked, the dial sweeping in),
    counting down from 1:30:00 with the gate at 15 minutes. "Instant to enter." comes on bar 9.
- **Act 2** (`src/scenes/Act2Leave.tsx`, `src/components/FloorPlan.tsx`, `src/components/Shield.tsx`):
  - Bar 10: the camera starts on the brick in the plan and pulls out to the whole flat (study,
    bedroom, bath, hall, kitchen/living) as the walls draw in.
  - Bars 11–13: the phone walks a step per beat from the desk to the sofa. "Expensive to leave." comes
    in with the walked distance in metres (8.9 m at the end).
  - Bar 14: the phone front-on; the Act 0 reflex opens an app and the shield comes up, drawn the way
    `BrickShieldExtension` configures it: "1h 16m left" / "desk slab, on your desk." / OK.
  - Bar 15, the drum stop: "Not yet."
  - The OK button's real default colour is unverified, so it is drawn neutral. Check it against the
    device.
- **Act 3** (`src/scenes/Act3Time.tsx`):
  - Bar 16: the app with the clock running fast (20:24 → 20:27), under "Until 20:55, the brick does
    nothing."
  - Bars 17–20: the world cuts speed up: two beats a cut, then one, a two-beat return to the dial, then
    half a beat. Each vignette's clock advances (20:27 → 20:40).
  - Bars 21–23: back on the dial, one tick lighting per beat (75 s a tick) so the gate is reached on
    the downbeat of bar 24. The oxide pill appears; a hold starts on 21:2, fills about a third ("Keep
    holding", sped up), and is released on 22:2. The line is "Emergency: hold for ten seconds. Three a
    week." Bar 23 has the dial alone.
  - A full hold ends the session in the app, so the film shows one started and let go, not one
    completed.
- **Act 4** (`src/scenes/Act4WalkBack.tsx`):
  - Bar 24, the drop: the gate tick flares, and "Locked" becomes the live ink pill "Tap your brick to
    end".
  - Bars 25–28: the same plan and path walked back, a step on every kick (14), the distance counting
    down to 0.0 m beside the brick. The line is "The only way out is the walk back."
  - Bars 29–30: the Act 1 tap again (the same `Table`, camera held at the contact framing), touching on
    bar 30.
  - Bars 30–32: the app returns to Ready, "Last 48m · ended at the brick", then "Ended at the brick.".
- **Act 5** (`src/scenes/Act5Card.tsx`):
  - Bar 32: "One setup per brick.", with two tag faces: desk slab → Deep work · 90 min, bedside
    sticker → Sleep · reverse.
  - Bar 33: "Or a route: tap them in order.", the plan with bricks 1→2→3 (desk slab, kitchen shelf,
    bedside sticker) joined through the doorways.
  - Bar 34: "Or blocked by default. A tap buys 15 minutes.", the reverse screen from 04-reverse.png,
    Standing → Open, 0:15:00, "open until 22:54".
  - Bar 35: "No account." / "No analytics." / "Nothing leaves your phone.", a line a beat.
  - Bars 36–38, after the hard cut to piano: the tag turning slowly, "Print it yourself." with
    "42 mm · PLA · one NTAG215 sticker / files and source, public domain".
  - Bars 38–42: the card. BURIKO in the tag's own lettering (`src/lib/wordmark.ts`, from
    `hardware/buriko-tag.scad`), "A session you walk away from.", and Apple's official black badge
    (`public/badge-black.svg`, unmodified, from toolbox.marketingtools.apple.com). The last 0.6 s
    fades to paper.
- **The session the film follows**: Deep work, 20:10 → 21:40, a 45-minute minimum (gate at 20:55,
  tick 36 of 72, on the drop). It was 15 minutes in v1, which would have opened the gate before the
  shield scene.
- **The running screen omits the oxide "Hold to unlock" pill** until Act 3, so the film's one colour
  arrives with the emergency hold. That is a simplification of the real screen, not a feature of it.
- **Act 3 vignettes** (`src/components/World.tsx`, look-dev in the `LookWorld` composition): grass in
  wind, a five-a-side pass, a runner on lane three, a bike wheel, dinner for two, two people meeting at a
  corner. Each has a mono legend and a clock time that advances with the session.

## Settled (round 4)

- Hero tag: black PLA.
- Act 0: only the phone reacts; no hand in the whole trailer.
- Act 3: the outside world in fast cuts, drawn, not filmed.
- Face ID line: dropped.
- Song: instrumental only.

## Open questions

- Act 3 vignette list: grass, pitch, track, bike, table for two, street: add or cut any?
