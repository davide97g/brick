# Reply to App Review — Guideline 1.3, Kids Category information request

Received: 4 September 2026. Sent: (not yet sent)

## Before sending: check the category

This app was not intended for the Kids Category. `store/METADATA.md` sets Productivity as the
primary category and Health & Fitness as the secondary, with a 4+ age rating — and a 4+ rating is
not the Kids Category. The two are separate settings, and the questionnaire only fires when *Kids*
is actually selected as a category.

So check App Store Connect → the app → App Information → Category before replying. If *Kids* is
selected there (primary or secondary), clear it and set Productivity / Health & Fitness. The Kids
Category carries requirements this app does not meet and does not want: a parental gate on every
external link, no third-party analytics or advertising of any kind, and a Kids-specific privacy
policy. Being in it by accident invites rejections unrelated to what the app does.

Then send the reply below, which answers the four questions either way.

---

Hello,

Two things — first a correction, then the answers you asked for.

**The Kids Category was not intended.** buriko is a Productivity app for adults: it applies
Screen Time restrictions to the owner's own device, unlocked by tapping a physical NFC object the
owner leaves in another room. It is rated 4+ because it contains no objectionable content, but it
is not designed for or directed at children. [If you cleared the category: "We have corrected the
category in App Store Connect to Productivity (primary) and Health & Fitness (secondary)."] Please
let us know if anything further is needed to take the submission out of the Kids Category.

The answers below hold regardless of category.

**1. Does the app include third-party analytics?**

No. There is no analytics of any kind, first- or third-party. The app has no third-party
dependencies at all: its only package dependency is BrickKit, a local Swift package inside the
same repository. No analytics, attribution, crash-reporting or A/B-testing SDK is linked.

**2. Does the app include third-party advertising?**

No. There is no advertising, no ad SDK, no SKAdNetwork identifiers, and nothing purchasable.
The app is free with no in-app purchases.

**3. Will the data be shared with any third parties?**

No. No data is shared with anyone, because no data leaves the device. The app contains no
networking code whatsoever — no URLSession, no WKWebView, no sockets, no ATS exception domains.
Its `PrivacyInfo.xcprivacy` declares `NSPrivacyTracking = false`, an empty
`NSPrivacyTrackingDomains`, and an empty `NSPrivacyCollectedDataTypes`. The source is public, so
the claim is checkable rather than promised.

**4. Is the app collecting any user or device data for any other purpose?**

No data is collected in the App Store sense — nothing is transmitted off the device or linked to
an identity. Everything the app knows is written to a single JSON file in its own App Group
container, readable only by the app and its two Screen Time extensions:

- the length and outcome of past sessions,
- the identifier and factory UID of the user's paired NFC tag, plus a free-text note the user
  writes about where they leave it,
- whether the tag or Face ID is the unlock method,
- the opaque `FamilyActivitySelection` blob that Apple's Screen Time framework returns for the
  apps the user chose to block.

Two notes on that last point and on Face ID:

- Apple hands us `ApplicationToken` values, which are opaque. The app stores those bytes and
  never decodes them; it is structurally unable to know which apps the user blocked, and no code
  path exists that could report them.
- Face ID is invoked through LocalAuthentication and returns only a pass/fail. No biometric data
  is read, stored or transmitted.

The only other data touched is the app's own `UserDefaults`, declared in the privacy manifest
under CA92.1. Deleting the app deletes the file and every restriction the app applied.

The full policy is at [Privacy Policy URL], and its source is `store/PRIVACY.md` in the public
repository.

Thank you.
