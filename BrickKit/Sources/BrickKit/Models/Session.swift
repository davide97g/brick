import Foundation

public enum EndReason: String, Codable, Equatable, Sendable {
    /// Reached its planned end; cleared by the DeviceActivity monitor.
    case scheduled
    /// User returned to the brick and tapped it.
    case tappedBrick
    /// User spent one of their emergency unlocks.
    case emergency
}

public struct Session: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public var plannedEnd: Date
    public var endedAt: Date?
    public var endReason: EndReason?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        plannedEnd: Date,
        endedAt: Date? = nil,
        endReason: EndReason? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.plannedEnd = plannedEnd
        self.endedAt = endedAt
        self.endReason = endReason
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
}
