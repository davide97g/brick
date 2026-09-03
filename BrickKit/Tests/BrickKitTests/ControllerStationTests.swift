import Foundation
import Testing
@testable import BrickKit

private let deskUID = "04AAAAAAAAAA80"
private let hallUID = "04BBBBBBBBBB80"

@MainActor
private struct StationHarness {
    let store = InMemoryStateStore()
    let shielding = RecordingShielding()
    let scheduler = RecordingScheduler()
    let tagReader = StubTagReader(uid: deskUID)
    let notifier = RecordingNotifier()
    let clock = TestClock()
    let controller: BrickController
    let work: BlockProfile
    let night: BlockProfile

    /// Two stations, two profiles, and an exit route that crosses the flat.
    init(exitRoute: [String] = []) {
        work = BlockProfile(
            name: "Deep work",
            selectionData: Data([0x01]),
            appCount: 12,
            minimumDuration: .brickMinutes(30),
            exitRoute: exitRoute
        )
        night = BlockProfile(
            name: "Night",
            selectionData: Data([0x02]),
            appCount: 30,
            minimumDuration: .brickMinutes(360)
        )
        store.save(
            BrickState(
                tags: [
                    BrickTag(uid: deskUID, name: "desk slab", profileID: work.id, pairedAt: clock.now),
                    BrickTag(uid: hallUID, name: "hallway sticker", profileID: night.id, pairedAt: clock.now)
                ],
                profiles: [work, night]
            )
        )
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
@Suite("Controller — stations and routes")
struct ControllerStationTests {

    @Test("a second tag is added rather than replacing the first")
    func pairingASecondTag() async throws {
        let h = StationHarness()
        h.tagReader.stub(.success("04CCCCCCCCCC80"))
        try await h.controller.pairBrick(name: "kitchen tile", placeNote: "under the shelf")
        #expect(h.store.load().tags.count == 3)
        #expect(h.store.load().tags.last?.name == "kitchen tile")
    }

    @Test("pairing a tag that is already paired changes nothing")
    func duplicatePairing() async {
        let h = StationHarness()
        await #expect(throws: BrickError.alreadyPaired) {
            try await h.controller.pairBrick(name: "again")
        }
        #expect(h.store.load().tags.count == 2)
    }

    @Test("the tag tapped decides which profile is shielded")
    func tagPicksTheProfile() async throws {
        let h = StationHarness()
        h.tagReader.stub(.success(hallUID))
        try await h.controller.startSessionByTap(duration: .brickMinutes(480))
        #expect(h.shielding.events == [.applied(Data([0x02]))])
        #expect(h.store.load().activeSession?.profileID == h.night.id)
        #expect(h.controller.activeProfile.name == "Night")
    }

    @Test("a session under a long minimum stays shut at the short one")
    func minimumFollowsTheProfile() async throws {
        let h = StationHarness()
        h.tagReader.stub(.success(hallUID))
        try await h.controller.startSessionByTap(duration: .brickMinutes(480))
        h.clock.advance(by: .brickMinutes(45))
        #expect(!h.controller.canEndWithKey)
        h.clock.advance(by: .brickMinutes(315))
        #expect(h.controller.canEndWithKey)
    }

    @Test("the first step of a route does not lift the shield")
    func firstStepHoldsTheShield() async throws {
        let h = StationHarness(exitRoute: [deskUID, hallUID])
        try await h.controller.startSessionByTap(duration: .brickMinutes(90))
        h.clock.advance(by: .brickMinutes(30))

        let outcome = try await h.controller.endSessionByTap()
        guard case .advanced(_, let remaining, _) = outcome else {
            Issue.record("expected the walk to advance"); return
        }
        #expect(remaining == 1)
        #expect(h.shielding.isShielded)
        #expect(h.store.load().activeSession != nil)
        #expect(h.store.load().routeProgress?.stepsDone == 1)
        #expect(h.controller.nextRouteTag?.name == "hallway sticker")
    }

    @Test("the last step clears the shield and files the session")
    func lastStepEnds() async throws {
        let h = StationHarness(exitRoute: [deskUID, hallUID])
        try await h.controller.startSessionByTap(duration: .brickMinutes(90))
        h.clock.advance(by: .brickMinutes(30))
        _ = try await h.controller.endSessionByTap()

        h.tagReader.stub(.success(hallUID))
        h.clock.advance(by: .brickMinutes(2))
        _ = try await h.controller.endSessionByTap()

        #expect(!h.shielding.isShielded)
        #expect(h.scheduler.cancelCount == 1)
        #expect(h.store.load().activeSession == nil)
        #expect(h.store.load().routeProgress == nil)
        #expect(h.store.load().history.last?.endReason == .tappedBrick)
    }

    @Test("a wrong tag mid-walk costs the progress and leaves the shield up")
    func wrongTagMidWalk() async throws {
        let h = StationHarness(exitRoute: [deskUID, hallUID])
        try await h.controller.startSessionByTap(duration: .brickMinutes(90))
        h.clock.advance(by: .brickMinutes(30))
        _ = try await h.controller.endSessionByTap()

        h.tagReader.stub(.success("04CCCCCCCCCC80"))
        await #expect(throws: BrickError.wrongTag(scanned: "04CCCCCCCCCC80")) {
            _ = try await h.controller.endSessionByTap()
        }
        #expect(h.shielding.isShielded)
        #expect(h.store.load().routeProgress == nil)
    }

