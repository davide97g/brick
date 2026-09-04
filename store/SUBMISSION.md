# Submission state

What is done, what is blocked, and what is unverified. Updated 4 September 2026.

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

## Open: Guideline 1.3, Kids Category information request

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

## Rejected: 1.0 (2), 2.5.1, automated Family Controls check

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

Next:

- Reply in Resolution Center with the evidence above — draft in `store/REVIEW-REPLY.md`.
- Only if Apple asks for one: bump `CURRENT_PROJECT_VERSION` to 3 and upload again. A build
  number cannot be reused.

## Name

The app ships as **buriko** on the App Store; the repository, the code and the physical object
are all still Brick. Listing copy in `store/METADATA.md` follows that split — buriko is the app,
the brick is the thing you leave behind.

## Still to do

- Confirm the category in App Store Connect is Productivity / Health & Fitness and not Kids,
  then reply to the 1.3 message from `store/REVIEW-REPLY-1.3.md`.
- Create the App Store Connect record and fill it from `store/METADATA.md`, then upload the build.
- Point the Privacy Policy URL at `store/PRIVACY.md` on GitHub (or a Pages site).
- Exercise the app on a device once — Screen Time authorization, a shield going up, the monitor
  clearing it — before asking anyone to review it.

## Unverified

Everything about behaviour on a real device beyond launch. The shield has never been observed
going up, `BrickMonitor` has never been observed firing with the app dead, and no NFC tag has
been read — there is no tag yet. The demo-tag path is tested in BrickKit and builds for device,
but has not been exercised on the phone either. None of that is required to upload a build; all
of it is required before the app is worth reviewing.
