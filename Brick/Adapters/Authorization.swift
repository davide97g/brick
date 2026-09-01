import BrickKit
import FamilyControls
import Foundation
import Observation

/// Screen Time authorization, behind a seam so the Simulator (where
/// Family Controls always fails) can still run the whole app.
protocol AuthorizationProviding: AnyObject, Sendable {
    var isAuthorized: Bool { get }
    func request() async throws
}

final class ScreenTimeAuthorization: AuthorizationProviding, @unchecked Sendable {
    var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// `.individual` is the self-binding case: the device owner restricting
    /// their own phone, no family sharing, no second device involved.
    func request() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }
}

final class PretendAuthorization: AuthorizationProviding, @unchecked Sendable {
    private static let key = "pretend.authorized"

    var isAuthorized: Bool {
        UserDefaults.standard.bool(forKey: Self.key)
    }

    func request() async throws {
        try? await Task.sleep(for: .milliseconds(400))
        UserDefaults.standard.set(true, forKey: Self.key)
    }
}
