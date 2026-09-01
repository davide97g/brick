import Foundation

/// Names shared by the app and its extensions. They have to agree exactly, and
/// the extensions can't import the app target, so they live here.
public enum BrickIdentifiers {
    public static let appGroup = "group.com.davideghiotto.brick"
    /// `ManagedSettingsStore(named:)` — the single store for the single brick.
    public static let managedSettingsStore = "brick.session"
    /// `DeviceActivityName` used for the scheduled end of a session.
    public static let deviceActivity = "brick.session"
    public static let stateFilename = "brick-state.json"
}

extension FileStateStore {
    /// The shared store, as seen by the app and by both extensions.
    public static func shared() -> FileStateStore? {
        FileStateStore(appGroupID: BrickIdentifiers.appGroup, filename: BrickIdentifiers.stateFilename)
    }
}
