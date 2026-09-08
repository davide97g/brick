# Submission state

What is done, what is blocked, and what is unverified. Updated 8 September 2026.

## Done and observed

- Paid membership active. Team `DA596D32QB`; development profiles now carry
  `com.apple.developer.family-controls` and the NFC reader formats, and expire in a year rather
  than a week.
- Device build signs, installs and launches on an iPhone 14.
- `Release` archive succeeds with no warnings:
  `xcodebuild -project Brick.xcodeproj -scheme Brick -configuration Release -destination 'generic/platform=iOS' -archivePath <path> archive`
- App icon is opaque. A 1024 icon with an alpha channel is rejected at upload; the one in the
  repository had one until now.
- Version numbers come from `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`, so
  the app and both extensions always ship the same pair (mismatches are ITMS-90473).
- `ITSAppUsesNonExemptEncryption = NO` is in the built Info.plist — verified with `plutil -p`.
- `PrivacyInfo.xcprivacy` is copied into `Brick.app` — verified in the built bundle.
- iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), which also clears the "all interface orientations
  must be supported" warning that iPad support would otherwise raise.
- Screenshots captured at 1320 × 2868 in `store/screenshots/6.9/`, one per screen, each one
  looked at rather than assumed — the `-uiPreview blocklist` hook was documented but missing, and
  the first pass caught it landing on the home screen instead.

## Cleared: Family Controls (Distribution)

Requested and **approved on 2 September 2026** (requests `NSBFJ2S8J7` and `5DXKNVZG8K`). The grant
is **team-level** — the capability shows as *Assigned* under the team's additional capabilities —
so it covers all three App IDs at once. One of the three requests failed on Apple's side with a
503 at submit; that turned out not to matter.

The App Store export now succeeds:

```sh
xcodebuild -project Brick.xcodeproj -scheme Brick -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Brick.xcarchive -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/Brick.xcarchive \
  -exportOptionsPlist store/ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
```

`** EXPORT SUCCEEDED **`, producing a signed `Brick.ipa`. All three embedded store profiles carry
`com.apple.developer.family-controls`, the app's also carries the NFC reader formats, and they
expire 2 September 2027.

### Two upload rejections, both fixed

The first upload attempt was rejected by App Store Connect's validator — not by review:

- `90360`: `CFBundleDisplayName` is required in each extension bundle. `project.yml` now declares
  it for both ("Brick Monitor", "Brick Shield"); never hand-write the extension plists, xcodegen
  overwrites them.
- `90778`: with the iOS 26 SDK, `NDEF` is disallowed in
  `com.apple.developer.nfc.readersession.formats`. The entitlement now lists `TAG` only. Nothing
  is lost: both adapters use `NFCTagReaderSession`, and the pairing write goes through
  `NFCMiFareTag.writeNDEF`, which the `TAG` format covers. There is no `NFCNDEFReaderSession`
  anywhere in the app.

`CURRENT_PROJECT_VERSION` was bumped to 2 at the same time, since a build number can't be reused.

### Uploading

The build can go up as soon as the App Store Connect record exists (Transporter rejects a build
whose app record is missing). Either:

- Xcode → Window → Organizer → Distribute App, or
- an App Store Connect API key (Users and Access → Integrations), then `destination: upload` in
  `store/ExportOptions.plist` plus `-authenticationKeyPath`, `-authenticationKeyID` and
  `-authenticationKeyIssuerID` on the export command.

## Solved: the reviewer has no tag

A session starts by reading an NFC tag, and pairing stores that tag's UID. A reviewer with no tag
could not pair, and so could not see a single session — an "unable to review" rejection, not a
bad one.

Settings now has an **App Review** section. Entering `BRICK-REVIEW` swaps the Core NFC reader for
the same stand-in the Simulator uses, so pairing, starting and ending all work with no hardware.
The code is in the review notes in `store/METADATA.md`.

- `DemoTagAccess` (app target) owns the code and the flag, in `UserDefaults`.
- `SwitchingTagReader` / `SwitchingTagWriter` (BrickKit) pick a side per scan and know nothing
  about which is which; `AppEnvironment` hands both in, keeping the composition-root rule intact.
- Four tests in `SwitchingTagTests` cover both sides, per-scan switching, and writes following
  reads. 40 tests pass.
- While it's on, Settings says so and offers a way off. An app that quietly stopped needing the
  object would be lying about what it is.

