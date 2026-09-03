import Foundation

/// The product's rules, as pure functions over state and a timestamp.
///
/// Every decision that makes the brick a commitment rather than a toggle lives
/// here, deliberately free of Apple frameworks so it can be tested exhaustively
/// on any platform.
public enum SessionEngine {

    // MARK: Profiles

    /// The rules a session runs under. Sessions filed before profiles existed
    /// carry no `profileID` and fall back to the first one.
    public static func profile(for session: Session, in state: BrickState) -> BlockProfile {
        state.profile(id: session.profileID) ?? state.profiles.first ?? BlockProfile()
    }

    /// The profile a tap on this tag starts.
    public static func profile(forTagUID uid: String, in state: BrickState) -> BlockProfile? {
        guard let tag = state.tag(withUID: uid) else { return nil }
        return state.profile(id: tag.profileID) ?? state.profiles.first
    }

    // MARK: Starting

    public static func validateStart(
        state: BrickState,
        duration: TimeInterval,
        now: Date
    ) throws -> Session {
        try validateStart(
            state: state,
            profile: state.profiles.first ?? BlockProfile(),
            startedByTag: nil,
            duration: duration,
            now: now
        )
    }

    /// The tag decides which occasion this is: the bedside sticker starts the
    /// night profile, the desk slab starts deep work.
    public static func validateStartByTap(
        state: BrickState,
        scannedUID: String,
        duration: TimeInterval,
        now: Date
    ) throws -> Session {
        guard let tag = state.tag(withUID: scannedUID) else {
            throw BrickError.wrongTag(scanned: scannedUID)
        }
        guard let profile = state.profile(id: tag.profileID) ?? state.profiles.first else {
            throw BrickError.emptyBlocklist
        }
        return try validateStart(
            state: state,
            profile: profile,
            startedByTag: tag.uid,
            duration: duration,
            now: now
        )
    }

    public static func validateStart(
        state: BrickState,
        profile: BlockProfile,
        startedByTag: String?,
        duration: TimeInterval,
        now: Date
    ) throws -> Session {
        guard state.hasKey else { throw BrickError.notPaired }
        guard !profile.isEmpty else { throw BrickError.emptyBlocklist }
        guard state.activeSession?.isActive != true else { throw BrickError.sessionAlreadyActive }
        guard duration >= .brickMinimumSession else {
            throw BrickError.durationTooShort(minimum: .brickMinimumSession)
        }
        return Session(
            startedAt: now,
            plannedEnd: now.addingTimeInterval(duration),
            kind: .block,
            profileID: profile.id,
            startedByTag: startedByTag
        )
    }

    // MARK: Ending with the key

    /// The gate: whichever key the user has, it only works once the minimum
    /// duration has elapsed. This is what turns a switch into a contract, and
    /// it is the rule that survives unchanged when the key is a face rather
    /// than an object, or three objects rather than one.
    public static func validateEnd(state: BrickState, now: Date) throws -> Session {
        guard let session = state.activeSession, session.isActive else {
            throw BrickError.noActiveSession
        }
        let minimum = profile(for: session, in: state).minimumDuration
        let exitOpens = session.earliestTapExit(minimumDuration: minimum)
        guard now >= exitOpens else { throw BrickError.tooEarlyToEnd(availableAt: exitOpens) }
        return session
    }

    // MARK: Exit routes

    /// The tags that have to be tapped, in order, to end this session early.
    ///
    /// A profile that names no route exits by the tag that started it — the
    /// original one-brick product, expressed as a route of length one.
    public static func exitRoute(for session: Session, in state: BrickState) -> [String] {
        let route = profile(for: session, in: state).exitRoute
        if !route.isEmpty { return route }
        if let uid = session.startedByTag { return [uid] }
        if let first = state.tags.first?.uid { return [first] }
        return []
    }

    /// The walk as it stands: the tags, in order, and how many are behind you.
    public static func routeStatus(state: BrickState, now: Date) -> RouteStatus? {
        guard let session = state.activeSession, session.isActive else { return nil }
        let steps = exitRoute(for: session, in: state).compactMap { state.tag(withUID: $0) }
        guard !steps.isEmpty else { return nil }
        let window = profile(for: session, in: state).routeWindow
        return RouteStatus(
            steps: steps,
            walked: stepsAlreadyWalked(state: state, session: session, window: window, now: now)
        )
    }

