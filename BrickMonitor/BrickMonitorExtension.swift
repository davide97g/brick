import BrickKit
import DeviceActivity
import Foundation
import ManagedSettings
import UserNotifications

/// Clears the shield when a session reaches its planned end, with the app not
/// running. Without this the leave-behind model would be a trap.
///
/// This runs out of process under tight time and memory limits, so it does the
/// least possible: clear the store, close the session in shared state, notify.
class BrickMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(
        named: ManagedSettingsStore.Name(BrickIdentifiers.managedSettingsStore)
    )

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue == BrickIdentifiers.deviceActivity else { return }

        var wasPermit = false

        if let stateStore = FileStateStore.shared() {
            stateStore.mutate { current in
                // A session ends by clearing the shield; a permit ends by
                // putting the standing one back. This process is the only
                // thing running, so getting the direction right here is the
                // whole of it.
                switch SessionEngine.expiryAction(state: current) {
                case .clear:
                    store.clearAllSettings()
                case .reapply(let selectionData):
                    wasPermit = true
                    try? SelectionShield.apply(selectionData, to: store)
                }
                let plannedEnd = current.activeSession?.plannedEnd ?? Date()
                SessionEngine.close(&current, reason: .scheduled, at: plannedEnd)
            }
        } else {
            store.clearAllSettings()
        }

        notifySessionEnded(wasPermit: wasPermit)
    }

    private func notifySessionEnded(wasPermit: Bool) {
        let content = UNMutableNotificationContent()
        content.title = wasPermit ? "Time's up" : "Session over"
        content.body = wasPermit ? "Blocked again." : "Everything is unblocked."
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: "brick.session.ended.monitor",
                content: content,
                trigger: nil
            )
        )
    }
}