The code being public in this repository costs nothing: anyone wanting out of a session can
already delete the app, which onboarding states plainly.

## Closed: Guideline 1.3, Kids Category information request

**The premise was wrong, and checkable over the API.** On 8 September 2026 the app had *no
category set at all* — `primaryCategory` and `secondaryCategory` were both `null` on the app
info, and no Kids category was selected anywhere. So there was nothing to clear. Both are now set
(Productivity / Health & Fitness) through `store/connect.py`. The four answers below still hold
and are worth sending as the reply, minus the correction paragraph about clearing Kids.

### The four questions

App Review sent an automated 1.3 message on 4 September 2026 asking the four standard Kids
Category questions (third-party analytics, third-party advertising, sharing with third parties,
any other data collection). All four answers are "no", and the answers are checkable rather than
asserted:

- No third-party dependencies. `project.yml` declares one package, `BrickKit`, by local path.
- No networking code. `grep -rE "URLSession|WKWebView|CFNetwork|Network\."` over the Swift
  sources returns nothing; no ATS exception domains, no SKAdNetwork entries.
- `PrivacyInfo.xcprivacy`: `NSPrivacyTracking = false`, empty tracking domains, empty
  `NSPrivacyCollectedDataTypes`, one accessed-API reason (CA92.1, own `UserDefaults`).

**The premise needs checking first.** The message says the app "has been submitted for the Kids
Category", but `store/METADATA.md` specifies Productivity / Health & Fitness with a 4+ age
rating — and 4+ is not the Kids Category; they are separate settings in App Store Connect. Look
at App Information → Category before replying. If *Kids* is selected there, clear it: the Kids
Category requires a parental gate on external links and forbids third-party analytics and ads
outright, so being in it by accident only invites unrelated rejections.

Draft reply, covering both the correction and the four answers: `store/REVIEW-REPLY-1.3.md`.

## Cleared: the 2.5.1 automated Family Controls check

It stopped firing. Build 1.0 (2) reached an actual human review on 5 September 2026 — the
rejection that came back names review devices (iPhone 17 Pro Max, iPad Air 11-inch M3) and asks
for a demo video, which an automated entitlement scan does not do. Nothing on this side changed
between the two messages, so the scan was the wrong conclusion it looked like. Kept below for the
record, and `store/REVIEW-REPLY.md` never had to be sent.

### What the 2.5.1 message said

App Review rejected build 1.0 (2) on 2 September 2026 with an automated message: the app "uses
one or more Screen Time APIs but the app has not been submitted with the Family Controls
entitlement". No human review took place.

The binary is not the problem. Re-exported on 3 September 2026 and inspected with
`codesign -d --entitlements`:

- `Brick.app`, `BrickMonitor.appex` and `BrickShield.appex` each carry
  `com.apple.developer.family-controls = true`, with `get-task-allow = false` and
  `beta-reports-active = true` — a real App Store signature.
- Each is signed with its own "iOS Team Store Provisioning Profile", and all three profiles carry
  the entitlement; they expire 2 September 2027.

The portal is not the problem either. Checked on 3 September 2026: all three App IDs
(`com.davideghiotto.brick`, `.monitor`, `.shield`) show Family Controls as **Assigned** under
Additional Capabilities. The request that failed with a 503 on approval day left no gap.

So the grant is in place, the entitlement is in every bundle, and the check still fired. Nothing
on this side to change — it is Apple's automated scan reaching the wrong conclusion.

`store/REVIEW-REPLY.md` holds the reply that was drafted for it. Don't send it: the message it
answers is no longer the live one.

## Open: 1.0 (2), Guideline 2.1, demo video needed

App Review asked on 5 September 2026 for a video showing the physical iPhone and the physical NFC
tag interacting — the initial pairing, then the whole workflow. Submission ID
`bd38e031-a11b-445c-9d03-bf18edbd4cb0`. A screen recording is what was rejected; both objects have
to be in frame, and no cut may fall inside a tap.

- Shot list, filming setup and the export/upload steps: `store/DEMO-VIDEO.md`.
- Reply draft, to send once the URL exists: `store/REVIEW-REPLY-2.1.md`.
- The video URL is now the first line of the review notes in `store/METADATA.md`, and App Review
  Information will not be complete without it.

Two flows need more than one tag to film — an exit route, and the foreign-tag refusal — so two
spare NTAG215s are worth buying before recording. Note that the first pairing writes an NDEF
record and **locks the tag read-only permanently**; a locked tag still pairs afterwards, because
the writer's failure falls back to reading the factory UID.

