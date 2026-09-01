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

        store.clearAllSettings()

        if let state = FileStateStore.shared() {
            state.mutate { current in
                let plannedEnd = current.activeSession?.plannedEnd ?? Date()
                SessionEngine.close(&current, reason: .scheduled, at: plannedEnd)
            }
        }

        notifySessionEnded()
    }

    /// A session removed from the other side (unpaired, emergency unlock) also
    /// arrives here as a stopped interval.
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    private func notifySessionEnded() {
        let content = UNMutableNotificationContent()
        content.title = "Session over"
        content.body = "Everything is unblocked."
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
