import Foundation

/// Writes the brick's identity onto the tag at pairing time, then makes it
/// permanent.
///
/// The UID alone is enough to recognise the brick, so this is belt-and-braces:
/// it leaves a readable record on the object itself, and it keeps the door open
/// for a later Universal Link route without re-pairing. Locking afterwards
/// stops the tag being casually repurposed.
public protocol TagWriting: AnyObject, Sendable {
    /// - Returns: the UID of the tag written to, uppercase hex.
    func writeIdentity(_ id: UUID) async throws -> String
}

public final class RecordingTagWriter: TagWriting, @unchecked Sendable {
    private let lock = NSLock()
    private var _written: [UUID] = []
    private let uid: String

    public init(uid: String = "04A1B2C3D4E580") { self.uid = uid }

    public var written: [UUID] { lock.withLock { _written } }

    public func writeIdentity(_ id: UUID) async throws -> String {
        // Scoped locking: a bare lock()/unlock() pair is unavailable from an
        // async context under Swift 6.
        lock.withLock { _written.append(id) }
        return uid
    }
}
