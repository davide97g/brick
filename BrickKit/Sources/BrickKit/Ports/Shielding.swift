import Foundation

/// Applies and clears the actual restrictions.
///
/// The real adapter wraps `ManagedSettingsStore` and lives in the app target,
/// because only it can import ManagedSettings. Keeping it behind a port is what
/// lets the session logic run in the Simulator and in unit tests, where
/// Family Controls authorization is unavailable.
public protocol Shielding: AnyObject, Sendable {
    /// - Parameter selectionData: an encoded `FamilyActivitySelection`.
    func apply(selectionData: Data?) throws
    func clear()
}

public final class RecordingShielding: Shielding, @unchecked Sendable {
    public enum Event: Equatable, Sendable {
        case applied(Data?)
        case cleared
    }

    private let lock = NSLock()
    private var _events: [Event] = []

    public init() {}

    public var events: [Event] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }

    public var isShielded: Bool {
        if case .applied = events.last { return true }
        return false
    }

    public func apply(selectionData: Data?) throws {
        lock.lock(); defer { lock.unlock() }
        _events.append(.applied(selectionData))
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        _events.append(.cleared)
    }
}
