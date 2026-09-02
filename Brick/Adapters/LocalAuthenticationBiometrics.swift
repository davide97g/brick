import BrickKit
import Foundation
import LocalAuthentication

/// Face ID / Touch ID, for the user who has no brick yet.
///
/// Deliberately `.deviceOwnerAuthenticationWithBiometrics` and not
/// `.deviceOwnerAuthentication`: falling back to the passcode would make the
/// key a secret the user can type while lying in bed, which is the exact
/// failure mode the whole product exists to avoid. No biometrics enrolled means
/// no biometric unlock — the brick stays the only way in.
final class LocalAuthenticationBiometrics: BiometricAuthenticating, @unchecked Sendable {
    private var freshContext: LAContext {
        let context = LAContext()
        // No grace period: a session that ends must cost a real face, not a
        // successful unlock from a minute ago.
        context.touchIDAuthenticationAllowableReuseDuration = 0
        return context
    }

    var isAvailable: Bool {
        freshContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var name: String {
        let context = freshContext
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometrics"
        }
    }

    func authenticate(reason: String) async throws {
        let context = freshContext
        do {
            let passed = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            guard passed else { throw BrickError.biometricFailed }
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                throw BrickError.biometricCancelled
            case .biometryNotAvailable, .biometryNotEnrolled, .biometryLockout:
                throw BrickError.biometricUnavailable
            default:
                throw BrickError.biometricFailed
            }
        }
    }
}
