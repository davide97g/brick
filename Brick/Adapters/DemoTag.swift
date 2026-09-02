import BrickKit
import Foundation
import Observation

/// App Review has no brick. Pairing and ending both require an NFC tag, so
/// without a way in, a reviewer can't see a single session — which is a
/// rejection, not a bad review.
///
/// Entering the access code in Settings swaps the NFC reader for the same
/// stand-in the Simulator uses. It is deliberately visible in the UI while it's
/// on: an app that quietly stops needing the object would be lying about what
/// it is.
@MainActor
@Observable
final class DemoTagAccess {
    /// Published in `store/METADATA.md` as the App Review demo credential. It
    /// being public costs nothing: anyone who wants out of a session can
    /// already delete the app, and that's stated in onboarding.
    static let code = "BRICK-REVIEW"

    private static let key = "review.demoTag"

    /// Readable from any thread: the tag adapters consult it per scan, off the
    /// main actor. `UserDefaults` is the shared truth, the property below is
    /// the observable mirror the UI watches.
    nonisolated static var isEnabledNow: Bool { UserDefaults.standard.bool(forKey: key) }

    private(set) var isEnabled: Bool

    init() {
        isEnabled = Self.isEnabledNow
    }

    /// - Returns: whether the code was accepted.
    @discardableResult
    func enable(withCode entered: String) -> Bool {
        let normalised = entered.trimmingCharacters(in: .whitespaces).uppercased()
        guard normalised == Self.code else { return false }
        set(true)
        return true
    }

    func disable() { set(false) }

    private func set(_ newValue: Bool) {
        isEnabled = newValue
        UserDefaults.standard.set(newValue, forKey: Self.key)
    }
}
