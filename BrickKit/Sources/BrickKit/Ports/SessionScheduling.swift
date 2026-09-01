import Foundation

/// Schedules the automatic end of a session.
///
/// The real adapter wraps `DeviceActivityCenter`; the monitor extension is what
/// actually clears the shield when the app is not running. This is the piece
/// that makes the leave-behind model safe rather than a trap.
public protocol SessionScheduling: AnyObject, Sendable {
    func scheduleEnd(of session: Session) throws
    func cancelScheduledEnd()
}

public final class RecordingScheduler: SessionScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var _scheduled: Session?
    private var _cancelCount = 0

    public init() {}

    public var scheduled: Session? {
        lock.lock(); defer { lock.unlock() }
        return _scheduled
    }

    public var cancelCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _cancelCount
    }

    public func scheduleEnd(of session: Session) throws {
        lock.lock(); defer { lock.unlock() }
        _scheduled = session
    }

    public func cancelScheduledEnd() {
        lock.lock(); defer { lock.unlock() }
        _scheduled = nil
        _cancelCount += 1
    }
}
