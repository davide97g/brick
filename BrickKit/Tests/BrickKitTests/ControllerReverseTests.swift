import Foundation
import Testing
@testable import BrickKit

private let slabUID = "04AAAAAAAAAA80"
private let deskUID = "04BBBBBBBBBB80"

private final class FailingScheduler: SessionScheduling, @unchecked Sendable {
    struct Boom: Error {}
    func scheduleEnd(of session: Session) throws { throw Boom() }
    func cancelScheduledEnd() {}
}

@MainActor
private struct ReverseHarness {
    let store = InMemoryStateStore()
    let shielding = RecordingShielding()
    let scheduler: SessionScheduling
    let recording = RecordingScheduler()
    let tagReader = StubTagReader(uid: slabUID)
    let notifier = RecordingNotifier()
    let clock = TestClock()
    let controller: BrickController
    let standing: BlockProfile

    init(minimumDuration: TimeInterval = .brickMinutes(60), failingScheduler: Bool = false) {
        standing = BlockProfile(
            name: "Doomscroll",
            selectionData: Data([0x07]),
            appCount: 5,
            minimumDuration: minimumDuration,
            mode: .reverse,
            permitAllowance: 2
        )
        let work = BlockProfile(name: "Deep work", selectionData: Data([0x01]), appCount: 3)
        store.save(
            BrickState(
                tags: [
                    BrickTag(uid: slabUID, name: "shelf slab", profileID: standing.id, pairedAt: clock.now),
                    BrickTag(uid: deskUID, name: "desk slab", profileID: work.id, pairedAt: clock.now)
                ],
                profiles: [standing, work]
            )
        )
        scheduler = failingScheduler ? FailingScheduler() : recording
        controller = BrickController(
            store: store,
            shielding: shielding,
            scheduler: scheduler,
            tagReader: tagReader,
            notifier: notifier,
            clock: clock
        )
    }

    func arm() async throws {
        try await controller.armReverse()
    }
}

@MainActor
@Suite("Controller — reverse mode")
struct ControllerReverseTests {

    @Test("arming puts the shield up and schedules nothing")
    func arming() async throws {
        let h = ReverseHarness()
        try await h.arm()
        #expect(h.shielding.events == [.applied(Data([0x07]))])
        #expect(h.recording.scheduled == nil)
        #expect(h.store.load().armedProfileID == h.standing.id)
        #expect(h.store.load().armedAt == h.clock.now)
    }

    @Test("a tag from another setup arms nothing")
    func armingNeedsItsOwnTag() async {
        let h = ReverseHarness()
        h.tagReader.stub(.success(deskUID))
        await #expect(throws: BrickError.wrongMode) {
            try await h.controller.armReverse()
        }
        #expect(h.shielding.events.isEmpty)
    }

    @Test("a permit schedules the shield's return before letting it down")
    func permitOrdersScheduleBeforeClear() async throws {
        let h = ReverseHarness()
        try await h.arm()
        try await h.controller.grantPermit()

        #expect(h.recording.scheduled?.kind == .permit)
        #expect(h.shielding.events == [.applied(Data([0x07])), .cleared])
        #expect(h.controller.permitsRemaining == 1)
        #expect(h.store.load().activeSession?.kind == .permit)
    }

    @Test("a permit that cannot be scheduled leaves the shield standing")
    func failedScheduleKeepsTheShieldUp() async throws {
        let h = ReverseHarness(failingScheduler: true)
        try await h.arm()
        await #expect(throws: FailingScheduler.Boom.self) {
            try await h.controller.grantPermit()
        }
        #expect(h.shielding.isShielded)
        #expect(h.store.load().activeSession == nil)
        // The refused permit cost nothing.
        #expect(h.controller.permitsRemaining == 2)
    }

    @Test("running out of permits says when the next one comes back")
    func quotaRunsOut() async throws {
        let h = ReverseHarness()
        try await h.arm()
        for _ in 0..<2 {
            try await h.controller.grantPermit()
            h.clock.advance(by: .brickMinutes(20))
            h.controller.reconcile()
        }
        #expect(h.controller.permitsRemaining == 0)
        await #expect(throws: BrickError.self) {
            try await h.controller.grantPermit()
        }
    }

    @Test("a permit that runs out puts the shield back by itself")
    func permitExpiryReapplies() async throws {
        let h = ReverseHarness()
        try await h.arm()
        try await h.controller.grantPermit()

        h.clock.advance(by: .brickMinimumSession)
        h.controller.reconcile()

        #expect(h.shielding.events.last == .applied(Data([0x07])))
        #expect(h.shielding.isShielded)
        #expect(h.store.load().activeSession == nil)
        #expect(h.store.load().armedProfileID == h.standing.id)
        #expect(h.store.load().history.last?.kind == .permit)
    }

    @Test("closing a permit early puts the shield back at once")
    func closingEarly() async throws {
        let h = ReverseHarness()
        try await h.arm()
        try await h.controller.grantPermit()
        h.clock.advance(by: .brickMinutes(3))
        h.controller.closePermitEarly()

        #expect(h.shielding.isShielded)
        #expect(h.store.load().history.last?.endReason == .closedEarly)
        #expect(h.store.load().activeSession == nil)
    }

    @Test("a standing shield is repaired on foreground, an open permit is not")
    func reapplyRespectsDirection() async throws {
        let h = ReverseHarness()
        try await h.arm()
        h.shielding.clear()
        #expect(h.controller.reapplyShieldIfNeeded())
        #expect(h.shielding.isShielded)

        try await h.controller.grantPermit()
        #expect(h.controller.reapplyShieldIfNeeded())
        #expect(!h.shielding.isShielded)
    }

    @Test("taking it down is refused before the minimum, without a scan")
    func disarmBeforeTheMinimum() async throws {
        let h = ReverseHarness(minimumDuration: .brickMinutes(60))
        try await h.arm()
        h.clock.advance(by: .brickMinutes(59))
        await #expect(throws: BrickError.tooEarlyToEnd(
            availableAt: h.store.load().armedAt!.addingTimeInterval(.brickMinutes(60))
        )) {
            try await h.controller.disarmReverse()
        }
        #expect(h.shielding.isShielded)
        #expect(h.store.load().armedProfileID != nil)
    }

    @Test("taking it down clears everything once the minimum has passed")
    func disarmAfterTheMinimum() async throws {
        let h = ReverseHarness(minimumDuration: .brickMinutes(60))
        try await h.arm()
        h.clock.advance(by: .brickMinutes(60))
        #expect(h.controller.canDisarm)
        try await h.controller.disarmReverse()

        #expect(!h.shielding.isShielded)
        #expect(h.store.load().armedProfileID == nil)
        #expect(h.store.load().armedAt == nil)
    }

    @Test("a block session refuses to start while a setup is standing")
    func blockSessionRefusedWhileArmed() async throws {
        let h = ReverseHarness(minimumDuration: 0)
        try await h.arm()
        h.tagReader.stub(.success(deskUID))
        await #expect(throws: BrickError.reverseArmed) {
            try await h.controller.startSessionByTap(duration: .brickMinutes(60))
        }
    }
}
