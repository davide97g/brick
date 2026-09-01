import Foundation
import Testing
@testable import BrickKit

@MainActor
private struct Harness {
    let store = InMemoryStateStore()
    let shielding = RecordingShielding()
    let scheduler = RecordingScheduler()
    let tagReader = StubTagReader(uid: "04A1B2C3D4E580")
    let notifier = RecordingNotifier()
    let clock = TestClock()
    let controller: BrickController

    init(paired: Bool = true, withBlocklist: Bool = true) {
        var state = BrickState()
        if paired {
            state.tag = BrickTag(uid: "04A1B2C3D4E580", placeNote: "on your desk", pairedAt: clock.now)
        }
        if withBlocklist {
            state.blocklist = BlocklistConfig(
                selectionData: Data([0x01]),
                appCount: 4,
                minimumDuration: .brickMinutes(30)
            )
        }
        store.save(state)
        controller = BrickController(
            store: store,
            shielding: shielding,
            scheduler: scheduler,
            tagReader: tagReader,
            notifier: notifier,
            clock: clock
        )
    }
}

@MainActor
@Suite("Controller")
struct BrickControllerTests {

    @Test("pairing stores the scanned UID")
    func pairing() async throws {
        let h = Harness(paired: false)
        try await h.controller.pairBrick(placeNote: "in the hallway")
        #expect(h.controller.state.tag?.uid == "04A1B2C3D4E580")
        #expect(h.store.load().tag?.placeNote == "in the hallway")
    }

    @Test("starting applies the shield and schedules the end")
    func startAppliesShield() async throws {
        let h = Harness()
        try await h.controller.startSessionByTap(duration: .brickMinutes(60))
        #expect(h.shielding.isShielded)
        #expect(h.shielding.events == [.applied(Data([0x01]))])
        #expect(h.scheduler.scheduled?.plannedEnd == h.clock.now.addingTimeInterval(.brickMinutes(60)))
        #expect(h.store.load().activeSession != nil)
    }

    @Test("starting with a foreign tag leaves the phone untouched")
    func foreignTagDoesNotStart() async {
        let h = Harness()
        h.tagReader.stub(.success("FFFFFFFFFFFFFF"))
        await #expect(throws: BrickError.wrongTag(scanned: "FFFFFFFFFFFFFF")) {
            try await h.controller.startSessionByTap(duration: .brickMinutes(60))
        }
        #expect(h.shielding.events.isEmpty)
        #expect(h.store.load().activeSession == nil)
    }

    @Test("a failed schedule rolls the shield back rather than trapping the user")
    func failedScheduleRollsBack() async throws {
        struct Boom: Error {}
        final class FailingScheduler: SessionScheduling, @unchecked Sendable {
            func scheduleEnd(of session: Session) throws { throw Boom() }
            func cancelScheduledEnd() {}
        }
        let store = InMemoryStateStore(
            BrickState(
                tag: BrickTag(uid: "04A1B2C3D4E580", pairedAt: Date()),
                blocklist: BlocklistConfig(selectionData: Data([0x01]), appCount: 1)
            )
        )
        let shielding = RecordingShielding()
        let controller = BrickController(
            store: store,
            shielding: shielding,
            scheduler: FailingScheduler(),
            tagReader: StubTagReader(),
            clock: TestClock()
        )
        #expect(throws: Boom.self) {
            try controller.startSession(duration: .brickMinutes(60))
        }
        #expect(!shielding.isShielded)
        #expect(store.load().activeSession == nil)
    }

    @Test("tapping early refuses and keeps the shield up")
    func earlyTapKeepsShield() async throws {
        let h = Harness()
        try await h.controller.startSessionByTap(duration: .brickMinutes(90))
        h.clock.advance(by: .brickMinutes(10))
        await #expect(throws: BrickError.self) {
            try await h.controller.endSessionByTap()
        }
        #expect(h.shielding.isShielded)
        #expect(h.controller.activeSession != nil)
        #expect(!h.controller.canEndByTap)
    }

    @Test("tapping after the minimum duration clears everything")
    func tapEndClears() async throws {
        let h = Harness()
        try await h.controller.startSessionByTap(duration: .brickMinutes(90))
        h.clock.advance(by: .brickMinutes(30))
        #expect(h.controller.canEndByTap)
        try await h.controller.endSessionByTap()
        #expect(!h.shielding.isShielded)
        #expect(h.scheduler.cancelCount == 1)
        #expect(h.controller.activeSession == nil)
        #expect(h.store.load().history.last?.endReason == .tappedBrick)
    }

    @Test("emergency unlock works away from the brick and spends allowance")
    func emergencyUnlock() async throws {
        let h = Harness()
        try await h.controller.startSessionByTap(duration: .brickMinutes(90))
        h.clock.advance(by: .brickMinutes(5))
        #expect(h.controller.emergencyRemaining == 3)
        try h.controller.endSessionByEmergency()
        #expect(!h.shielding.isShielded)
        #expect(h.controller.emergencyRemaining == 2)
        #expect(h.store.load().history.last?.endReason == .emergency)
    }

    @Test("a missed monitor callback is repaired on foreground")
    func reconcileClearsExpiredShield() async throws {
        let h = Harness()
        try await h.controller.startSessionByTap(duration: .brickMinutes(30))
        // Simulate the extension never firing: state still says active.
        h.clock.advance(by: .brickMinutes(45))
        h.controller.reconcile()
        #expect(!h.shielding.isShielded)
        #expect(h.controller.activeSession == nil)
        let closed = try #require(h.store.load().history.last)
        #expect(closed.endReason == .scheduled)
        // Filed at its planned end, not at the moment we noticed.
        #expect(closed.endedAt == closed.plannedEnd)
    }

    @Test("reconcile leaves a still-running session alone")
    func reconcileLeavesRunningSession() async throws {
        let h = Harness()
        try await h.controller.startSessionByTap(duration: .brickMinutes(60))
        h.clock.advance(by: .brickMinutes(20))
        h.controller.reconcile()
        #expect(h.shielding.isShielded)
        #expect(h.controller.activeSession != nil)
    }

    @Test("starting queues the end notifications, ending cancels them")
    func notificationsFollowTheSession() async throws {
        let h = Harness()
        try await h.controller.startSessionByTap(duration: .brickMinutes(60))
        #expect(h.notifier.scheduled.count == 1)
        #expect(h.notifier.cancelCount == 0)
        h.clock.advance(by: .brickMinutes(30))
        try await h.controller.endSessionByTap()
        #expect(h.notifier.cancelCount == 1)
    }

    @Test("expiry cancels any notification still queued")
    func expiryCancelsNotifications() async throws {
        let h = Harness()
        try await h.controller.startSessionByTap(duration: .brickMinutes(30))
        h.clock.advance(by: .brickMinutes(31))
        h.controller.reconcile()
        #expect(h.notifier.cancelCount == 1)
    }

    @Test("unpairing is refused while a session is running")
    func cannotUnpairMidSession() async throws {
        let h = Harness()
        try await h.controller.startSessionByTap(duration: .brickMinutes(60))
        #expect(throws: BrickError.sessionAlreadyActive) {
            try h.controller.unpairBrick()
        }
        #expect(h.store.load().tag != nil)
    }
}