    @Test("an abandoned walk is worth nothing when it resumes too late")
    func abandonedWalkResets() async throws {
        let h = StationHarness(exitRoute: [deskUID, hallUID])
        try await h.controller.startSessionByTap(duration: .brickMinutes(90))
        h.clock.advance(by: .brickMinutes(30))
        _ = try await h.controller.endSessionByTap()

        h.clock.advance(by: .brickMinutes(11))
        h.tagReader.stub(.success(hallUID))
        await #expect(throws: BrickError.wrongTag(scanned: hallUID)) {
            _ = try await h.controller.endSessionByTap()
        }
        #expect(h.shielding.isShielded)
    }

    @Test("starting clears whatever walk was left behind by the last session")
    func startingClearsStaleProgress() async throws {
        let h = StationHarness(exitRoute: [deskUID, hallUID])
        h.store.mutate {
            $0.routeProgress = RouteProgress(sessionID: UUID(), stepsDone: 1, lastTapAt: h.clock.now)
        }
        try await h.controller.startSessionByTap(duration: .brickMinutes(90))
        #expect(h.store.load().routeProgress == nil)
    }

    @Test("unpairing a station takes it out of every route with it")
    func unpairingCleansRoutes() async throws {
        let h = StationHarness(exitRoute: [deskUID, hallUID])
        try h.controller.unpairTag(uid: hallUID)
        #expect(h.store.load().tags.count == 1)
        #expect(h.store.load().profiles.first?.exitRoute == [deskUID])
    }

    @Test("a route cannot be rewritten while its own session is running")
    func routesAreFrozenMidSession() async throws {
        let h = StationHarness(exitRoute: [deskUID, hallUID])
        try await h.controller.startSessionByTap(duration: .brickMinutes(90))
        #expect(throws: BrickError.sessionAlreadyActive) {
            try h.controller.setExitRoute([deskUID], forProfile: h.work.id)
        }
        #expect(throws: BrickError.sessionAlreadyActive) {
            try h.controller.removeProfile(id: h.work.id)
        }
    }

    @Test("the shield's way-out line names the next step, not the last")
    func keyDescriptionFollowsTheWalk() async throws {
        let h = StationHarness(exitRoute: [deskUID, hallUID])
        h.controller.updateTag(uid: hallUID, placeNote: "by the front door")
        try await h.controller.startSessionByTap(duration: .brickMinutes(90))
        h.clock.advance(by: .brickMinutes(30))
        _ = try await h.controller.endSessionByTap()
        #expect(h.controller.keyDescription == "1 tap left. Next: hallway sticker, by the front door.")
    }

    @Test("a one-tap exit still just says where the brick is")
    func keyDescriptionForASingleTap() async throws {
        let h = StationHarness()
        h.controller.updateTag(uid: deskUID, placeNote: "on your desk")
        try await h.controller.startSessionByTap(duration: .brickMinutes(90))
        #expect(h.controller.keyDescription == "desk slab is on your desk.")
    }
}
