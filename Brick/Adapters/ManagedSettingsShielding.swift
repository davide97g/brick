import BrickKit
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
        try SelectionShield.apply(selectionData, to: store)
    }

    func clear() {
        store.clearAllSettings()
    }
}
