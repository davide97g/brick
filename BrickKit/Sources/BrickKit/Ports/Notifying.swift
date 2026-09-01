import Foundation

/// Local notifications around a session.
///
/// These are scheduled up front rather than fired live: a notification queued
/// at start still arrives if the app is killed and the monitor extension never
/// runs, which matters when the brick is deliberately out of reach.
public protocol Notifying: AnyObject, Sendable {
    func requestPermission() async
    func scheduleSessionNotifications(for session: Session)
    func cancelSessionNotifications()
}

public final class RecordingNotifier: Notifying, @unchecked Sendable {
    private let lock = NSLock()
    private var _scheduled: [Session] = []
    private var _cancelCount = 0

    public init() {}

    public var scheduled: [Session] {
        lock.lock(); defer { lock.unlock() }
        return _scheduled
    }

    public var cancelCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _cancelCount
    }

    public func requestPermission() async {}

    public func scheduleSessionNotifications(for session: Session) {
        lock.lock(); defer { lock.unlock() }
        _scheduled.append(session)
    }

    public func cancelSessionNotifications() {
        lock.lock(); defer { lock.unlock() }
        _cancelCount += 1
    }
}

/// Used where notifications aren't wanted, such as inside an extension.
public final class SilentNotifier: Notifying, @unchecked Sendable {
    public init() {}
    public func requestPermission() async {}
    public func scheduleSessionNotifications(for session: Session) {}
    public func cancelSessionNotifications() {}
}
