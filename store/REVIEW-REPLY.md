# Reply to App Review — 1.0 (2), 2.5.1 automated Family Controls rejection

Sent: (not yet sent)

---

Hello,

The Family Controls entitlement is present in this build, in the app and in both of its
Screen Time extensions.

Our team was approved for Family Controls (Distribution) on 2 September 2026 (requests
NSBFJ2S8J7 and 5DXKNVZG8K). All three App IDs show Family Controls as Assigned under Additional
Capabilities:

- com.davideghiotto.brick
- com.davideghiotto.brick.monitor
- com.davideghiotto.brick.shield

Build 1.0 (2) was signed with the App Store distribution profile for each of those App IDs, all
issued after the approval, and each profile carries `com.apple.developer.family-controls`.
Inspecting the signed binaries in the uploaded build confirms the same:

- Brick.app — `com.apple.developer.family-controls` = true
- BrickMonitor.appex — `com.apple.developer.family-controls` = true
- BrickShield.appex — `com.apple.developer.family-controls` = true

Each is signed for distribution (`get-task-allow` = false, `beta-reports-active` = true).

The automated check appears to have reached the wrong conclusion. Could you re-run it against
this build, or tell us what it found so we can correct it? We are happy to upload a new build
if that helps, but we have not been able to find anything to change.

Thank you.
