# App Store listing — draft

Everything App Store Connect asks for, drafted here so the wording lives in the repository
rather than in a web form. Character limits are Apple's.

## Identity

| Field | Value |
|---|---|
| Name (30) | `buriko` — as created in App Store Connect. The object it pairs with is still called a brick throughout the copy; the app is what's named buriko. |
| Subtitle (30) | `A session you walk away from` |
| Bundle ID | `com.davideghiotto.brick` |
| SKU | `brick-ios-001` |
| Primary category | Productivity |
| Secondary category | Health & Fitness |
| Price | Free |
| Age rating | 4+ |
| Availability | All territories |

## Promotional text (170)

One tap on a printed brick starts a session. Leaving the brick behind is the point: the way out
is the walk back to it, and only after the time you agreed to.

## Description (4000)

buriko pairs your phone with one small object you print yourself: a brick.

Tap the brick and pick a length. The apps you chose go behind a shield. Then you leave the brick
where it is — on a shelf, in another room, at home — and take your phone with you. The only
early way out is walking back to it, and only once the minimum you agreed to has passed. Before
that, the app tells you how long is left and nothing else.

There is no streak to protect, no score to raise, no plant that dies if you fail. Those make the
phone matter more, and the whole value of this app is not caring about it.

**How a session works**

• Tap the brick. Your tag's UID is matched against the paired one; a foreign tag does nothing.
• Pick a length. Fifteen minutes is the floor — Apple's scheduler refuses anything shorter.
• The shield goes up, and the end is scheduled before the shield is trusted.
• Blocked apps show minutes remaining and the note you wrote about where you left the brick.
• It ends by itself, with the app closed, at the time you set.
• Or you go back and tap the brick again, once the minimum has passed.
• Or you use one of three emergency unlocks per rolling week, behind a ten-second hold. The
  valve has to exist. It just shouldn't be something a thumb does by reflex.

**What it never does**

• No account, no sign-in, no sync.
• No analytics, no crash reporting, no advertising.
• No networking code of any kind — the source is public and that is checkable.
• The app never learns which apps you blocked. Apple hands it opaque tokens, and it stores them
  without ever decoding them.

**No brick yet?**

Face ID can stand in for one. Sessions start and end the same way, and the minimum duration and
the emergency quota are identical — but the key is in your hand instead of across the room, and
the app says so where you choose it. Pair a brick later and it takes over.

**What you need**

An NFC tag — an NTAG215 sticker or card costs about a euro — and, if you want the object,
a printed shell. The models and print profiles are public domain, in the same repository as the
app. Without either, Face ID gets you started.

**One thing no app can fix**

Deleting buriko removes every restriction it applied. If you want that door shut, turn on
Settings → Screen Time → Content & Privacy Restrictions → App Deletion → Don't Allow.

## Keywords (100, comma-separated, no spaces)

`focus,screen time,block apps,nfc,distraction,deep work,phone,limit,offline,timer,attention`

## What's New (first release)

First release.

## URLs

| Field | Value |
|---|---|
| Support URL | `https://github.com/davide97g/brick` |
| Marketing URL | _optional; the repository README doubles as one_ |
| Privacy Policy URL | `https://github.com/davide97g/brick/blob/main/store/PRIVACY.md` — GitHub renders it, which is all App Store Connect requires. A Pages site is nicer but not needed to submit. |

## App Privacy answers

Data collection: **Data Not Collected.** No data types are collected, so no linking, tracking, or
third-party disclosure questions apply. Tracking: **No.**

This matches `Brick/Resources/PrivacyInfo.xcprivacy`, which declares no collected data types and
one required-reason API (`UserDefaults`, reason `CA92.1`).

## Export compliance

`ITSAppUsesNonExemptEncryption = NO` is set in the generated Info.plist, so the question is
answered at build time and never asked per upload.

## Review notes

Paste this into App Store Connect verbatim. **Demo access code: `BRICK-REVIEW`** — enter it under
Settings → App Review. Fill the demo-account fields with any placeholder; there is no account.
Sign-in required: **No**.

The **first line must be the demo video URL** — App Review asked for one under Guideline 2.1 on
5 September 2026 and will ask again without it. Record it from `store/DEMO-VIDEO.md`.

