import Foundation

/// A rolling-window quota.
///
/// Written for emergency unlocks: the valve has to exist — the brick is
/// deliberately out of reach — but it has to cost something, and the cost is
/// local and visible rather than an email to support. Reverse mode reuses it
/// for permits, where the same shape says how many times a day the phone can
/// be opened, so the allowance and window are parameters as well as defaults.
public struct EmergencyLog: Codable, Equatable, Sendable {
    public static let allowance = 3
    public static let window: TimeInterval = 7 * 24 * 60 * 60

    public var uses: [Date]

    public init(uses: [Date] = []) { self.uses = uses }

    public func recentUses(at now: Date, window: TimeInterval = Self.window) -> [Date] {
        uses.filter { now.timeIntervalSince($0) < window }
    }

    public func remainingAllowance(
        at now: Date,
        allowance: Int = Self.allowance,
        window: TimeInterval = Self.window
    ) -> Int {
        max(0, allowance - recentUses(at: now, window: window).count)
    }

    public func hasAllowance(
        at now: Date,
        allowance: Int = Self.allowance,
        window: TimeInterval = Self.window
    ) -> Bool {
        remainingAllowance(at: now, allowance: allowance, window: window) > 0
    }

    /// When the oldest use falls out of the window and an allowance returns.
    public func nextReplenishment(
        at now: Date,
        allowance: Int = Self.allowance,
        window: TimeInterval = Self.window
    ) -> Date? {
        guard !hasAllowance(at: now, allowance: allowance, window: window) else { return nil }
        return recentUses(at: now, window: window).min()?.addingTimeInterval(window)
    }

    public mutating func record(at now: Date, window: TimeInterval = Self.window) {
        uses.append(now)
        uses = recentUses(at: now, window: window)
    }
}
