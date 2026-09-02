import Foundation

/// Picks between two readers at call time. It doesn't know which is which —
/// the composition root does, and hands both in.
public final class SwitchingTagReader: TagReading, @unchecked Sendable {
    private let primary: TagReading
    private let alternate: TagReading
    private let useAlternate: @Sendable () -> Bool

    public init(primary: TagReading, alternate: TagReading, useAlternate: @escaping @Sendable () -> Bool) {
        self.primary = primary
        self.alternate = alternate
        self.useAlternate = useAlternate
    }

    public func readTagUID() async throws -> String {
        try await (useAlternate() ? alternate : primary).readTagUID()
    }
}

public final class SwitchingTagWriter: TagWriting, @unchecked Sendable {
    private let primary: TagWriting
    private let alternate: TagWriting
    private let useAlternate: @Sendable () -> Bool

    public init(primary: TagWriting, alternate: TagWriting, useAlternate: @escaping @Sendable () -> Bool) {
        self.primary = primary
        self.alternate = alternate
        self.useAlternate = useAlternate
    }

    public func writeIdentity(_ id: UUID) async throws -> String {
        try await (useAlternate() ? alternate : primary).writeIdentity(id)
    }
}
