import BrickKit
import Foundation

/// Composition root. The only file that knows which adapters are real.
enum AppEnvironment {
    static func makeStore() -> StateStore {
        if let shared = FileStateStore.shared() { return shared }
        // No App Group container (Simulator without the entitlement): fall back
        // to the app's own Documents directory so the app still runs.
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return FileStateStore(url: documents.appendingPathComponent(BrickIdentifiers.stateFilename))
    }

    static func makeAuthorization() -> AuthorizationProviding {
        #if targetEnvironment(simulator)
        PretendAuthorization()
        #else
        ScreenTimeAuthorization()
        #endif
    }

    @MainActor
    static func makeController() -> BrickController {
        #if targetEnvironment(simulator)
        BrickController(
            store: makeStore(),
            shielding: PretendShielding(),
            scheduler: PretendScheduler(),
            tagReader: PretendTagReader(),
            tagWriter: PretendTagWriter(),
            biometrics: PretendBiometrics(),
            notifier: UserNotificationsNotifier()
        )
        #else
        // Real NFC, unless App Review has entered the demo code — then the
        // Simulator stand-ins, which are the only way to review an app whose
        // every entry point is a physical tag.
        BrickController(
            store: makeStore(),
            shielding: ManagedSettingsShielding(),
            scheduler: DeviceActivityScheduler(),
            tagReader: SwitchingTagReader(
                primary: CoreNFCTagReader(),
                alternate: PretendTagReader(),
                useAlternate: { DemoTagAccess.isEnabledNow }
            ),
            tagWriter: SwitchingTagWriter(
                primary: CoreNFCTagWriter(),
                alternate: PretendTagWriter(),
                useAlternate: { DemoTagAccess.isEnabledNow }
            ),
            biometrics: SwitchingBiometrics(
                primary: LocalAuthenticationBiometrics(),
                alternate: PretendBiometrics(),
                useAlternate: { DemoTagAccess.isEnabledNow }
            ),
            notifier: UserNotificationsNotifier()
        )
        #endif
    }
}
