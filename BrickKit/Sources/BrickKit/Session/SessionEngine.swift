import Foundation

/// The product's rules, as pure functions over state and a timestamp.
///
/// Every decision that makes the brick a commitment rather than a toggle lives
/// here, deliberately free of Apple frameworks so it can be tested exhaustively
/// on any platform.
public enum SessionEngine {

    // MARK: Starting

    public static func validateStart(
        state: BrickState,
        duration: TimeInterval,
        now: Date
    ) throws -> Session {
        guard state.isPaired else { throw BrickError.notPaired }
        guard !state.blocklist.isEmpty else { throw BrickError.emptyBlocklist }
        guard state.activeSession?.isActive != true else { throw BrickError.sessionAlreadyActive }
        guard duration >= .brickMinimumSession else {
            throw BrickError.durationTooShort(minimum: .brickMinimumSession)
        }
        return Session(startedAt: now, plannedEnd: now.addingTimeInterval(duration))
    }

    // MARK: Ending by tap

    /// The brick can only end a session once the minimum duration has elapsed.
    /// This is what turns a switch into a contract: returning to the object
    /// early buys you nothing.
    public static func validateTapEnd(
        state: BrickState,
        scannedUID: String,
        now: Date
    ) throws -> Session {
        guard let tag = state.tag else { throw BrickError.notPaired }
        guard tag.uid.caseInsensitiveCompare(scannedUID) == .orderedSame else {
            throw BrickError.wrongTag(scanned: scannedUID)
        }
        guard let session = state.activeSession, session.isActive else {
            throw BrickError.noActiveSession
        }
        let exitOpens = session.earliestTapExit(minimumDuration: state.blocklist.minimumDuration)
        guard now >= exitOpens else { throw BrickError.tooEarlyToEnd(availableAt: exitOpens) }
        return session
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
        state.history.append(session)
        if reason == .emergency { state.emergency.record(at: now) }
    }
}
