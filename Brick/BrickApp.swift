import BrickKit
import SwiftUI

@main
struct BrickApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Theme.accent)
        }
    }
}

@MainActor
@Observable
final class AppModel {
    let controller: BrickController
    let authorization: AuthorizationProviding

    var isAuthorized: Bool
    var scanning = false
    var alert: AlertContent?

    init(
        controller: BrickController? = nil,
        authorization: AuthorizationProviding? = nil
    ) {
        let authorization = authorization ?? AppEnvironment.makeAuthorization()
        self.controller = controller ?? AppEnvironment.makeController()
        self.authorization = authorization
        self.isAuthorized = authorization.isAuthorized
    }

    var needsSetup: Bool {
        !isAuthorized || !controller.state.isPaired || controller.state.blocklist.isEmpty
    }

    func requestAuthorization() async {
        do {
            try await authorization.request()
            isAuthorized = authorization.isAuthorized
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
