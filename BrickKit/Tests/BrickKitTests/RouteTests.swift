import Foundation
import Testing
@testable import BrickKit

private let t0 = Date(timeIntervalSince1970: 1_760_000_000)
private let desk = "04AAAAAAAAAA80"
private let hall = "04BBBBBBBBBB80"
private let door = "04CCCCCCCCCC80"

private func routedState(
    route: [String],
    minimumDuration: TimeInterval = .brickMinutes(30),
    routeWindow: TimeInterval = .brickRouteWindow,
    startedByTag: String? = desk,
    progress: RouteProgress? = nil,
    sessionLength: TimeInterval = .brickMinutes(90)
) -> BrickState {
    let profile = BlockProfile(
        name: "Deep work",
        selectionData: Data([0x01]),
        appCount: 4,
        minimumDuration: minimumDuration,
        exitRoute: route,
        routeWindow: routeWindow
    )
    let session = Session(
        startedAt: t0,
        plannedEnd: t0.addingTimeInterval(sessionLength),
        profileID: profile.id,
        startedByTag: startedByTag
    )
    return BrickState(
        tags: [desk, hall, door].map {
            BrickTag(uid: $0, name: $0 == desk ? "desk slab" : "sticker", profileID: profile.id, pairedAt: t0)
        },
        profiles: [profile],
        activeSession: session,
        routeProgress: progress
    )
}

private let open = t0.addingTimeInterval(.brickMinutes(30))

@Suite("Exit routes")
struct RouteTests {

    @Test("a profile with no route exits by the tag that started it")
    func emptyRouteIsTheStartingTag() throws {
        let state = routedState(route: [])
        let session = try #require(state.activeSession)
        #expect(SessionEngine.exitRoute(for: session, in: state) == [desk])
    }

