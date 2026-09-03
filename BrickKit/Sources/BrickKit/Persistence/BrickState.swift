import Foundation

/// Everything the app and its extensions need to agree on, in one Codable value.
public struct BrickState: Codable, Equatable, Sendable {
    /// The state file is read by two extensions under tight limits, so history
    /// is capped rather than allowed to grow forever.
    public static let historyLimit = 200

    public var tags: [BrickTag]
    public var profiles: [BlockProfile]
    public var unlock: UnlockMethod
    public var activeSession: Session?
    /// Reverse mode: the profile whose standing shield is up, with no session
    /// running. `nil` in the ordinary direction.
    public var armedProfileID: UUID?
    public var routeProgress: RouteProgress?
    public var history: [Session]
    public var emergency: EmergencyLog

    public init(
        tags: [BrickTag] = [],
        profiles: [BlockProfile] = [],
        unlock: UnlockMethod = .brick,
        activeSession: Session? = nil,
        armedProfileID: UUID? = nil,
        routeProgress: RouteProgress? = nil,
        history: [Session] = [],
        emergency: EmergencyLog = EmergencyLog()
    ) {
        self.tags = tags
        self.profiles = profiles
        self.unlock = unlock
        self.activeSession = activeSession
        self.armedProfileID = armedProfileID
        self.routeProgress = routeProgress
        self.history = history
        self.emergency = emergency
    }

    /// The shape of the state while there was one tag and one blocklist. Kept
    /// so the app and its tests keep compiling; it goes when the profiles UI
    /// lands.
    public init(
        tag: BrickTag?,
        unlock: UnlockMethod = .brick,
        blocklist: BlockProfile = BlockProfile(),
        activeSession: Session? = nil,
        history: [Session] = [],
        emergency: EmergencyLog = EmergencyLog()
    ) {
        var tag = tag
        tag?.profileID = blocklist.id
        self.init(
            tags: tag.map { [$0] } ?? [],
            profiles: [blocklist],
            unlock: unlock,
            activeSession: activeSession,
            history: history,
            emergency: emergency
        )
    }

    // MARK: The single-brick view of a set of them

    /// The one tag, for code that hasn't learned about the set yet.
    public var tag: BrickTag? {
        get { tags.first }
        set {
            guard let newValue else { tags.removeAll(); return }
            if tags.isEmpty { tags = [newValue] } else { tags[0] = newValue }
        }
    }

    /// The profile a bare "start a session" uses.
    public var blocklist: BlockProfile {
        get { profiles.first ?? BlockProfile() }
        set {
            if profiles.isEmpty { profiles = [newValue] } else { profiles[0] = newValue }
        }
    }

    // MARK: Derived

    public var isPaired: Bool { !tags.isEmpty }

    /// Whether there is any way in and out at all: a paired brick, or
    /// biometrics standing in for one.
    public var hasKey: Bool {
        switch unlock {
        case .brick: return isPaired
        case .biometric: return true
        }
    }

    public var isReadyToStart: Bool { hasKey && !blocklist.isEmpty }

    public func tag(withUID uid: String) -> BrickTag? {
        tags.first { $0.uid.caseInsensitiveCompare(uid) == .orderedSame }
    }

    public func profile(id: UUID?) -> BlockProfile? {
        guard let id else { return nil }
        return profiles.first { $0.id == id }
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case tags, profiles, unlock, activeSession, armedProfileID, routeProgress
        case history, emergency
        // Written by every build before profiles existed.
        case tag, blocklist
    }

    /// Decoded field by field so that a state file written by an older build —
    /// one with a single `tag` and a single `blocklist` — still loads. `load()`
    /// falls back to an empty state on any thrown error, which would silently
    /// unpair the user and drop their blocklist.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unlock = try container.decodeIfPresent(UnlockMethod.self, forKey: .unlock) ?? .brick
        activeSession = try container.decodeIfPresent(Session.self, forKey: .activeSession)
        armedProfileID = try container.decodeIfPresent(UUID.self, forKey: .armedProfileID)
        routeProgress = try container.decodeIfPresent(RouteProgress.self, forKey: .routeProgress)
        history = try container.decodeIfPresent([Session].self, forKey: .history) ?? []
        emergency = try container.decodeIfPresent(EmergencyLog.self, forKey: .emergency) ?? EmergencyLog()

        let decodedProfiles = try container.decodeIfPresent([BlockProfile].self, forKey: .profiles)
        let legacyBlocklist = try container.decodeIfPresent(BlockProfile.self, forKey: .blocklist)
        profiles = decodedProfiles ?? legacyBlocklist.map { [$0] } ?? []

        let decodedTags = try container.decodeIfPresent([BrickTag].self, forKey: .tags)
        let legacyTag = try container.decodeIfPresent(BrickTag.self, forKey: .tag)
        tags = decodedTags ?? legacyTag.map { [$0] } ?? []

        // The migrated tag has to point at the migrated profile, or it starts
        // nothing: neither key existed when the file was written.
        if decodedTags == nil, let profileID = profiles.first?.id {
            for index in tags.indices where tags[index].profileID == nil {
                tags[index].profileID = profileID
            }
        }
    }

    /// The legacy keys are read but never written back: one migration, at the
    /// first load after the update.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tags, forKey: .tags)
        try container.encode(profiles, forKey: .profiles)
        try container.encode(unlock, forKey: .unlock)
        try container.encodeIfPresent(activeSession, forKey: .activeSession)
        try container.encodeIfPresent(armedProfileID, forKey: .armedProfileID)
        try container.encodeIfPresent(routeProgress, forKey: .routeProgress)
        try container.encode(history, forKey: .history)
        try container.encode(emergency, forKey: .emergency)
    }
}
