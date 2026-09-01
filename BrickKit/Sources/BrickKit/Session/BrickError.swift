import Foundation

public enum BrickError: Error, Equatable, Sendable {
    case notPaired
    case alreadyPaired
    case wrongTag(scanned: String)
    case emptyBlocklist
    case durationTooShort(minimum: TimeInterval)
    case sessionAlreadyActive
    case noActiveSession
    case tooEarlyToEnd(availableAt: Date)
    case emergencyQuotaExhausted(replenishesAt: Date?)
}

extension BrickError: LocalizedError {
    /// Deliberately flat and factual. No lecturing: the product's whole tone
    /// depends on the refusal being a fact rather than a judgement.
    public var errorDescription: String? {
        switch self {
        case .notPaired:
            return "No brick paired yet."
        case .alreadyPaired:
            return "A brick is already paired."
        case .wrongTag:
            return "That isn't your brick."
        case .emptyBlocklist:
            return "Pick what the brick should block first."
        case .durationTooShort(let minimum):
            return "Sessions start at \(Int(minimum / 60)) minutes."
        case .sessionAlreadyActive:
            return "A session is already running."
        case .noActiveSession:
            return "No session is running."
        case .tooEarlyToEnd:
            return "Not yet."
        case .emergencyQuotaExhausted:
            return "No emergency unlocks left."
        }
    }
}
