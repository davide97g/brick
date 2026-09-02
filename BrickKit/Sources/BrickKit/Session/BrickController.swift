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
    private let tagWriter: TagWriting?
    private let biometrics: BiometricAuthenticating
    private let notifier: Notifying
    private let clock: Clock

    public init(
        store: StateStore,
        shielding: Shielding,
        scheduler: SessionScheduling,
        tagReader: TagReading,
        tagWriter: TagWriting? = nil,
        biometrics: BiometricAuthenticating = StubBiometrics(),
        notifier: Notifying = SilentNotifier(),
        clock: Clock = SystemClock()
    ) {
        self.store = store
        self.shielding = shielding
        self.scheduler = scheduler
        self.tagReader = tagReader
        self.tagWriter = tagWriter
        self.biometrics = biometrics
        self.notifier = notifier
        self.clock = clock
        self.state = store.load()
    }

    public var now: Date { clock.now }

    // MARK: Derived state for the UI

    public var activeSession: Session? { state.activeSession }

    public var remaining: TimeInterval {
        state.activeSession?.remaining(at: now) ?? 0
    }

    /// Whether the key — brick or face — works yet.
    public var canEndWithKey: Bool {
        guard let session = state.activeSession, session.isActive else { return false }
        return now >= session.earliestTapExit(minimumDuration: state.blocklist.minimumDuration)
    }

    public var keyExitOpensAt: Date? {
        state.activeSession?.earliestTapExit(minimumDuration: state.blocklist.minimumDuration)
    }

    public var emergencyRemaining: Int { state.emergency.remainingAllowance(at: now) }

    public var unlockMethod: UnlockMethod { state.unlock }

    /// Whether biometrics can be offered as a stand-in for a brick at all.
    public var biometricsAvailable: Bool { biometrics.isAvailable }

    /// "Face ID" / "Touch ID". Copy must name what the phone will actually show.
    public var biometricName: String { biometrics.name }

    /// Swapping the key mid-session would be a free unlock, and biometrics
    /// that aren't enrolled can't be offered at all.
    public var canSwitchKey: Bool {
        activeSession?.isActive != true && biometrics.isAvailable
    }

    /// What the user has to reach for to get out. The shield says the same
    /// thing, from the state file alone.
    public var keyDescription: String {
        switch state.unlock {
        case .brick: return state.tag?.whereItIs ?? "Your brick has the way out."
        case .biometric: return "No brick. \(biometrics.name) is the way out."
        }
    }

    // MARK: Lifecycle

    /// Call on every foreground. Covers a missed monitor callback: the shield
    /// must never outlive its planned end.
    public func reconcile() {
        state = store.load()
        guard SessionEngine.needsExpiry(state: state, now: now) else { return }
        let plannedEnd = state.activeSession?.plannedEnd ?? now
        shielding.clear()
        scheduler.cancelScheduledEnd()
        notifier.cancelSessionNotifications()
        persist { SessionEngine.close(&$0, reason: .scheduled, at: plannedEnd) }
    }

    public func requestNotificationPermission() async {
        await notifier.requestPermission()
    }

    /// Re-applies the shield for a session that is still running.
    ///
    /// Screen Time authorization can be revoked from Settings, which silently
    /// invalidates the stored tokens and leaves a session that blocks nothing.
    /// Re-applying on every foreground repairs that as soon as access is back.
    ///
    /// - Returns: `false` when the shield could not be applied, so the caller
    ///   can say so rather than let the user believe they're blocked.
    @discardableResult
    public func reapplyShieldIfNeeded() -> Bool {
        guard let session = state.activeSession, session.isActive else { return true }
        do {
            try shielding.apply(selectionData: state.blocklist.selectionData)
            return true
        } catch {
            return false
        }
    }

    // MARK: Pairing

    /// Writes an identity onto the tag when a writer is available, and falls
    /// back to a plain read otherwise — a tag that is already locked, or a
    /// build without write support, still pairs on its UID.
    public func pairBrick(placeNote: String = "") async throws {
        guard state.tag == nil else { throw BrickError.alreadyPaired }
        let identity = UUID()
        let uid: String
        if let tagWriter {
            do {
                uid = try await tagWriter.writeIdentity(identity)
            } catch {
                uid = try await tagReader.readTagUID()
            }
        } else {
            uid = try await tagReader.readTagUID()
        }
        persist {
            $0.tag = BrickTag(uid: uid, ndefID: identity, placeNote: placeNote, pairedAt: self.now)
            $0.unlock = .brick
        }
    }

    // MARK: Choosing the key

    /// Switches to biometrics — the path for a user who has no brick yet.
    ///
    /// The prompt is run here rather than trusted later: a key that turns out
    /// not to work is discovered now, not at the end of a four-hour session.
    public func useBiometricUnlock() async throws {
        guard state.activeSession?.isActive != true else { throw record(.sessionAlreadyActive) }
        guard biometrics.isAvailable else { throw record(.biometricUnavailable) }
        try await biometrics.authenticate(reason: "Use \(biometrics.name) to start and end sessions.")
        persist { $0.unlock = .biometric }
        lastError = nil
    }

    /// Switches back to the brick. The tag survives the detour, so a user who
    /// tried biometrics and printed a brick later doesn't re-pair.
    public func useBrickUnlock() throws {
        guard state.activeSession?.isActive != true else { throw record(.sessionAlreadyActive) }
        persist { $0.unlock = .brick }
        lastError = nil
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

    /// Starting goes through whichever key is configured.
    public func startSessionUsingKey(duration: TimeInterval) async throws {
        switch state.unlock {
        case .brick:
            try await startSessionByTap(duration: duration)
        case .biometric:
            try await biometrics.authenticate(reason: "Start a session.")
            try startSession(duration: duration)
        }
    }

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
        notifier.scheduleSessionNotifications(for: session)
        persist { $0.activeSession = session }
        lastError = nil
    }

    public func endSessionUsingKey() async throws {
        switch state.unlock {
        case .brick:
            try await endSessionByTap()
        case .biometric:
            try await endSessionByBiometrics()
        }
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

    /// The gate is checked before the prompt, so a refusal costs nothing, and
    /// again after it, because time passes while the sheet is up.
    public func endSessionByBiometrics() async throws {
        do {
            _ = try SessionEngine.validateEnd(state: state, now: now)
        } catch let error as BrickError {
            throw record(error)
        }
        try await biometrics.authenticate(reason: "End this session.")
        do {
            _ = try SessionEngine.validateEnd(state: state, now: now)
        } catch let error as BrickError {
            throw record(error)
        }
        finish(reason: .biometrics)
    }

    /// Spending an emergency unlock still goes through the biometric prompt
    /// when that is the key: the quota is what costs something, but a phone
    /// left on a table shouldn't be able to spend it.
    public func endSessionByEmergency() async throws {
        do {
            _ = try SessionEngine.validateEmergency(state: state, now: now)
        } catch let error as BrickError {
            throw record(error)
        }
        if state.unlock == .biometric {
            try await biometrics.authenticate(reason: "Spend an emergency unlock.")
            do {
                _ = try SessionEngine.validateEmergency(state: state, now: now)
            } catch let error as BrickError {
                throw record(error)
            }
        }
        finish(reason: .emergency)
    }

    // MARK: Plumbing

    private func finish(reason: EndReason) {
        shielding.clear()
        scheduler.cancelScheduledEnd()
        notifier.cancelSessionNotifications()
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
