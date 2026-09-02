import BrickKit
import SwiftUI

@main
struct BrickApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}

@MainActor
@Observable
final class AppModel {
    let controller: BrickController
    let authorization: AuthorizationProviding
    /// App Review's way past the missing brick. See `DemoTagAccess`.
    let demoTag = DemoTagAccess()

    var isAuthorized: Bool
    var scanning = false

    #if DEBUG
    /// Screenshot hook: `-uiPreview start|settings|blocklist` opens that screen
    /// at launch, so screens behind a tap can be captured from the CLI.
    let uiPreview: String? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-uiPreview"),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }()
    #endif
    var alert: AlertContent?
    /// Set when a running session's shield could not be applied — the phone
    /// says it's blocked while nothing actually is.
    var enforcementBroken = false

    init(
        controller: BrickController? = nil,
        authorization: AuthorizationProviding? = nil
    ) {
        let authorization = authorization ?? AppEnvironment.makeAuthorization()
        self.controller = controller ?? AppEnvironment.makeController()
        self.authorization = authorization
        self.isAuthorized = authorization.isAuthorized
    }

    /// Screen Time access was revoked from Settings while a brick is paired.
    var authorizationLost: Bool {
        !isAuthorized && controller.state.hasKey
    }

    /// Called on every foreground: re-reads authorization and repairs the
    /// shield of a session that is still running.
    func refreshEnforcement() {
        isAuthorized = authorization.isAuthorized
        controller.reconcile()
        enforcementBroken = isAuthorized ? !controller.reapplyShieldIfNeeded() : false
    }

    var needsSetup: Bool {
        !isAuthorized || !controller.state.hasKey || controller.state.blocklist.isEmpty
    }

    /// Runs for the life of the scene: the first status a cold start reports is
    /// not to be trusted.
    func observeAuthorization() async {
        for await approved in authorization.statusUpdates() {
            guard approved != isAuthorized else { continue }
            isAuthorized = approved
            if approved { refreshEnforcement() }
        }
    }

    func requestAuthorization() async {
        do {
            try await authorization.request()
            isAuthorized = authorization.isAuthorized
            if isAuthorized { await controller.requestNotificationPermission() }
        } catch {
            present(error)
        }
    }

    /// Wraps every NFC-backed action: one place to own the scanning flag and
    /// turn a thrown rule into a plain, non-preachy message.
    func scan(_ operation: @escaping () async throws -> Void) async {
        scanning = true
        defer { scanning = false }
        do {
            try await operation()
        } catch {
            present(error)
        }
    }

    func present(_ error: Error) {
        if case BrickError.biometricCancelled = error {
            return  // User dismissed the Face ID sheet; not worth an alert.
        }
        if let brickError = error as? BrickError {
            alert = AlertContent(brickError, now: controller.now)
        } else if case CoreNFCFailureLike.cancelled = CoreNFCFailureLike(error) {
            return  // User dismissed the scan sheet; not worth an alert.
        } else {
            alert = AlertContent(
                title: "Something went wrong",
                message: error.localizedDescription
            )
        }
    }
}

struct AlertContent: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    init(_ error: BrickError, now: Date) {
        title = error.errorDescription ?? "Not now"
        switch error {
        case .tooEarlyToEnd(let availableAt):
            message = "\(Format.countdown(availableAt.timeIntervalSince(now))) left before the brick can end this."
        case .emergencyQuotaExhausted(let replenishesAt):
            if let replenishesAt {
                message = "Your next one comes back \(Format.day(replenishesAt))."
            } else {
                message = "They come back on a rolling seven-day window."
            }
        case .wrongTag:
            message = "That tag isn't the brick you paired."
        case .emptyBlocklist:
            message = "Choose the apps and sites this brick should block."
        default:
            message = ""
        }
    }
}

/// Small shim so `AppModel` doesn't need to import CoreNFC just to spot a
/// user-cancelled scan.
private enum CoreNFCFailureLike {
    case cancelled
    case other

    init(_ error: Error) {
        let text = error.localizedDescription.lowercased()
        self = text.contains("cancel") ? .cancelled : .other
    }
}
