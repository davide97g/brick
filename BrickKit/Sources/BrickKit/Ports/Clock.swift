import Foundation

public protocol Clock: Sendable {
    var now: Date { get }
}

public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}

/// Manual clock so the duration rules can be tested without waiting.
public final class TestClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date

    public init(_ start: Date = Date(timeIntervalSince1970: 1_760_000_000)) { _now = start }

    public var now: Date {
        lock.lock(); defer { lock.unlock() }
        return _now
    }

    public func advance(by interval: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        _now = _now.addingTimeInterval(interval)
    }
}
