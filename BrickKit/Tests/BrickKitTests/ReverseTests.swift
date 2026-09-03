import Foundation
import Testing
@testable import BrickKit

private let t0 = Date(timeIntervalSince1970: 1_760_000_000)
private let slabUID = "04AAAAAAAAAA80"
private let otherUID = "04BBBBBBBBBB80"

private func reverseState(
    minimumDuration: TimeInterval = .brickMinutes(60),
    permitAllowance: Int = 3,
    permits: EmergencyLog = EmergencyLog(),
    armed: Bool = false,
    armedAt: Date = t0
) -> BrickState {
    let standing = BlockProfile(
        name: "Doomscroll",
        selectionData: Data([0x07]),
        appCount: 5,
        minimumDuration: minimumDuration,
        mode: .reverse,
        permitAllowance: permitAllowance
    )
    let work = BlockProfile(name: "Deep work", selectionData: Data([0x01]), appCount: 3)
    return BrickState(
        tags: [
            BrickTag(uid: slabUID, name: "shelf slab", profileID: standing.id, pairedAt: t0),
            BrickTag(uid: otherUID, name: "desk slab", profileID: work.id, pairedAt: t0)
        ],
        profiles: [standing, work],
        armedProfileID: armed ? standing.id : nil,
        armedAt: armed ? armedAt : nil,
        permits: permits
    )
}

@Suite("Reverse mode")
struct ReverseTests {

    @Test("arming a reverse setup stands the shield up with nothing scheduled")
    func arming() throws {
        var state = reverseState()
        let standing = state.profiles[0]
        try SessionEngine.validateArm(state: state, profile: standing, now: t0)
        SessionEngine.arm(&state, profile: standing, at: t0)
        #expect(state.armedProfileID == standing.id)
        #expect(state.armedAt == t0)
        #expect(state.activeSession == nil)
    }

