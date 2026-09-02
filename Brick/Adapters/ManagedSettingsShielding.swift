import BrickKit
import FamilyControls
import Foundation
import ManagedSettings

/// Real shielding: one named `ManagedSettingsStore` for the single brick.
///
/// Settings written here survive app termination and reboot — that persistence
/// is the point, and it's also why `reconcile()` exists on the controller.
final class ManagedSettingsShielding: Shielding, @unchecked Sendable {
    static let storeName = ManagedSettingsStore.Name(BrickIdentifiers.managedSettingsStore)

    private let store = ManagedSettingsStore(named: ManagedSettingsShielding.storeName)

    func apply(selectionData: Data?) throws {
        guard let selection = try SelectionCoder.decode(selectionData) else {
            throw BrickError.emptyBlocklist
        }
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil
            : selection.webDomainTokens
    }

    func clear() {
        store.clearAllSettings()
    }
}

/// The only place a `FamilyActivitySelection` is turned into bytes.
///
/// BrickKit stores those bytes without ever looking inside: the tokens are
/// opaque by Apple's design, and the app never learns which apps were chosen.
enum SelectionCoder {
    static func encode(_ selection: FamilyActivitySelection) throws -> Data {
        try JSONEncoder().encode(selection)
    }

    static func decode(_ data: Data?) throws -> FamilyActivitySelection? {
        guard let data else { return nil }
        return try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    /// `includeEntireCategory` is fixed at init and survives a round trip, so a
    /// selection stored by a build that used the default `false` keeps shielding
    /// nothing for its categories. Carrying the tokens into a whole-category
    /// selection is what makes an existing blocklist behave once re-picked.
    static func wholeCategories(_ selection: FamilyActivitySelection) -> FamilyActivitySelection {
        guard !selection.includeEntireCategory else { return selection }
        var migrated = FamilyActivitySelection(includeEntireCategory: true)
        migrated.applicationTokens = selection.applicationTokens
        migrated.categoryTokens = selection.categoryTokens
        migrated.webDomainTokens = selection.webDomainTokens
        return migrated
    }
}