    @Test("the gate comes first: a correct step before the minimum earns nothing")
    func gateBeforeProgress() throws {
        let state = routedState(route: [desk, hall, door])
        #expect(throws: BrickError.tooEarlyToEnd(availableAt: open)) {
            try SessionEngine.validateRouteTap(state: state, scannedUID: desk, now: open.addingTimeInterval(-1))
        }
        #expect(state.routeProgress == nil)
    }

    @Test("walking the route in order ends the session on the last tap")
    func walkingInOrderCompletes() throws {
        var state = routedState(route: [desk, hall, door])

        let first = try SessionEngine.validateRouteTap(state: state, scannedUID: desk, now: open)
        guard case .advanced(_, let remainingAfterFirst, let next) = first else {
            Issue.record("expected the walk to advance"); return
        }
        #expect(remainingAfterFirst == 2)
        #expect(next == hall)
        SessionEngine.apply(first, to: &state)

        let second = try SessionEngine.validateRouteTap(
            state: state, scannedUID: hall, now: open.addingTimeInterval(60)
        )
        guard case .advanced(_, let remainingAfterSecond, let nextNext) = second else {
            Issue.record("expected the walk to advance"); return
        }
        #expect(remainingAfterSecond == 1)
        #expect(nextNext == door)
        SessionEngine.apply(second, to: &state)

        let last = try SessionEngine.validateRouteTap(
            state: state, scannedUID: door, now: open.addingTimeInterval(120)
        )
        guard case .completed(let session) = last else {
            Issue.record("expected the walk to complete"); return
        }
        #expect(session.id == state.activeSession?.id)
    }

    @Test("tapping the last tag first is refused: the route is an order, not a set")
    func orderMatters() throws {
        let state = routedState(route: [desk, hall, door])
        let outcome = try SessionEngine.validateRouteTap(state: state, scannedUID: door, now: open)
        #expect(outcome == .wrongTag(scanned: door, expectedUID: desk))
    }

    @Test("a wrong tag costs the whole walk")
    func wrongTagResetsProgress() throws {
        var state = routedState(route: [desk, hall, door])
        let first = try SessionEngine.validateRouteTap(state: state, scannedUID: desk, now: open)
        SessionEngine.apply(first, to: &state)
        #expect(state.routeProgress?.stepsDone == 1)

        let wrong = try SessionEngine.validateRouteTap(
            state: state, scannedUID: door, now: open.addingTimeInterval(30)
        )
        #expect(wrong == .wrongTag(scanned: door, expectedUID: hall))
        SessionEngine.apply(wrong, to: &state)
        #expect(state.routeProgress == nil)
    }

    @Test("a walk abandoned for longer than the window starts again")
    func staleProgressResets() throws {
        var walked = routedState(route: [desk, hall, door], routeWindow: .brickMinutes(10))
        let first = try SessionEngine.validateRouteTap(state: walked, scannedUID: desk, now: open)
        SessionEngine.apply(first, to: &walked)

        // Eleven minutes later the second step is no longer the second step.
        let late = open.addingTimeInterval(.brickMinutes(11))
        let outcome = try SessionEngine.validateRouteTap(state: walked, scannedUID: hall, now: late)
        #expect(outcome == .wrongTag(scanned: hall, expectedUID: desk))
    }

    @Test("progress from a previous session counts for nothing")
    func progressIsPerSession() throws {
        var state = routedState(route: [desk, hall, door])
        state.routeProgress = RouteProgress(sessionID: UUID(), stepsDone: 2, lastTapAt: open)
        let outcome = try SessionEngine.validateRouteTap(state: state, scannedUID: door, now: open)
        #expect(outcome == .wrongTag(scanned: door, expectedUID: desk))
    }

    @Test("cross-key: the tag that started it cannot be the tag that ends it")
    func crossKey() throws {
        let state = routedState(route: [hall], startedByTag: desk)
        #expect(try SessionEngine.validateRouteTap(state: state, scannedUID: desk, now: open)
            == .wrongTag(scanned: desk, expectedUID: hall))
        guard case .completed = try SessionEngine.validateRouteTap(state: state, scannedUID: hall, now: open) else {
            Issue.record("the kitchen tile is the key"); return
        }
    }

    @Test("an unpaired tag is refused on identity, whatever the clock says")
    func unknownTagIsRefusedBeforeTheGate() throws {
        let state = routedState(route: [desk, hall, door])
        let outcome = try SessionEngine.validateRouteTap(
            state: state, scannedUID: "DEADBEEF", now: t0
        )
        #expect(outcome == .wrongTag(scanned: "DEADBEEF", expectedUID: desk))
    }

    @Test("a one-tap exit behaves exactly as the single-brick product did")
    func oneStepRouteIsTheOldBehaviour() throws {
        let state = routedState(route: [])
        #expect(throws: BrickError.tooEarlyToEnd(availableAt: open)) {
            try SessionEngine.validateTapEnd(state: state, scannedUID: desk, now: open.addingTimeInterval(-1))
        }
        #expect(throws: Never.self) {
            try SessionEngine.validateTapEnd(state: state, scannedUID: desk, now: open)
        }
    }

    @Test("validateTapEnd says how much walk is left rather than ending early")
    func tapEndReportsRemainingSteps() {
        let state = routedState(route: [desk, hall, door])
        #expect(throws: BrickError.routeIncomplete(remaining: 2, next: "sticker")) {
            try SessionEngine.validateTapEnd(state: state, scannedUID: desk, now: open)
        }
    }

    @Test("closing a session clears any half-walked route behind it")
    func closingClearsProgress() {
        var state = routedState(route: [desk, hall, door])
        state.routeProgress = RouteProgress(
            sessionID: state.activeSession!.id, stepsDone: 2, lastTapAt: open
        )
        SessionEngine.close(&state, reason: .emergency, at: open)
        #expect(state.routeProgress == nil)
    }

    @Test("the route is still gated by the planned end, never past it")
    func neverGatesPastThePlannedEnd() throws {
        let state = routedState(
            route: [desk, hall],
            minimumDuration: .brickMinutes(45),
            sessionLength: .brickMinutes(20)
        )
        guard case .advanced = try SessionEngine.validateRouteTap(
            state: state, scannedUID: desk, now: t0.addingTimeInterval(.brickMinutes(20))
        ) else {
            Issue.record("the gate must clamp to the planned end"); return
        }
    }
}
