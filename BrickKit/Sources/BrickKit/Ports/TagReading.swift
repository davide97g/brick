import Foundation

/// Reads the brick's NFC tag UID in a foreground Core NFC session.
///
/// Under the leave-behind model the phone is always in hand at the brick for
/// both start and end, so a foreground session costs nothing — and it avoids
/// Universal Links, Associated Domains and any hosted file.
public protocol TagReading: AnyObject, Sendable {
    /// - Returns: the tag UID as uppercase hex.
    func readTagUID() async throws -> String
}

public final class StubTagReader: TagReading, @unchecked Sendable {
    private let lock = NSLock()
    private var _result: Result<String, Error>

    public init(uid: String = "04A1B2C3D4E580") { _result = .success(uid) }

    public func stub(_ result: Result<String, Error>) {
        lock.lock(); defer { lock.unlock() }
        _result = result
    }

    public func readTagUID() async throws -> String {
        try currentResult().get()
    }

    private func currentResult() -> Result<String, Error> {
        lock.lock(); defer { lock.unlock() }
        return _result
    }
}
