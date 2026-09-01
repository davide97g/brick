import Foundation

/// Rolling-window quota for emergency unlocks.
///
/// The valve has to exist — the brick is deliberately out of reach — but it has
/// to cost something, and the cost is local and visible rather than an email to
/// support.
public struct EmergencyLog: Codable, Equatable, Sendable {
    public static let allowance = 3
    public static let window: TimeInterval = 7 * 24 * 60 * 60

    public var uses: [Date]

    public init(uses: [Date] = []) { self.uses = uses }

    public func recentUses(at now: Date) -> [Date] {
        uses.filter { now.timeIntervalSince($0) < Self.window }
    }

    public func remainingAllowance(at now: Date) -> Int {
        max(0, Self.allowance - recentUses(at: now).count)
    }

    public func hasAllowance(at now: Date) -> Bool {
        remainingAllowance(at: now) > 0
    }

    /// When the oldest use falls out of the window and an allowance returns.
    public func nextReplenishment(at now: Date) -> Date? {
        guard !hasAllowance(at: now) else { return nil }
        return recentUses(at: now).min()?.addingTimeInterval(Self.window)
    }

    public mutating func record(at now: Date) {
        uses.append(now)
        uses = recentUses(at: now)
    }
}
