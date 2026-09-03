import Foundation

/// A partly-walked exit route.
///
/// Kept in shared state rather than in memory, because the walk outlasts the
/// app: the phone gets pocketed between taps, and the app is killed as often
/// as not.
public struct RouteProgress: Codable, Equatable, Sendable {
    public var sessionID: UUID
    public var stepsDone: Int
    public var lastTapAt: Date

    public init(sessionID: UUID, stepsDone: Int, lastTapAt: Date) {
        self.sessionID = sessionID
        self.stepsDone = stepsDone
        self.lastTapAt = lastTapAt
    }

    /// Progress from a walk that was abandoned. Counting it would turn a route
    /// into a set of errands run over days, which is not a cost at all.
    public func isStale(window: TimeInterval, at now: Date) -> Bool {
        now.timeIntervalSince(lastTapAt) > window
    }
}

/// What a tag tap did to an exit route.
///
/// A wrong tag is an outcome rather than a thrown error because it has a
/// consequence — the walk resets — and that consequence is a rule, so it
/// belongs in the engine with the rest of them.
public enum RouteOutcome: Equatable, Sendable {
    /// One step down, `remaining` to go, and where to go next.
    case advanced(progress: RouteProgress, remaining: Int, nextUID: String)
    /// The last step. The caller closes the session.
    case completed(Session)
    /// Not the tag the route wanted. Progress goes back to zero.
    case wrongTag(scanned: String, expectedUID: String)
}
