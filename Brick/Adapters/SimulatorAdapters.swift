import BrickKit
import Foundation

/// Stand-ins used on the Simulator, where Family Controls and Core NFC are both
/// unavailable. They keep the full flow — pairing, sessions, refusals, expiry —
/// exercisable without a device or a paid membership.
final class PretendShielding: Shielding, @unchecked Sendable {
    private let lock = NSLock()
    private var shielded = false

    var isShielded: Bool {
        lock.lock(); defer { lock.unlock() }
        return shielded
    }

    func apply(selectionData: Data?) throws {
        lock.lock(); defer { lock.unlock() }
        shielded = true
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        shielded = false
    }
}

/// No-op scheduler. The Simulator relies on the app's own reconcile-on-tick,
/// which is exactly the fallback path the device build also needs.
final class PretendScheduler: SessionScheduling, @unchecked Sendable {
    func scheduleEnd(of session: Session) throws {}
    func cancelScheduledEnd() {}
}

/// Always returns the same UID, so pairing then tapping matches.
final class PretendTagReader: TagReading, @unchecked Sendable {
    static let uid = "04A1B2C3D4E580"

    func readTagUID() async throws -> String {
        try? await Task.sleep(for: .milliseconds(600))
        return Self.uid
    }
}

/// Pretends to write and lock, returning the same UID the reader reports.
final class PretendTagWriter: TagWriting, @unchecked Sendable {
    func writeIdentity(_ id: UUID) async throws -> String {
        try? await Task.sleep(for: .milliseconds(900))
        return PretendTagReader.uid
    }
}

/// Always passes, after a beat long enough to look like a prompt. Face ID does
/// work in the Simulator, but only once enrolled by hand — the flow has to be
/// exercisable without that, and App Review needs the same way through on a
/// device with no enrolled face.
final class PretendBiometrics: BiometricAuthenticating, @unchecked Sendable {
    let isAvailable = true
    let name = "Face ID"

    func authenticate(reason: String) async throws {
        try? await Task.sleep(for: .milliseconds(500))
    }
}
