import BrickKit
import DeviceActivity
import Foundation

/// Real scheduling: a `DeviceActivitySchedule` whose end fires the monitor
/// extension, which clears the shield even with the app killed.
///
/// `DeviceActivitySchedule` works in wall-clock components and refuses
/// intervals shorter than 15 minutes, which is why `TimeInterval.brickMinimumSession`
/// exists.
final class DeviceActivityScheduler: SessionScheduling, @unchecked Sendable {
    static let activityName = DeviceActivityName("brick.session")

    private let center = DeviceActivityCenter()
    private let calendar = Calendar.current

    func scheduleEnd(of session: Session) throws {
        let components: Set<Calendar.Component> = [.hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: session.startedAt),
            intervalEnd: calendar.dateComponents(components, from: session.plannedEnd),
            repeats: false
        )
        center.stopMonitoring([Self.activityName])
        try center.startMonitoring(Self.activityName, during: schedule)
    }

    func cancelScheduledEnd() {
        center.stopMonitoring([Self.activityName])
    }
}
