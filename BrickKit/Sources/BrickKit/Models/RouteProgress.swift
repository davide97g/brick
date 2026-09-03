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

/// Where the walk stands right now, resolved to the tags themselves.
///
/// The app and the shield both describe the way out, from the same state file
/// and the same rules, so they cannot drift apart.
public struct RouteStatus: Equatable, Sendable {
    public let steps: [BrickTag]
    public let walked: Int

    public init(steps: [BrickTag], walked: Int) {
        self.steps = steps
        self.walked = walked
    }

    public var isSingleTap: Bool { steps.count <= 1 }
    public var remaining: Int { max(0, steps.count - walked) }

    /// The tag to go to. The last one when the walk is somehow past its end,
    /// so this is never nil for a route that has steps.
    public var next: BrickTag? {
        guard !steps.isEmpty else { return nil }
        return steps[min(walked, steps.count - 1)]
    }

    /// "2 taps left. Next: hallway sticker, by the front door."
    public var description: String? {
        guard let next else { return nil }
        guard !isSingleTap else { return next.whereItIs }
        let taps = "\(remaining) tap\(remaining == 1 ? "" : "s") left."
        return next.placeNote.isEmpty
            ? "\(taps) Next: \(next.displayName)."
            : "\(taps) Next: \(next.displayName), \(next.placeNote)."
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
