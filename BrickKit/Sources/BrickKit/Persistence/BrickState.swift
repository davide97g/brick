import Foundation

/// Everything the app and its extensions need to agree on, in one Codable value.
public struct BrickState: Codable, Equatable, Sendable {
    /// The state file is read by two extensions under tight limits, so history
    /// is capped rather than allowed to grow forever.
    public static let historyLimit = 200

    public var tag: BrickTag?
    public var blocklist: BlocklistConfig
    public var activeSession: Session?
    public var history: [Session]
    public var emergency: EmergencyLog

    public init(
        tag: BrickTag? = nil,
        blocklist: BlocklistConfig = BlocklistConfig(),
        activeSession: Session? = nil,
        history: [Session] = [],
        emergency: EmergencyLog = EmergencyLog()
    ) {
        self.tag = tag
        self.blocklist = blocklist
        self.activeSession = activeSession
        self.history = history
        self.emergency = emergency
    }

    public var isPaired: Bool { tag != nil }
    public var isReadyToStart: Bool { isPaired && !blocklist.isEmpty }
}
