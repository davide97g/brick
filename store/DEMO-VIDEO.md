# Demo video for App Review — Guideline 2.1

App Review rejected 1.0 (2) on 5 September 2026 asking for a video that shows the physical tag
and a physical iPhone interacting. Submission ID `bd38e031-a11b-445c-9d03-bf18edbd4cb0`.
Apple's three requirements, verbatim:

- the current version of the app in use on a physical Apple device, not a simulator
- the initial pairing process between the app and the designated hardware
- the entire app workflow with the designated hardware

Both the tag and the iPhone have to be in frame. A screen recording alone is what got rejected.

## What you need

- The NFC tag you have. **First pairing writes an NDEF record and then locks the tag read-only,
  permanently** (`CoreNFCTagWriter` — NTAG lock bits are one-way). Don't film with a tag you want
  for anything else. A locked tag still pairs afterwards: the writer's failure falls back to
  reading the factory UID, so a reinstall re-pairs the same tag fine.
- Optional but worth €2: **two more NTAG215 tags**. Apple asked for *all* the NFC functionality,
  and two of the flows need more than one tag — an exit route (several tags tapped in order) and
  the foreign-tag refusal. With one tag those two shots are impossible and have to be described
  in the notes instead of shown.
- A second camera on something that doesn't move — a tripod, a stack of books, a phone stand.
- Good, flat light. No overhead lamp behind you: the screen glares and the reviewer sees nothing.

## Record against the build under review

Film the build Apple will look at, not a Debug build off your Mac:

1. Upload `build/export/Brick.ipa` (1.0 (3)) to App Store Connect.
2. Add yourself as an internal tester and install it through TestFlight.
3. Delete any existing copy of the app first. That both clears every restriction it applied and
   gets you the onboarding and pairing screens, which Apple explicitly asked to see.

Then, on the phone, before you roll:

- Settings → Display & Brightness → **Auto-Lock: 5 Minutes** (the default kills the screen mid-take).
- Brightness up. Plug it in if you like — charging is invisible on camera.
- Clear the home screen of anything personal; the blocked-app shot puts it on video.
- **Leave demo-tag mode off.** It is off on a fresh install. Filming with `BRICK-REVIEW` on would
  show simulated taps, which is exactly the doubt Apple is trying to settle. It gets its own shot
  at the end, deliberately.

## How to film it

### Option A — one camera, recommended

Frame the phone flat on a table or held in one hand, with room for the tag to come in from the
side. Shoot landscape, 1080p or 4K, 30 fps. Get close enough that the screen text is legible on
playback — check one take before shooting all of it.

This is the whole requirement met in the simplest way: one continuous frame containing a real
iPhone, a real tag, and your hand moving one to the other. Nothing about it can be read as a
simulator.

### Option B — OBS composite, optional

Use this only if Option A's screen legibility disappoints you. It gives a crisp UI feed next to a
camera view of the hardware.

1. Connect the iPhone to the Mac by USB and trust the computer.
2. OBS → Sources → **+** → Video Capture Device → Device: your iPhone. macOS exposes the phone's
   screen there, the same feed QuickTime's Movie Recording uses.
3. Add a second source for the hardware: Continuity Camera (another iPhone) or a webcam, pointed
   at the phone, your hand and the tag.
4. Canvas 1920×1080. Screen feed on the left, camera on the right — side by side, not
   picture-in-picture; the camera half is the evidence, don't shrink it to a postage stamp.
5. Settings → Output → Recording: format **mp4**, encoder Apple VT H264 Hardware, high quality.

Two cautions. The cable means you cannot film the walk-away this way — shoot that part with
Option A. And keep the physical phone visible in the camera source throughout, so the composite
reads as one device filmed two ways rather than a mirrored feed.

## Shot list

Aim for four to five minutes. **Never cut during a tap** — the tag approaching the phone and the
screen reacting must be in one continuous shot, or the thing Apple asked to see is exactly the
thing missing. The NFC antenna is at the **top of the back** of the phone; hold the tag there.

1. **Slate.** Hold the tag and the phone together in frame. Open TestFlight and show
   `buriko 1.0 (3)`. That answers "the current version" without a word of narration.
