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

**What you need**

An NFC tag — an NTAG215 sticker or card costs about a euro — and, if you want the object,
a printed shell. The models and print profiles are public domain, in the same repository as the
app.

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

> buriko pairs your iPhone with a physical NFC tag. Tapping the tag starts a Screen Time session;
> tapping it again ends one, but only after the minimum duration you chose. Everything is local:
> no account, no server, no networking code of any kind.
>
> **Testing without a tag.** The app normally needs a physical NFC tag, which you don't have.
> Open Settings (the control in the top right of the main screen), scroll to **App Review**, and
> enter the code **BRICK-REVIEW**. The app then uses a simulated tag: "Tap your brick" buttons
> complete immediately, so you can pair, start a session and end one with no hardware. A banner
> in Settings says the demo tag is on, and it can be turned off there.
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
> The source is public: https://github.com/davide97g/brick

## Screenshots

Two sets, same four screens:

- `store/screenshots/6.9/` — 1320 × 2868, captured natively on the iPhone 17 Pro Max simulator.
- `store/screenshots/6.5/` — 1242 × 2688, scaled to width and centre-cropped from the set above
  (the aspect ratios differ by 0.4%, so cropping a sliver of near-black margin beats stretching
  the dial into an ellipse).

App Store Connect's iPhone slot decides which it wants. The 6.5" slot rejects 1320 × 2868 —
give it the 6.5" set; a 6.9" slot (via "View All Sizes in Media Manager") takes the native one.

Upload these four, in order:

1. `02-idle.png` — Ready, with what the brick blocks
2. `03-start-sheet.png` — picking a length, with the minimum stated
3. `04-running.png` — the dial mid-session, the gate tick, where the brick is
4. `06-blocklist.png` — session length and the minimum, and why the minimum exists

`01-onboarding.png` (the privacy page) is optional as a fifth. `05-settings.png` is **not** for
the listing — it shows the App Review section — but it is the evidence that section renders
correctly.

The shield screen itself can't be captured this way: it is drawn by the extension in another
process, over a blocked app, and never appears in the host app.