    @Test("a block setup cannot be armed, and a reverse setup cannot be started")
    func modesDoNotCross() {
        let state = reverseState()
        #expect(throws: BrickError.wrongMode) {
            try SessionEngine.validateArm(state: state, profile: state.profiles[1], now: t0)
        }
        #expect(throws: BrickError.wrongMode) {
            try SessionEngine.validateStart(
                state: state, profile: state.profiles[0], startedByTag: nil,
                duration: .brickMinutes(60), now: t0
            )
        }
    }

    @Test("nothing else starts while a setup is standing")
    func armedBlocksEverythingElse() {
        let state = reverseState(armed: true)
        #expect(throws: BrickError.reverseArmed) {
            try SessionEngine.validateStart(
                state: state, profile: state.profiles[1], startedByTag: nil,
                duration: .brickMinutes(60), now: t0
            )
        }
    }

    @Test("a permit needs no gate: the walk to the tag was the cost")
    func permitHasNoGate() throws {
        let state = reverseState(armed: true)
        let permit = try SessionEngine.validatePermit(
            state: state, scannedUID: slabUID, now: t0.addingTimeInterval(30)
        )
        #expect(permit.kind == .permit)
        #expect(permit.plannedEnd == t0.addingTimeInterval(30 + .brickMinimumSession))
    }

    @Test("a permit is refused to a tag that belongs to another setup")
    func permitNeedsTheRightTag() {
        let state = reverseState(armed: true)
        #expect(throws: BrickError.wrongTag(scanned: otherUID)) {
            try SessionEngine.validatePermit(state: state, scannedUID: otherUID, now: t0)
        }
    }

    @Test("the 15-minute floor holds in this direction too")
    func permitFloor() throws {
        let state = reverseState(armed: true)
        let permit = try SessionEngine.validatePermit(
            state: state, scannedUID: slabUID, duration: .brickMinutes(2), now: t0
        )
        #expect(permit.plannedDuration == .brickMinimumSession)
    }

    @Test("permits are counted, and running out says when the next one comes back")
    func permitQuota() throws {
        var state = reverseState(armed: true)
        for index in 0..<3 {
            let at = t0.addingTimeInterval(Double(index) * 3600)
            let permit = try SessionEngine.validatePermit(state: state, scannedUID: slabUID, now: at)
            SessionEngine.openPermit(&state, permit, at: at)
            SessionEngine.close(&state, reason: .scheduled, at: at.addingTimeInterval(900))
        }
        #expect(SessionEngine.permitsRemaining(state: state, now: t0.addingTimeInterval(3 * 3600)) == 0)
        #expect(throws: BrickError.permitQuotaExhausted(
            replenishesAt: t0.addingTimeInterval(.brickPermitWindow)
        )) {
            try SessionEngine.validatePermit(
                state: state, scannedUID: slabUID, now: t0.addingTimeInterval(3 * 3600)
            )
        }
    }

    @Test("the quota rolls: yesterday's openings don't count against today")
    func permitQuotaRolls() throws {
        let yesterday = EmergencyLog(uses: [
            t0.addingTimeInterval(-.brickPermitWindow - 60),
            t0.addingTimeInterval(-.brickPermitWindow - 120),
            t0.addingTimeInterval(-.brickPermitWindow - 180)
        ])
        let state = reverseState(permits: yesterday, armed: true)
        #expect(SessionEngine.permitsRemaining(state: state, now: t0) == 3)
        #expect(throws: Never.self) {
            try SessionEngine.validatePermit(state: state, scannedUID: slabUID, now: t0)
        }
    }

    @Test("an emergency buys a permit past the quota, and costs an emergency")
    func emergencyPermit() throws {
        var state = reverseState(
            permits: EmergencyLog(uses: [t0, t0, t0]),
            armed: true
        )
        let permit = try SessionEngine.validatePermit(
            state: state, scannedUID: slabUID, spendingEmergency: true, now: t0
        )
        #expect(permit.grantedByEmergency)
        SessionEngine.openPermit(&state, permit, at: t0)
        #expect(state.emergency.remainingAllowance(at: t0) == EmergencyLog.allowance - 1)
        #expect(SessionEngine.permitsRemaining(state: state, now: t0) == 0)
    }

    @Test("a permit ends by putting the shield back, a session by clearing it")
    func expiryDirection() throws {
        var state = reverseState(armed: true)
        let permit = try SessionEngine.validatePermit(state: state, scannedUID: slabUID, now: t0)
        SessionEngine.openPermit(&state, permit, at: t0)
        #expect(SessionEngine.expiryAction(state: state) == .reapply(selectionData: Data([0x07])))

        var blocking = reverseState()
        blocking.activeSession = try SessionEngine.validateStart(
            state: blocking, profile: blocking.profiles[1], startedByTag: nil,
            duration: .brickMinutes(60), now: t0
        )
        #expect(SessionEngine.expiryAction(state: blocking) == .clear)
    }

    @Test("taking it down is behind the same minimum a session's gate uses")
    func disarmIsGated() {
        let state = reverseState(minimumDuration: .brickMinutes(60), armed: true, armedAt: t0)
        let opensAt = t0.addingTimeInterval(.brickMinutes(60))
        #expect(SessionEngine.disarmOpensAt(state: state) == opensAt)
        #expect(throws: BrickError.tooEarlyToEnd(availableAt: opensAt)) {
            try SessionEngine.validateDisarm(
                state: state, scannedUID: slabUID, now: opensAt.addingTimeInterval(-1)
            )
        }
        #expect(throws: Never.self) {
            try SessionEngine.validateDisarm(state: state, scannedUID: slabUID, now: opensAt)
        }
    }

    @Test("taking it down needs a tag of the setup that is standing")
    func disarmNeedsTheRightTag() {
        let state = reverseState(minimumDuration: 0, armed: true)
        #expect(throws: BrickError.wrongTag(scanned: otherUID)) {
            try SessionEngine.validateDisarm(state: state, scannedUID: otherUID, now: t0)
        }
    }

    @Test("nothing to take down when nothing is standing")
    func disarmWithoutArming() {
        #expect(throws: BrickError.notArmed) {
            try SessionEngine.validateDisarm(state: reverseState(), scannedUID: slabUID, now: t0)
        }
        #expect(throws: BrickError.notArmed) {
            try SessionEngine.validatePermit(state: reverseState(), scannedUID: slabUID, now: t0)
        }
    }
}
