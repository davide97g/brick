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

    /// The rules in force: the running session's profile, or the one a bare
    /// start would use.
    public var activeProfile: BlockProfile {
        if let session = state.activeSession {
            return SessionEngine.profile(for: session, in: state)
        }
        // A standing shield is the rules in force even with no session.
        return state.armedProfile ?? state.profiles.first ?? BlockProfile()
    }

    /// Whether the key — brick or face — works yet.
    public var canEndWithKey: Bool {
        guard let session = state.activeSession, session.isActive else { return false }
        return now >= session.earliestTapExit(minimumDuration: activeProfile.minimumDuration)
    }

    public var keyExitOpensAt: Date? {
        state.activeSession?.earliestTapExit(minimumDuration: activeProfile.minimumDuration)
    }

    /// The walk still owed before this session can end early.
    public var routeStatus: RouteStatus? {
        SessionEngine.routeStatus(state: state, now: now)
    }

    public var exitRoute: [BrickTag] { routeStatus?.steps ?? [] }
    public var routeStepsWalked: Int { routeStatus?.walked ?? 0 }

    /// Where to go next. `nil` when nothing is running.
    public var nextRouteTag: BrickTag? { routeStatus?.next }

    public var emergencyRemaining: Int { state.emergency.remainingAllowance(at: now) }

    // MARK: Reverse

    /// The reverse setup standing right now, if any.
    public var armedProfile: BlockProfile? { state.armedProfile }
    public var isArmed: Bool { state.armedProfileID != nil }
    public var isPermitRunning: Bool { state.activeSession?.kind == .permit }
    public var permitsRemaining: Int { SessionEngine.permitsRemaining(state: state, now: now) ?? 0 }
    public var disarmOpensAt: Date? { SessionEngine.disarmOpensAt(state: state) }

    public var canDisarm: Bool {
        guard isArmed, !isPermitRunning else { return false }
        guard let opensAt = disarmOpensAt else { return true }
        return now >= opensAt
    }

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
        case .brick: return routeStatus?.description ?? state.tag?.whereItIs
            ?? "Your brick has the way out."
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
        // A block session ends by clearing; a permit ends by putting the
        // standing shield back. Getting this backwards would either strand the
        // user or quietly leave reverse mode off.
        switch SessionEngine.expiryAction(state: state) {
        case .clear:
            shielding.clear()
        case .reapply(let selectionData):
            try? shielding.apply(selectionData: selectionData)
        }
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
        if let session = state.activeSession, session.isActive {
            // A permit is an open window on purpose; re-applying here would
            // shut it early.
            guard session.kind != .permit else { return true }
            do {
                try shielding.apply(
                    selectionData: SessionEngine.profile(for: session, in: state).selectionData
                )
                return true
            } catch {
                return false
            }
        }
        if let armed = state.armedProfile {
            do {
                try shielding.apply(selectionData: armed.selectionData)
                return true
            } catch {
                return false
            }
        }
        return true
    }

    // MARK: Pairing

    /// Writes an identity onto the tag when a writer is available, and falls
    /// back to a plain read otherwise — a tag that is already locked, or a
    /// build without write support, still pairs on its UID.
    ///
    /// - Parameter writeIdentity: `false` pairs on the factory UID alone and
    ///   leaves the tag's contents untouched. That is how a second phone joins
    ///   a brick someone else already paired: one object, two phones, two
    ///   unrelated sets of sessions, and no sync between them — the UID is
    ///   public and unwritable, so nothing has to be shared to agree on it.
    public func pairBrick(
        name: String = "",
        placeNote: String = "",
        profileID: UUID? = nil,
        writeIdentity: Bool = true
    ) async throws {
        let identity = UUID()
        let uid: String
        var wroteIdentity = false
        if let tagWriter, writeIdentity {
            do {
                uid = try await tagWriter.writeIdentity(identity)
                wroteIdentity = true
            } catch {
                uid = try await tagReader.readTagUID()
            }
        } else {
            uid = try await tagReader.readTagUID()
        }
        guard state.tag(withUID: uid) == nil else {
            // If the write went through, the tag physically carries the new
            // identity now, so record it before refusing rather than leaving
            // the stored ndefID describing a tag that no longer matches.
            if wroteIdentity {
                persist { state in
                    guard let index = state.tags.firstIndex(where: {
                        $0.uid.caseInsensitiveCompare(uid) == .orderedSame
                    }) else { return }
                    state.tags[index].ndefID = identity
                }
            }
            throw record(.alreadyPaired)
        }
        persist {
            $0.tags.append(
                BrickTag(
                    uid: uid,
                    ndefID: identity,
                    name: name,
                    placeNote: placeNote,
                    profileID: profileID ?? $0.profiles.first?.id,
                    pairedAt: self.now
                )
            )
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

    public func updateTag(uid: String, name: String? = nil, placeNote: String? = nil, profileID: UUID?? = nil) {
        persist { state in
            guard let index = state.tags.firstIndex(where: {
                $0.uid.caseInsensitiveCompare(uid) == .orderedSame
            }) else { return }
            if let name { state.tags[index].name = name }
            if let placeNote { state.tags[index].placeNote = placeNote }
            if let profileID { state.tags[index].profileID = profileID }
        }
    }

    /// Only allowed while nothing is running — otherwise unpairing would be a
    /// free unlock.
    public func unpairBrick() throws {
        guard state.activeSession?.isActive != true else { throw BrickError.sessionAlreadyActive }
        persist { $0.tags.removeAll() }
    }

    /// Drops one station. Its steps leave every exit route with it, so no
    /// profile is left pointing at a tag that no longer exists.
    public func unpairTag(uid: String) throws {
        guard state.activeSession?.isActive != true else { throw BrickError.sessionAlreadyActive }
        persist { state in
            state.tags.removeAll { $0.uid.caseInsensitiveCompare(uid) == .orderedSame }
            for index in state.profiles.indices {
                state.profiles[index].exitRoute.removeAll {
                    $0.caseInsensitiveCompare(uid) == .orderedSame
                }
            }
        }
    }

    // MARK: Profiles

    /// A fresh install has no setups and every screen needs one to point at,
    /// so the first launch makes it rather than every caller checking.
    @discardableResult
    public func defaultProfile() -> BlockProfile {
        if let first = state.profiles.first { return first }
        let profile = BlockProfile()
        persist { $0.profiles.append(profile) }
        return profile
    }

    @discardableResult
    public func addProfile(_ profile: BlockProfile) -> BlockProfile {
        persist { $0.profiles.append(profile) }
        return profile
    }

    public func updateProfile(_ profile: BlockProfile) {
        persist { state in
            guard let index = state.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
            state.profiles[index] = profile
        }
    }

    /// Refused while its own session runs: the rules a session started under
    /// are the rules it ends under.
    public func removeProfile(id: UUID) throws {
        if let session = state.activeSession, session.isActive,
           SessionEngine.profile(for: session, in: state).id == id {
            throw record(.sessionAlreadyActive)
        }
        persist { state in
            state.profiles.removeAll { $0.id == id }
            for index in state.tags.indices where state.tags[index].profileID == id {
                state.tags[index].profileID = state.profiles.first?.id
            }
        }
    }

    /// Direction is the one setting that cannot change under a live shield:
    /// a setup that flipped while standing would leave the phone blocked with
    /// no rule describing why.
    public func setMode(_ mode: ProfileMode, forProfile id: UUID) throws {
        guard state.armedProfileID != id else { throw record(.reverseArmed) }
        if let session = state.activeSession, session.isActive,
           SessionEngine.profile(for: session, in: state).id == id {
            throw record(.sessionAlreadyActive)
        }
        persist { state in
            guard let index = state.profiles.firstIndex(where: { $0.id == id }) else { return }
            state.profiles[index].mode = mode
        }
    }

    /// The route is stored as UIDs, in order. An empty route means the tag
    /// that started the session — the one-brick product.
    public func setExitRoute(_ uids: [String], forProfile id: UUID) throws {
        if let session = state.activeSession, session.isActive,
           SessionEngine.profile(for: session, in: state).id == id {
            throw record(.sessionAlreadyActive)
        }
        persist { state in
            guard let index = state.profiles.firstIndex(where: { $0.id == id }) else { return }
            state.profiles[index].exitRoute = uids
        }
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

    /// Starting goes through whichever key is configured. With a brick the
    /// tag decides the profile, so `profileID` is only consulted on the
    /// biometric path, where there is no object to ask.
    public func startSessionUsingKey(duration: TimeInterval, profileID: UUID? = nil) async throws {
        switch state.unlock {
        case .brick:
            try await startSessionByTap(duration: duration)
        case .biometric:
            try await biometrics.authenticate(reason: "Start a session.")
            try startSession(duration: duration, profileID: profileID)
        }
    }

    /// Starting requires the brick: you scan it, then you walk away from it.
    /// Which brick decides which profile — that is what a station is.
    public func startSessionByTap(duration: TimeInterval) async throws {
        guard !state.tags.isEmpty else { throw record(.notPaired) }
        let uid = try await tagReader.readTagUID()
        let session: Session
        do {
            session = try SessionEngine.validateStartByTap(
                state: state, scannedUID: uid, duration: duration, now: now
            )
        } catch let error as BrickError {
            throw record(error)
        }
        try begin(session)
    }

    public func startSession(duration: TimeInterval, profileID: UUID? = nil) throws {
        guard let profile = state.profile(id: profileID) ?? state.profiles.first else {
            throw record(.emptyBlocklist)
        }
        let session: Session
        do {
            session = try SessionEngine.validateStart(
                state: state, profile: profile, startedByTag: nil, duration: duration, now: now
            )
        } catch let error as BrickError {
            throw record(error)
        }
        try begin(session)
    }

    private func begin(_ session: Session) throws {
        let profile = SessionEngine.profile(for: session, in: state)
        try shielding.apply(selectionData: profile.selectionData)
        do {
            try scheduler.scheduleEnd(of: session)
        } catch {
            // Without a scheduled end the brick becomes a trap, so refuse to
            // start rather than leave the user relying on the app being opened.
            shielding.clear()
            throw error
        }
        notifier.scheduleSessionNotifications(for: session)
        persist {
            $0.activeSession = session
            $0.routeProgress = nil
        }
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

    /// One tap of the exit route. A profile with no route is a route of one,
    /// so this is also the plain "tap the brick" path.
    ///
    /// - Returns: the outcome, so the UI can say how much of the walk is left.
    @discardableResult
    public func endSessionByTap() async throws -> RouteOutcome {
        guard !state.tags.isEmpty else { throw record(.notPaired) }
        let uid = try await tagReader.readTagUID()
        let outcome: RouteOutcome
        do {
            outcome = try SessionEngine.validateRouteTap(state: state, scannedUID: uid, now: now)
        } catch let error as BrickError {
            throw record(error)
        }
        persist { SessionEngine.apply(outcome, to: &$0) }
        switch outcome {
        case .completed:
            finish(reason: .tappedBrick)
        case .advanced:
            lastError = nil
        case .wrongTag(let scanned, _):
            throw record(.wrongTag(scanned: scanned))
        }
        return outcome
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

    // MARK: Reverse — arming, permits, disarming

    /// Puts a reverse setup up. With a brick that means tapping one of its
    /// tags; the object is still what starts it.
    public func armReverse(profileID: UUID? = nil) async throws {
        let profile: BlockProfile
        switch state.unlock {
        case .brick:
            let uid = try await tagReader.readTagUID()
            guard let tapped = SessionEngine.profile(forTagUID: uid, in: state) else {
                throw record(.wrongTag(scanned: uid))
            }
            if let profileID, tapped.id != profileID { throw record(.wrongTag(scanned: uid)) }
            profile = tapped
        case .biometric:
            guard let chosen = state.profile(id: profileID) ?? state.profiles.first else {
                throw record(.emptyBlocklist)
            }
            try await biometrics.authenticate(reason: "Put this setup up.")
            profile = chosen
        }

        do {
            try SessionEngine.validateArm(state: state, profile: profile, now: now)
        } catch let error as BrickError {
            throw record(error)
        }
        try shielding.apply(selectionData: profile.selectionData)
        persist { SessionEngine.arm(&$0, profile: profile, at: self.now) }
        lastError = nil
    }

    /// Buys an open window. The shield comes down only once its return is
    /// scheduled — rule 8, mirrored: never lift a shield without a way back.
    public func grantPermit(duration: TimeInterval? = nil, spendingEmergency: Bool = false) async throws {
        var scannedUID: String?
        switch state.unlock {
        case .brick:
            scannedUID = try await tagReader.readTagUID()
        case .biometric:
            try await biometrics.authenticate(reason: "Open the phone for a while.")
        }

        let session: Session
        do {
            session = try SessionEngine.validatePermit(
                state: state,
                scannedUID: scannedUID,
                duration: duration,
                spendingEmergency: spendingEmergency,
                now: now
            )
        } catch let error as BrickError {
            throw record(error)
        }

        // Filed first so a monitor callback that arrives immediately finds a
        // permit to close rather than an empty state.
        persist { SessionEngine.openPermit(&$0, session, at: self.now) }
        do {
            try scheduler.scheduleEnd(of: session)
        } catch {
            persist {
                $0.activeSession = nil
                if session.grantedByEmergency, !$0.emergency.uses.isEmpty {
                    $0.emergency.uses.removeLast()
                } else if !$0.permits.uses.isEmpty {
                    $0.permits.uses.removeLast()
                }
            }
            throw error
        }
        shielding.clear()
        notifier.scheduleSessionNotifications(for: session)
        lastError = nil
    }

    /// Puts the shield back before the permit runs out. Always allowed: there
    /// is nothing to protect the user from in this direction.
    public func closePermitEarly() {
        guard let session = state.activeSession, session.kind == .permit, session.isActive else { return }
        if let armed = state.armedProfile {
            try? shielding.apply(selectionData: armed.selectionData)
        }
        scheduler.cancelScheduledEnd()
        notifier.cancelSessionNotifications()
        let timestamp = now
        persist { SessionEngine.close(&$0, reason: .closedEarly, at: timestamp) }
        lastError = nil
    }

    /// Takes the standing shield down for good — the way out of reverse mode,
    /// behind the same minimum a session's gate uses.
    public func disarmReverse() async throws {
        var scannedUID: String?
        switch state.unlock {
        case .brick:
            do {
                _ = try SessionEngine.validateDisarm(state: state, scannedUID: nil, now: now)
            } catch let error as BrickError {
                throw record(error)  // refuse before the scan when the gate is shut
            }
            scannedUID = try await tagReader.readTagUID()
        case .biometric:
            do {
                _ = try SessionEngine.validateDisarm(state: state, scannedUID: nil, now: now)
            } catch let error as BrickError {
                throw record(error)
            }
            try await biometrics.authenticate(reason: "Take this setup down.")
        }

        do {
            try SessionEngine.validateDisarm(state: state, scannedUID: scannedUID, now: now)
        } catch let error as BrickError {
            throw record(error)
        }
        shielding.clear()
        persist { SessionEngine.disarm(&$0) }
        lastError = nil
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
