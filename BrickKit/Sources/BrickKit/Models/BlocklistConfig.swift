import Foundation

/// What the brick blocks, plus the session rules.
///
/// The selection itself is stored as an opaque `Data` blob — an encoded
/// `FamilyActivitySelection`. BrickKit deliberately never imports
/// FamilyControls: the tokens are opaque to us by Apple's design, and keeping
/// them opaque here is what lets the whole core compile and test on macOS.
/// Counts are cached alongside purely so the UI can say "12 apps" without
/// decoding anything.
public struct BlocklistConfig: Codable, Equatable, Sendable {
    public var selectionData: Data?
    public var appCount: Int
    public var categoryCount: Int
    public var webDomainCount: Int
    public var defaultDuration: TimeInterval
    public var minimumDuration: TimeInterval

    public init(
        selectionData: Data? = nil,
        appCount: Int = 0,
        categoryCount: Int = 0,
        webDomainCount: Int = 0,
        defaultDuration: TimeInterval = .brickMinutes(60),
        minimumDuration: TimeInterval = .brickMinutes(30)
    ) {
        self.selectionData = selectionData
        self.appCount = appCount
        self.categoryCount = categoryCount
        self.webDomainCount = webDomainCount
        self.defaultDuration = defaultDuration
        self.minimumDuration = minimumDuration
    }

    public var isEmpty: Bool {
        appCount == 0 && categoryCount == 0 && webDomainCount == 0
    }

    public var summary: String {
        guard !isEmpty else { return "Nothing selected yet" }
        var parts: [String] = []
        if appCount > 0 { parts.append("\(appCount) app\(appCount == 1 ? "" : "s")") }
        if categoryCount > 0 { parts.append("\(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")") }
        if webDomainCount > 0 { parts.append("\(webDomainCount) site\(webDomainCount == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }
}

extension TimeInterval {
    public static func brickMinutes(_ count: Double) -> TimeInterval { count * 60 }

    /// `DeviceActivitySchedule` refuses intervals shorter than 15 minutes, so
    /// nothing in the product may offer less.
    public static let brickMinimumSession: TimeInterval = .brickMinutes(15)
}
