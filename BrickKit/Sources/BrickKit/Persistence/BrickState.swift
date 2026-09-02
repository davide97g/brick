import Foundation

/// Everything the app and its extensions need to agree on, in one Codable value.
public struct BrickState: Codable, Equatable, Sendable {
    /// The state file is read by two extensions under tight limits, so history
    /// is capped rather than allowed to grow forever.
    public static let historyLimit = 200

    public var tag: BrickTag?
    public var unlock: UnlockMethod
    public var blocklist: BlocklistConfig
    public var activeSession: Session?
    public var history: [Session]
    public var emergency: EmergencyLog

    public init(
        tag: BrickTag? = nil,
        unlock: UnlockMethod = .brick,
        blocklist: BlocklistConfig = BlocklistConfig(),
        activeSession: Session? = nil,
        history: [Session] = [],
        emergency: EmergencyLog = EmergencyLog()
    ) {
        self.tag = tag
        self.unlock = unlock
        self.blocklist = blocklist
        self.activeSession = activeSession
        self.history = history
        self.emergency = emergency
    }

    public var isPaired: Bool { tag != nil }

    /// Whether there is any way in and out at all: a paired brick, or
    /// biometrics standing in for one.
    public var hasKey: Bool {
        switch unlock {
        case .brick: return isPaired
        case .biometric: return true
        }
    }

    public var isReadyToStart: Bool { hasKey && !blocklist.isEmpty }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case tag, unlock, blocklist, activeSession, history, emergency
    }

    /// Decoded field by field so that a state file written by an older build —
    /// one with no `unlock` key — still loads. `load()` falls back to an empty
    /// state on any thrown error, which would silently unpair the user.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tag = try container.decodeIfPresent(BrickTag.self, forKey: .tag)
        unlock = try container.decodeIfPresent(UnlockMethod.self, forKey: .unlock) ?? .brick
        blocklist = try container.decodeIfPresent(BlocklistConfig.self, forKey: .blocklist) ?? BlocklistConfig()
        activeSession = try container.decodeIfPresent(Session.self, forKey: .activeSession)
        history = try container.decodeIfPresent([Session].self, forKey: .history) ?? []
        emergency = try container.decodeIfPresent(EmergencyLog.self, forKey: .emergency) ?? EmergencyLog()
    }
}
