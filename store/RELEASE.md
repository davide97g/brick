# Releasing a build — the runbook

What "prepare a release" means in this repository, in the order it has to happen. Every step is
verified by reading something back, not by assuming the previous step worked.

Standing instruction: when asked to prepare a release, work through this without stopping to ask.
Stop only for the two things a script cannot do — filming the demo video, and pressing Submit for
Review — and for anything that contradicts what is written here.

## Credentials

App Store Connect API key, already on disk:

- Key ID `MFCGJ8UX92`, Issuer ID `f8b76e45-dfdd-4938-916a-f2840dde0f09`
- `~/.appstoreconnect/private_keys/AuthKey_MFCGJ8UX92.p8`

`store/connect.py` signs its own ES256 JWT with `openssl` — there is no PyJWT on this machine and
none is needed.

## 1. Bump the build number

`CURRENT_PROJECT_VERSION` in `project.yml`, then `xcodegen generate`. A build number cannot be
reused; App Store Connect answers `previousBundleVersion` if you try. `MARKETING_VERSION` and
`CURRENT_PROJECT_VERSION` are declared once and inherited, so the app and both extensions always
ship the same pair (a mismatch is ITMS-90473).

## 2. Prove the thing works before signing it

```sh
swift test --package-path BrickKit
xcodebuild -project Brick.xcodeproj -scheme Brick \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## 3. Archive, export, and inspect what came out

```sh
xcodebuild -project Brick.xcodeproj -scheme Brick -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Brick.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/Brick.xcarchive \
  -exportOptionsPlist store/ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates
```

Then check the artefact rather than trusting the build log — unzip `build/export/Brick.ipa` and
confirm all of it:

- `codesign -d --entitlements - --xml` on `Brick.app` and both `.appex`es:
  `com.apple.developer.family-controls` true in all three, the App Group in all three,
  `com.apple.developer.nfc.readersession.formats` = `TAG` only (`NDEF` is rejected by the iOS 26
  SDK — ITMS-90778), `get-task-allow` false, `beta-reports-active` true.
- `security cms -D -i embedded.mobileprovision` on all three: store profiles, each carrying
  Family Controls, not expired.
- `plutil -p` the three Info.plists: same `CFBundleShortVersionString` / `CFBundleVersion`,
  `CFBundleDisplayName` present in both extensions (ITMS-90360), `UIDeviceFamily` = [1],
  `ITSAppUsesNonExemptEncryption` false, `PrivacyInfo.xcprivacy` in the bundle.
- The 1024 icon has no alpha channel (PNG colour type 2 or 0, never 4 or 6).

## 4. Upload

```sh
xcrun altool --upload-app -f build/export/Brick.ipa -t ios \
  --apiKey MFCGJ8UX92 --apiIssuer f8b76e45-dfdd-4938-916a-f2840dde0f09
```

Then wait for `processingState` to reach `VALID` and attach it to the version. A build that is
still processing does not appear in Add Build, which looks like a failed upload and is not one.

## 5. Screenshots

```sh
python3 store/screenshots/capture.py            # 6.9" natively, 6.5" derived from it
```

Then **look at every capture**. Not the first one — every one. Both bugs this pass found were
invisible from the code: a status bar faking 9:41 over a screen that derives its times from the
real clock, and the running dial's last digit blurred by `.contentTransition(.numericText())` in
every frame after the first tick. Re-capture after any UI change; a set that predates a feature
shows an app that does not exist.

## 6. Push the listing

```sh
python3 store/connect.py show                        # read the live state first
python3 store/connect.py metadata                    # copy, categories, review notes
python3 store/connect.py screenshots                 # replaces both sets
python3 store/connect.py metadata --video-url <URL>  # once the demo video exists
```

`store/METADATA.md` is the source; the script parses it, so edit the Markdown and re-run rather
than typing into the web form. It enforces Apple's character limits before sending.

Read it back with `show` afterwards. Note that App Store Connect returns relationship data only
when asked for it by name — categories read as `None` without `?include=primaryCategory,...`,
which looks exactly like an unset category and is not one.

## 7. The two things left

- **The demo video.** App Review asked for one under Guideline 2.1 and will ask again without it.
  Shot list and filming setup: `store/DEMO-VIDEO.md`. This needs the tag and a camera; it cannot
  be scripted.
- **Submit for Review.** The developer's call, not the agent's.

## What review has actually rejected, and why

Kept so the same ground isn't re-covered. Full detail in `store/SUBMISSION.md`.

| Message | Real cause |
|---|---|
| ITMS-90360 | `CFBundleDisplayName` missing from the extension bundles |
| ITMS-90778 | `NDEF` in the NFC entitlement, disallowed by the iOS 26 SDK |
| 2.5.1, automated | Apple's scan was wrong; the entitlement was in every bundle. Stopped firing on its own |
| 1.3, Kids Category | The app had *no* category set at all. Kids was never selected |
| 2.1, demo video | Review notes were **empty** in App Store Connect — the reviewer had no way to know a demo mode existed. The copy had never left `store/METADATA.md` |

The lesson in the last two rows is the same one: check what App Store Connect actually holds,
because the repository having the right words in it does not mean Apple received them.
