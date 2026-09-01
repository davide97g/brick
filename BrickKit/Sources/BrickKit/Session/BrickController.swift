import Foundation
import Observation

/// Orchestrates the ports around `SessionEngine`. Owns no rules of its own.
@MainActor
@Observable
public final class BrickController {
    public private(set) var state: BrickState
    public private(set) var lastError: BrickError?

    private let store: StateStore
    private let shielding: Shielding
    private let scheduler: SessionScheduling
    private let tagReader: TagReading
    private let clock: Clock

    public init(
        store: StateStore,
        shielding: Shielding,
        scheduler: SessionScheduling,
        tagReader: TagReading,
        clock: Clock = SystemClock()
    ) {
        self.store = store
        self.shielding = shielding
        self.scheduler = scheduler
        self.tagReader = tagReader
        self.clock = clock
        self.state = store.load()
    }

    public var now: Date { clock.now }

    // MARK: Derived state for the UI

    public var activeSession: Session? { state.activeSession }

    public var remaining: TimeInterval {
        state.activeSession?.remaining(at: now) ?? 0
    }

    public var canEndByTap: Bool {
        guard let session = state.activeSession, session.isActive else { return false }
        return now >= session.earliestTapExit(minimumDuration: state.blocklist.minimumDuration)
    }

    public var tapExitOpensAt: Date? {
        state.activeSession?.earliestTapExit(minimumDuration: state.blocklist.minimumDuration)
    }

    public var emergencyRemaining: Int { state.emergency.remainingAllowance(at: now) }

    // MARK: Lifecycle

    /// Call on every foreground. Covers a missed monitor callback: the shield
    /// must never outlive its planned end.
    public func reconcile() {
        state = store.load()
        guard SessionEngine.needsExpiry(state: state, now: now) else { return }
        let plannedEnd = state.activeSession?.plannedEnd ?? now
        shielding.clear()
        scheduler.cancelScheduledEnd()
        persist { SessionEngine.close(&$0, reason: .scheduled, at: plannedEnd) }
    }

    // MARK: Pairing

    public func pairBrick(placeNote: String = "") async throws {
        guard state.tag == nil else { throw BrickError.alreadyPaired }
        let uid = try await tagReader.readTagUID()
        persist { $0.tag = BrickTag(uid: uid, placeNote: placeNote, pairedAt: self.now) }
    }

    public func updatePlaceNote(_ note: String) {
        persist { $0.tag?.placeNote = note }
    }

    /// Only allowed while nothing is running — otherwise unpairing would be a
    /// free unlock.
    public func unpairBrick() throws {
        guard state.activeSession?.isActive != true else { throw BrickError.sessionAlreadyActive }
        persist { $0.tag = nil }
    }

    // MARK: Blocklist

    public func updateBlocklist(
        selectionData: Data?,
        appCount: Int,
        categoryCount: Int,
        webDomainCount: Int
    ) {
        persist {
            $0.blocklist.selectionData = selectionData
            $0.blocklist.appCount = appCount
            $0.blocklist.categoryCount = categoryCount
            $0.blocklist.webDomainCount = webDomainCount
        }
    }

    public func updateDurations(default defaultDuration: TimeInterval, minimum: TimeInterval) {
        persist {
            $0.blocklist.defaultDuration = max(.brickMinimumSession, defaultDuration)
            $0.blocklist.minimumDuration = max(0, minimum)
        }
    }

    // MARK: Sessions

    /// Starting requires the brick: you scan it, then you walk away from it.
    public func startSessionByTap(duration: TimeInterval) async throws {
        guard let tag = state.tag else { throw BrickError.notPaired }
        let uid = try await tagReader.readTagUID()
        guard tag.uid.caseInsensitiveCompare(uid) == .orderedSame else {
            throw record(BrickError.wrongTag(scanned: uid))
        }
        try startSession(duration: duration)
    }

    public func startSession(duration: TimeInterval) throws {
        let session: Session
        do {
            session = try SessionEngine.validateStart(state: state, duration: duration, now: now)
        } catch let error as BrickError {
            throw record(error)
        }
        try shielding.apply(selectionData: state.blocklist.selectionData)
        do {
            try scheduler.scheduleEnd(of: session)
        } catch {
            // Without a scheduled end the brick becomes a trap, so refuse to
            // start rather than leave the user relying on the app being opened.
            shielding.clear()
            throw error
        }
        persist { $0.activeSession = session }
        lastError = nil
    }

    public func endSessionByTap() async throws {
        guard state.tag != nil else { throw record(.notPaired) }
        let uid = try await tagReader.readTagUID()
        do {
            _ = try SessionEngine.validateTapEnd(state: state, scannedUID: uid, now: now)
        } catch let error as BrickError {
            throw record(error)
        }
        finish(reason: .tappedBrick)
    }

    public func endSessionByEmergency() throws {
        do {
            _ = try SessionEngine.validateEmergency(state: state, now: now)
        } catch let error as BrickError {
            throw record(error)
        }
        finish(reason: .emergency)
    }

    // MARK: Plumbing

    private func finish(reason: EndReason) {
        shielding.clear()
        scheduler.cancelScheduledEnd()
        let timestamp = now
        persist { SessionEngine.close(&$0, reason: reason, at: timestamp) }
        lastError = nil
    }

    private func persist(_ body: (inout BrickState) -> Void) {
        var updated = store.load()
        body(&updated)
        store.save(updated)
        state = updated
    }

    @discardableResult
    private func record(_ error: BrickError) -> BrickError {
        lastError = error
        return error
    }
}