2. **Onboarding.** Launch the app. Swipe the three pages: "The idea", "Privacy", "The catch".
3. **Screen Time access.** "Allow Screen Time access" → Apple's Family Controls dialog → Allow.
4. **Initial pairing — the shot they asked for.** "Pair your brick" → the screen reads "Hold your
   iPhone near it." Bring the tag to the back of the phone. The Core NFC sheet appears, the read
   succeeds, the app moves on. Then name it and fill "Where you keep it" (e.g. "on the shelf in
   the hall"). One take, no cut.
5. **Choose what it blocks.** Apple's own picker; choose two or three apps you actually have.
6. **Start a session.** "Tap your brick to start" → Length: 15 minutes (say on camera that 15 is
   the floor because `DeviceActivitySchedule` refuses less) → tap the tag → the dial appears with
   "until HH:MM".
7. **The shield.** Leave the app, open one of the blocked apps from the home screen. The shield
   shows the minutes left and the note about where the brick is. Hold on it for a few seconds.
8. **A foreign tag does nothing.** *(needs a second tag)* Tap an unpaired tag: the app refuses it
   on identity. This is the clearest proof that a real UID is being read and matched.
9. **Tapping early is refused.** Tap the paired tag before the minimum has passed: "Not yet", plus
   the time remaining. Another real read, and the rule the product is built on.
10. **The walk.** Put the tag on a shelf in another room. Walk out with the phone, camera
    following. This is the product; it costs you twenty seconds of video.
11. **The wait.** Fifteen minutes have to pass. Either keep rolling and speed that stretch up in
    the edit with a caption ("15 minutes, unedited"), or make a single labelled cut. Don't cut
    silently.
12. **End with the tag.** Walk back, tap the tag: the session ends and the shield clears. Reopen
    the app that was blocked and show it opens now. Beginning to end, closed.
13. **Reverse setup.** *(optional, shows the other direction)* Settings → Setups → a reverse setup
    standing: blocked by default, a tap buys a fixed open window. Tap the tag, show
    "open until HH:MM".
14. **Exit route.** *(needs two tags)* Settings → Setups → route with two bricks. Ending asks for
    "Tap <name>", then the second tag, in order. Show a wrong tag mid-route costing the progress
    if you have the time.
15. **Emergency unlock.** Hold to unlock, ten seconds, three per rolling week. Not NFC, but it is
    the fastest way for a reviewer to end a session and they should see it exists.
16. **The reviewer's own path.** Settings → App Review → enter `BRICK-REVIEW`. The banner says the
    demo tag is on; "Tap your brick" now completes with no hardware. Then turn it off again on
    camera. This proves the review notes are true — and, coming last, it cannot be mistaken for
    how the rest of the video was made.

## The short version — and what the submitted video contains

The full shot list above runs long, mostly because of the 15-minute wait. That wait is avoidable:
**"Locked for at least" offers 0 and 5 minutes**, and the minimum is per setup — only the *session
length* carries Apple's 15-minute floor. Set the minimum to 5 and the whole loop films in one
continuous take.

This is the take that was submitted with 1.0 (3), 9 minutes 19 seconds:

1. Pairing a fresh tag.
2. Starting a session by tapping it.
3. A blocked app showing the shield.
4. Tapping the tag before the minimum: refused, with the time remaining.
5. The tag left in another room, and the walk back.
6. Tapping the tag again: the session ends, and the blocked app opens.
7. The emergency unlock — a ten-second press.

A first cut ran 91 seconds and showed pairing, a session start and the emergency press, with no
shield and no tap-to-end. That was not enough, and it is worth knowing why: the shield is the only
evidence the app does what it claims, and ending with the tag is half of what the tag is for — the
ten-second press is not NFC at all. Reverse mode and exit routes were left out on purpose. They
are not what Apple asked about, and a route needs a second tag.

## Export and upload

- 1080p, H.264, mp4 or mov. No music, no titles beyond the captions for cuts.
- Upload to YouTube as **Unlisted** (not Private — private needs a Google sign-in and reviewers
  get a wall). Title: `buriko 1.0 (3) — NFC demo`. Mark it "not made for kids" so comments and
  playback aren't restricted, and confirm it plays in a private browser window.

Then in App Store Connect → the app version → **App Review Information**:

- Paste the URL into Notes, above the existing notes, as the first line.
- Sign-in required: **No**. Contact name, phone and email filled in.
- Reply in Resolution Center from `store/REVIEW-REPLY-2.1.md`.

## Checklist before you upload the video

- [ ] The tag and the phone are in the same frame during every tap
- [ ] No cut inside any tap
- [ ] Screen text legible at 1080p
- [ ] Demo-tag mode off for shots 1–15, shown deliberately in 16
- [ ] The version on screen is 1.0 (3)
- [ ] Initial pairing is in the video, from an app with no tag paired
- [ ] A session starts, shields a real app, and ends by tapping the tag
- [ ] Nothing personal on the home screen or in a notification banner
