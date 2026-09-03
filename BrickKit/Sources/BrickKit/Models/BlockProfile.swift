import Foundation

/// Whether a profile blocks by default or opens by default.
///
/// `.block` is the original product: the phone is free until you tap, then it
/// is shielded until the clock or the walk says otherwise. `.reverse` inverts
/// it — the shield stands, and a tap buys a fixed open window. Both cost a
/// walk to the object; they differ in which direction the walk buys.
public enum ProfileMode: String, Codable, Equatable, Sendable {
    case block
    case reverse
}

/// What one occasion blocks, plus the rules for getting back out of it.
///
/// The selection itself is stored as an opaque `Data` blob — an encoded
/// `FamilyActivitySelection`. BrickKit deliberately never imports
/// FamilyControls: the tokens are opaque to us by Apple's design, and keeping
/// them opaque here is what lets the whole core compile and test on macOS.
/// Counts are cached alongside purely so the UI can say "12 apps" without
/// decoding anything.
public struct BlockProfile: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var selectionData: Data?
    public var appCount: Int
    public var categoryCount: Int
    public var webDomainCount: Int
    public var defaultDuration: TimeInterval
    public var minimumDuration: TimeInterval
    public var mode: ProfileMode

    /// Tag UIDs that have to be tapped, in order, to end a session early.
    /// Empty means the one tag that started the session — the original
    /// product, expressed as a route of length one.
    public var exitRoute: [String]

    /// How long a partly-walked route stays valid. A route has to be one walk,
    /// not a week of drive-bys, and a house is a different distance from an
    /// office — so it is per profile.
    public var routeWindow: TimeInterval

    public init(
        id: UUID = UUID(),
        name: String = "Brick",
        selectionData: Data? = nil,
        appCount: Int = 0,
        categoryCount: Int = 0,
        webDomainCount: Int = 0,
        defaultDuration: TimeInterval = .brickMinutes(60),
        minimumDuration: TimeInterval = .brickMinutes(30),
        mode: ProfileMode = .block,
        exitRoute: [String] = [],
        routeWindow: TimeInterval = .brickRouteWindow
    ) {
        self.id = id
        self.name = name
        self.selectionData = selectionData
        self.appCount = appCount
        self.categoryCount = categoryCount
        self.webDomainCount = webDomainCount
        self.defaultDuration = defaultDuration
        self.minimumDuration = minimumDuration
        self.mode = mode
        self.exitRoute = exitRoute
        self.routeWindow = routeWindow
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

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case id, name, selectionData, appCount, categoryCount, webDomainCount
        case defaultDuration, minimumDuration, mode, exitRoute, routeWindow
    }

    /// Decoded field by field: this type was written to disk as
    /// `BlocklistConfig`, with none of the profile keys. A throw here reaches
    /// `load()`, which swallows it and returns empty state — i.e. it would
    /// silently drop the user's blocklist.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Brick"
        selectionData = try container.decodeIfPresent(Data.self, forKey: .selectionData)
        appCount = try container.decodeIfPresent(Int.self, forKey: .appCount) ?? 0
        categoryCount = try container.decodeIfPresent(Int.self, forKey: .categoryCount) ?? 0
        webDomainCount = try container.decodeIfPresent(Int.self, forKey: .webDomainCount) ?? 0
        defaultDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .defaultDuration)
            ?? .brickMinutes(60)
        minimumDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .minimumDuration)
            ?? .brickMinutes(30)
        mode = try container.decodeIfPresent(ProfileMode.self, forKey: .mode) ?? .block
        exitRoute = try container.decodeIfPresent([String].self, forKey: .exitRoute) ?? []
        routeWindow = try container.decodeIfPresent(TimeInterval.self, forKey: .routeWindow)
            ?? .brickRouteWindow
    }
}

/// The name this type had while there was only ever one of them. Kept so the
/// app and its tests keep compiling; it goes when the profiles UI lands.
public typealias BlocklistConfig = BlockProfile

extension TimeInterval {
    public static func brickMinutes(_ count: Double) -> TimeInterval { count * 60 }

    /// `DeviceActivitySchedule` refuses intervals shorter than 15 minutes, so
    /// nothing in the product may offer less.
    public static let brickMinimumSession: TimeInterval = .brickMinutes(15)

    /// Long enough to walk a house, short enough that yesterday's half-walked
    /// route doesn't count towards today's.
    public static let brickRouteWindow: TimeInterval = .brickMinutes(10)
}