    /// A tag tap against the exit route.
    ///
    /// Order matters and is the rule: a tag that was never paired is refused
    /// on identity, which is true whatever the clock says; everything about
    /// the *exit* — including how far along the walk is — is behind the gate,
    /// so walking early earns nothing.
    public static func validateRouteTap(
        state: BrickState,
        scannedUID: String,
        now: Date
    ) throws -> RouteOutcome {
        guard let session = state.activeSession, session.isActive else {
            throw BrickError.noActiveSession
        }
        let route = exitRoute(for: session, in: state)
        guard let firstStep = route.first else { throw BrickError.notPaired }
        guard state.tag(withUID: scannedUID) != nil else {
            return .wrongTag(scanned: scannedUID, expectedUID: firstStep)
        }

        _ = try validateEnd(state: state, now: now)

        let profile = profile(for: session, in: state)
        let done = stepsAlreadyWalked(state: state, session: session, window: profile.routeWindow, now: now)
        let expected = route[min(done, route.count - 1)]
        guard expected.caseInsensitiveCompare(scannedUID) == .orderedSame else {
            return .wrongTag(scanned: scannedUID, expectedUID: expected)
        }

        let walked = done + 1
        guard walked < route.count else { return .completed(session) }
        return .advanced(
            progress: RouteProgress(sessionID: session.id, stepsDone: walked, lastTapAt: now),
            remaining: route.count - walked,
            nextUID: route[walked]
        )
    }

    /// Progress that belongs to another session, or to a walk that was
    /// abandoned, counts for nothing.
    private static func stepsAlreadyWalked(
        state: BrickState,
        session: Session,
        window: TimeInterval,
        now: Date
    ) -> Int {
        guard let progress = state.routeProgress,
              progress.sessionID == session.id,
              !progress.isStale(window: window, at: now)
        else { return 0 }
        return max(0, progress.stepsDone)
    }

    /// Records what the tap did. A wrong tag costs the whole walk: there is no
    /// credit for the steps taken before it.
    public static func apply(_ outcome: RouteOutcome, to state: inout BrickState) {
        switch outcome {
        case .advanced(let progress, _, _):
            state.routeProgress = progress
        case .completed, .wrongTag:
            state.routeProgress = nil
        }
    }

    /// The brick path for a one-tag exit: the scanned tag has to be *the*
    /// brick, then the gate. A profile with a longer route refuses here and
    /// says how much of the walk is left.
    public static func validateTapEnd(
        state: BrickState,
        scannedUID: String,
        now: Date
    ) throws -> Session {
        guard !state.tags.isEmpty else { throw BrickError.notPaired }
        switch try validateRouteTap(state: state, scannedUID: scannedUID, now: now) {
        case .completed(let session):
            return session
        case .advanced(_, let remaining, let nextUID):
            throw BrickError.routeIncomplete(
                remaining: remaining,
                next: state.tag(withUID: nextUID)?.displayName ?? "the next brick"
            )
        case .wrongTag(let scanned, _):
            throw BrickError.wrongTag(scanned: scanned)
        }
    }

    // MARK: Ending by emergency

    public static func validateEmergency(state: BrickState, now: Date) throws -> Session {
        guard let session = state.activeSession, session.isActive else {
            throw BrickError.noActiveSession
        }
        guard state.emergency.hasAllowance(at: now) else {
            throw BrickError.emergencyQuotaExhausted(
                replenishesAt: state.emergency.nextReplenishment(at: now)
            )
        }
        return session
    }

    // MARK: Reconciliation

    /// True when the stored state claims a session is running but its planned
    /// end has already passed — i.e. the DeviceActivity monitor never fired, or
    /// the device was off. The app checks this on every foreground so a missed
    /// extension callback can never strand the user.
    public static func needsExpiry(state: BrickState, now: Date) -> Bool {
        guard let session = state.activeSession, session.isActive else { return false }
        return now >= session.plannedEnd
    }

    // MARK: Applying an end

    /// Closes the active session and files it in history. Idempotent.
    public static func close(
        _ state: inout BrickState,
        reason: EndReason,
        at now: Date
    ) {
        guard var session = state.activeSession, session.isActive else { return }
        session.endedAt = now
        session.endReason = reason
        state.activeSession = nil
        state.routeProgress = nil
        state.history.append(session)
        if state.history.count > BrickState.historyLimit {
            state.history.removeFirst(state.history.count - BrickState.historyLimit)
        }
        if reason == .emergency { state.emergency.record(at: now) }
    }
}