## Build 1.0 (3): archived, exported, verified

`CURRENT_PROJECT_VERSION` is 3 — build 2 is spent, and the video has to show the version under
review. Rebuilt on 8 September 2026 and inspected rather than assumed:

- 124 BrickKit tests pass; the Simulator build and the Release archive both succeed with no
  warnings.
- `** EXPORT SUCCEEDED **` → `build/export/Brick.ipa`, 1.5 MB.
- `1.0` / `3` in all three Info.plists, so no ITMS-90473. `CFBundleDisplayName` present in both
  extension bundles.
- Entitlements in the exported binaries: `com.apple.developer.family-controls` = true in
  `Brick.app`, `BrickMonitor.appex` and `BrickShield.appex`; NFC formats `TAG` only, no `NDEF`;
  the App Group in all three; `get-task-allow` = false and `beta-reports-active` = true.
- All three embedded profiles are "iOS Team Store Provisioning Profile", each carrying Family
  Controls, expiring 2 September 2027.
- `ITSAppUsesNonExemptEncryption` = false, `PrivacyInfo.xcprivacy` in the bundle,
  `UIDeviceFamily` = [1] (iPhone only — the iPad Air the reviewer used was running it in
  compatibility mode), portrait only.
- The 1024 icon is PNG colour type 2: RGB, no alpha channel.

## Done: the listing filled from the repository, over the API

`store/connect.py` signs with the App Store Connect API key and pushes what `store/METADATA.md`
says, so the copy lives here rather than in a web form. Run on 8 September 2026:

- Version localization: 2318-character description (it said "Brick" where it should say buriko),
  90 characters of keywords, promotional text, support URL.
- App info: subtitle "A session you walk away from", privacy policy URL, and the two categories,
  which were unset.
- **App Review notes: 2716 characters, and they were empty.** The `BRICK-REVIEW` demo code, the
  "testing without a tag" instructions and the Screen Time explanation had never left
  `store/METADATA.md` — so the reviewer who asked for a demo video had no way to know a demo mode
  existed. That is likely half of why 1.0 (2) came back.
- Nine screenshots in each of `APP_IPHONE_67` (1320 × 2868) and `APP_IPHONE_65` (1242 × 2688),
  replacing the five that were there, all `COMPLETE` with no delivery errors.

Still to add: the demo video URL, which goes in as the first line of the notes —
`python3 store/connect.py metadata --video-url <URL>`.

## Done: screenshots regenerated for build 3

The set on the listing was captured on 2 September, before setups, exit routes, reverse mode and
the dynamic-type pass all landed on 3 September — it showed an app that no longer exists.
`store/screenshots/capture.py` now seeds the state file per screen and captures eleven, and every
one was looked at. Two things the looking caught: the status bar was overriding the time to Apple's
9:41 while the screen under it derived "until 23:43" from the real clock, and the running dial's
last digit was blurred in every frame because `.contentTransition(.numericText())` animates for
most of each second — that shot is now taken at first paint, before the first tick.

## Name

The app ships as **buriko** on the App Store; the repository, the code and the physical object
are all still Brick. Listing copy in `store/METADATA.md` follows that split — buriko is the app,
the brick is the thing you leave behind.

## Still to do

- ~~Upload the build and select it for the version.~~ Done: 1.0 (3) is uploaded, `VALID`, and
  attached to version 1.0.
- Install 1.0 (3) on the phone through TestFlight, then record the demo video from
  `store/DEMO-VIDEO.md`. Filming it *is* the device pass listed below: Screen Time authorization,
  a real tag pairing, a shield going up, and the monitor clearing it, all on camera.
- Put the video URL in App Review Information → Notes and send `store/REVIEW-REPLY-2.1.md`.
- Reply to the 1.3 message from `store/REVIEW-REPLY-1.3.md` — the category paragraph needs
  trimming first, since Kids was never selected.
- Submit for review once the video URL is in the notes.

## Unverified

Everything about behaviour on a real device beyond launch. The shield has never been observed
going up, `BrickMonitor` has never been observed firing with the app dead, and no NFC tag has
been read on the phone. The demo-tag path is tested in BrickKit and builds for device, but has not
been exercised there either. Recording the demo video settles all of it at once — the video is
worthless unless every step in it actually worked — so nothing here should be claimed as working
until that footage exists.