> **Demo video (physical iPhone + physical NFC tag): [VIDEO URL]**
>
> buriko pairs your iPhone with a physical NFC tag. Tapping the tag starts a Screen Time session;
> tapping it again ends one, but only after the minimum duration you chose. Everything is local:
> no account, no server, no networking code of any kind.
>
> **Testing without a tag.** The app normally needs a physical NFC tag, which you don't have.
> Open Settings (the control in the top right of the main screen), scroll to **App Review**, and
> enter the code **BRICK-REVIEW**. The app then uses a simulated tag: "Tap your brick" buttons
> complete immediately, so you can pair, start a session and end one with no hardware. A banner
> in Settings says the demo tag is on, and it can be turned off there. The code also swaps the
> Face ID prompt for a simulated one, so a review device with no enrolled face is not blocked
> either.
>
> **Face ID as a second path.** A user with no tag can choose Face ID during setup ("No brick
> yet? Use Face ID instead") and start and end sessions with it. The same minimum duration and
> the same emergency quota apply. Face ID is used only as an on-device gesture of intent — no
> biometric data is read, stored or transmitted.
>
> **A full pass takes about two minutes:**
> 1. Grant Screen Time access when asked. Brick requests Family Controls for the individual case
>    — this device restricting itself. There is no family sharing, no second device, and the app
>    makes no parental-control claim.
> 2. Choose apps to block, then pick a session length. 15 minutes is the shortest the app offers
>    because `DeviceActivitySchedule` rejects anything shorter.
> 3. Tap "Tap your brick to start". Blocked apps now show the app's shield screen.
> 4. To end early: tap the brick again once the minimum has passed, or use "Hold to unlock" — an
>    emergency unlock, three per rolling seven days, behind a ten-second press. That is the
>    fastest way to end a session during review.
>
> **Screen Time usage.** The app applies `ManagedSettings` shields to the selection the user
> makes with Apple's own picker, and schedules the end with `DeviceActivityMonitor`. It never
> sees which apps were chosen: `ApplicationToken`s are opaque, and the encoded selection is
> stored as bytes and never decoded.
>
> **The hardware.** There is no proprietary accessory. The tag is an ordinary NTAG215 sticker or
> card, about a euro, optionally inside a 3D-printed shell whose model is public domain in the
> repository. Any NFC tag works: the app reads the tag's factory UID with Core NFC
> (`NFCTagReaderSession`, entitlement format `TAG`) and matches it against the paired UID. On the
> first pairing it also writes an NDEF identity record and locks the tag read-only. What makes the
> object matter is where the user leaves it, not what it contains.
>
> The source is public: https://github.com/davide97g/brick

## Screenshots

Captured by `python3 store/screenshots/capture.py`, which seeds the state file per screen rather
than tapping through — that is the only way to reach the screens behind a tap, and it is
repeatable. Every screen is looked at afterwards; the onboarding card bug once survived a pass
because only page 0 was captured.

Two sets, same screens:

- `store/screenshots/6.9/` — 1320 × 2868, captured natively on the iPhone 17 Pro Max simulator.
- `store/screenshots/6.5/` — 1242 × 2688, scaled to width and centre-cropped from the set above
  (the aspect ratios differ by 0.4%, so cropping a sliver of near-black margin beats stretching
  the dial into an ellipse).

In the API there is no 6.9" display type: the 1320 × 2868 set goes into **APP_IPHONE_67** and the
1242 × 2688 set into **APP_IPHONE_65**. `python3 store/connect.py screenshots` replaces both.

The listing order, first three being the ones the install sheet shows:

1. `01-idle` — Ready, and what the brick blocks
2. `03-running` — the dial mid-session, the gate, and which brick to walk to
3. `04-reverse` — reverse mode standing: blocked by default, a tap buys an open window
4. `02-start-sheet` — picking a length
5. `05-blocklist` — the setup: length, minimum, direction, the walk back
6. `06-setups` — several setups, one per occasion
7. `07-route` — the exit route, tap in order
8. `08-bricks` — the set of paired tags
9. `11-onboarding` — the privacy page

Not in the listing: `10-settings` shows the App Review section, so it is evidence that the
section renders rather than a selling point, and `09-brick` is a detail screen that says nothing
the others don't.

The shield screen itself can't be captured this way: it is drawn by the extension in another
process, over a blocked app, and never appears in the host app. It belongs in the demo video
instead — see `store/DEMO-VIDEO.md`.
