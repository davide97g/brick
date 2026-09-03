import Foundation

public enum EndReason: String, Codable, Equatable, Sendable {
    /// Reached its planned end; cleared by the DeviceActivity monitor.
    case scheduled
    /// User returned to the brick and tapped it — the whole route of it.
    case tappedBrick
    /// No brick paired: user passed the biometric prompt after the gate opened.
    case biometrics
    /// User spent one of their emergency unlocks.
    case emergency
}

/// Which direction the session runs in.
///
/// A `.block` session ends by clearing the shield; a `.permit` ends by putting
/// it back. Everything downstream of that — the monitor, `reconcile()`, the
/// rollback ordering — has to know which one it is holding.
public enum SessionKind: String, Codable, Equatable, Sendable {
    case block
    case permit
}

public struct Session: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public var plannedEnd: Date
    public var endedAt: Date?
    public var endReason: EndReason?
    public var kind: SessionKind
    /// The profile whose rules govern this session. `nil` for sessions filed
    /// before profiles existed, which the engine reads as the first profile.
    public var profileID: UUID?
    /// The tag that started it — the default exit when a profile names no route.
    public var startedByTag: String?
    /// A permit taken beyond the quota, at the cost of an emergency unlock.
    public var grantedByEmergency: Bool

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        plannedEnd: Date,
        endedAt: Date? = nil,
        endReason: EndReason? = nil,
        kind: SessionKind = .block,
        profileID: UUID? = nil,
        startedByTag: String? = nil,
        grantedByEmergency: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.plannedEnd = plannedEnd
        self.endedAt = endedAt
        self.endReason = endReason
        self.kind = kind
        self.profileID = profileID
        self.startedByTag = startedByTag
        self.grantedByEmergency = grantedByEmergency
    }

    public var isActive: Bool { endedAt == nil }
    public var plannedDuration: TimeInterval { plannedEnd.timeIntervalSince(startedAt) }

    public func remaining(at now: Date) -> TimeInterval {
        max(0, plannedEnd.timeIntervalSince(now))
    }

    public func elapsed(at now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(startedAt))
    }

    /// When the brick tap becomes a valid way out.
    public func earliestTapExit(minimumDuration: TimeInterval) -> Date {
        startedAt.addingTimeInterval(min(minimumDuration, plannedDuration))
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case id, startedAt, plannedEnd, endedAt, endReason
        case kind, profileID, startedByTag, grantedByEmergency
    }

    /// Field by field, for the same reason as everything else here: a running
    /// session written by an older build has none of the new keys, and a throw
    /// while decoding it would hand the user an empty state with the shield
    /// still up.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        plannedEnd = try container.decode(Date.self, forKey: .plannedEnd)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        endReason = try container.decodeIfPresent(EndReason.self, forKey: .endReason)
        kind = try container.decodeIfPresent(SessionKind.self, forKey: .kind) ?? .block
        profileID = try container.decodeIfPresent(UUID.self, forKey: .profileID)
        startedByTag = try container.decodeIfPresent(String.self, forKey: .startedByTag)
        grantedByEmergency = try container.decodeIfPresent(Bool.self, forKey: .grantedByEmergency) ?? false
    }
}
