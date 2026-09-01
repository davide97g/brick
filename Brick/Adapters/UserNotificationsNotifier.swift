import BrickKit
import Foundation
import UserNotifications

/// Queues both notifications when the session starts, so they still arrive if
/// the app is killed and the monitor extension never runs.
final class UserNotificationsNotifier: Notifying, @unchecked Sendable {
    private enum ID {
        static let warning = "brick.session.warning"
        static let ended = "brick.session.ended"
    }

    private let warningLeadTime: TimeInterval = .brickMinutes(5)

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func scheduleSessionNotifications(for session: Session) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ID.warning, ID.ended])

        let total = session.plannedDuration
        if total > warningLeadTime {
            add(
                id: ID.warning,
                title: "5 minutes left",
                body: "Your apps come back at \(session.plannedEnd.formatted(date: .omitted, time: .shortened)).",
                after: total - warningLeadTime
            )
        }

        add(
            id: ID.ended,
            title: "Session over",
            body: "Everything is unblocked.",
            after: total
        )
    }

    func cancelSessionNotifications() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [ID.warning, ID.ended])
    }

    private func add(id: String, title: String, body: String, after interval: TimeInterval) {
        guard interval > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
