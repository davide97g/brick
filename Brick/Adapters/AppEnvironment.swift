import BrickKit
import Foundation

/// Composition root. The only file that knows which adapters are real.
enum AppEnvironment {
    static let appGroupID = "group.com.davideghiotto.brick"

    static func makeStore() -> StateStore {
        if let shared = FileStateStore(appGroupID: appGroupID) { return shared }
        // No App Group container (Simulator without the entitlement): fall back
        // to the app's own Documents directory so the app still runs.
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return FileStateStore(url: documents.appendingPathComponent("brick-state.json"))
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
            tagReader: PretendTagReader()
        )
        #else
        BrickController(
            store: makeStore(),
            shielding: ManagedSettingsShielding(),
            scheduler: DeviceActivityScheduler(),
            tagReader: CoreNFCTagReader()
        )
        #endif
    }
}
