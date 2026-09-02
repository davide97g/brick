import Foundation
import Testing
@testable import BrickKit

private let t0 = Date(timeIntervalSince1970: 1_760_000_000)

private func pairedState(
    minimumDuration: TimeInterval = .brickMinutes(30),
    activeSession: Session? = nil,
    emergency: EmergencyLog = EmergencyLog()
) -> BrickState {
    BrickState(
        tag: BrickTag(uid: "04A1B2C3D4E580", pairedAt: t0),
        blocklist: BlocklistConfig(
            selectionData: Data([0x01]),
            appCount: 4,
            minimumDuration: minimumDuration
        ),
        activeSession: activeSession,
        emergency: emergency
    )
}

@Suite("Starting a session")
struct StartTests {
    @Test("requires a paired brick")
    func requiresPairing() {
        var state = pairedState()
        state.tag = nil
        #expect(throws: BrickError.notPaired) {
            try SessionEngine.validateStart(state: state, duration: .brickMinutes(60), now: t0)
        }
    }

    @Test("accepts biometrics in place of a brick")
    func biometricsStandInForABrick() throws {
        var state = pairedState()
        state.tag = nil
        state.unlock = .biometric
        let session = try SessionEngine.validateStart(
            state: state, duration: .brickMinutes(60), now: t0
        )
        #expect(session.plannedEnd == t0.addingTimeInterval(.brickMinutes(60)))
    }

    @Test("requires a non-empty blocklist")
    func requiresBlocklist() {
        var state = pairedState()
        state.blocklist = BlocklistConfig()
        #expect(throws: BrickError.emptyBlocklist) {
            try SessionEngine.validateStart(state: state, duration: .brickMinutes(60), now: t0)
        }
    }

    @Test("refuses durations below the DeviceActivity 15-minute floor")
    func refusesShortDurations() {
        #expect(throws: BrickError.durationTooShort(minimum: .brickMinimumSession)) {
            try SessionEngine.validateStart(
                state: pairedState(), duration: .brickMinutes(14), now: t0
            )
        }
        #expect(throws: Never.self) {
            try SessionEngine.validateStart(
                state: pairedState(), duration: .brickMinutes(15), now: t0
            )
        }
    }

    @Test("refuses a second concurrent session")
    func refusesConcurrent() {
        let running = Session(startedAt: t0, plannedEnd: t0.addingTimeInterval(.brickMinutes(60)))
        #expect(throws: BrickError.sessionAlreadyActive) {
            try SessionEngine.validateStart(
                state: pairedState(activeSession: running),
                duration: .brickMinutes(60),
                now: t0
            )
        }
    }

    @Test("plans the end from the start time")
    func plansEnd() throws {
        let session = try SessionEngine.validateStart(
            state: pairedState(), duration: .brickMinutes(90), now: t0
        )
        #expect(session.plannedEnd == t0.addingTimeInterval(.brickMinutes(90)))
        #expect(session.isActive)
    }
}

@Suite("Ending with the brick")
struct TapEndTests {
    private let running = Session(startedAt: t0, plannedEnd: t0.addingTimeInterval(.brickMinutes(90)))

    @Test("rejects a tag that isn't the paired brick")
    func rejectsWrongTag() {
        #expect(throws: BrickError.wrongTag(scanned: "DEADBEEF")) {
            try SessionEngine.validateTapEnd(
                state: pairedState(activeSession: running), scannedUID: "DEADBEEF", now: t0
            )
        }
    }

    @Test("matches the paired UID case-insensitively")
    func matchesCaseInsensitively() throws {
        let state = pairedState(activeSession: running)
        _ = try SessionEngine.validateTapEnd(
            state: state,
            scannedUID: "04a1b2c3d4e580",
            now: t0.addingTimeInterval(.brickMinutes(30))
        )
    }

    @Test("refuses before the minimum duration, even at the brick")
    func refusesEarly() {
        let state = pairedState(minimumDuration: .brickMinutes(30), activeSession: running)
        let opensAt = t0.addingTimeInterval(.brickMinutes(30))
        #expect(throws: BrickError.tooEarlyToEnd(availableAt: opensAt)) {
            try SessionEngine.validateTapEnd(
                state: state,
                scannedUID: "04A1B2C3D4E580",
                now: t0.addingTimeInterval(.brickMinutes(29))
            )
        }
    }

    @Test("allows exactly at the minimum duration")
    func allowsAtBoundary() throws {
        let state = pairedState(minimumDuration: .brickMinutes(30), activeSession: running)
        _ = try SessionEngine.validateTapEnd(
            state: state,
            scannedUID: "04A1B2C3D4E580",
            now: t0.addingTimeInterval(.brickMinutes(30))
        )
    }

    @Test("never gates the exit past the planned end")
    func clampsToPlannedEnd() throws {
        let short = Session(startedAt: t0, plannedEnd: t0.addingTimeInterval(.brickMinutes(20)))
        let state = pairedState(minimumDuration: .brickMinutes(45), activeSession: short)
        _ = try SessionEngine.validateTapEnd(
            state: state,
            scannedUID: "04A1B2C3D4E580",
            now: t0.addingTimeInterval(.brickMinutes(20))
        )
    }

    @Test("refuses when nothing is running")
    func refusesIdle() {
        #expect(throws: BrickError.noActiveSession) {
            try SessionEngine.validateTapEnd(
                state: pairedState(), scannedUID: "04A1B2C3D4E580", now: t0
            )
        }
    }
}

@Suite("Emergency unlocks")
struct EmergencyTests {
    private let running = Session(startedAt: t0, plannedEnd: t0.addingTimeInterval(.brickMinutes(90)))

    @Test("allowed while quota remains, regardless of elapsed time")
    func allowedEarly() throws {
        let state = pairedState(activeSession: running)
        _ = try SessionEngine.validateEmergency(state: state, now: t0.addingTimeInterval(60))
    }

    @Test("blocked once the rolling allowance is spent")
    func blockedWhenExhausted() {
        let used = EmergencyLog(uses: [
            t0.addingTimeInterval(-.brickMinutes(10)),
            t0.addingTimeInterval(-.brickMinutes(20)),
            t0.addingTimeInterval(-.brickMinutes(30))
        ])
        let state = pairedState(activeSession: running, emergency: used)
        #expect(throws: BrickError.emergencyQuotaExhausted(
            replenishesAt: t0.addingTimeInterval(-.brickMinutes(30)).addingTimeInterval(EmergencyLog.window)
        )) {
            try SessionEngine.validateEmergency(state: state, now: t0)
        }
    }

    @Test("uses outside the 7-day window don't count")
    func windowExpires() throws {
        let stale = EmergencyLog(uses: [
            t0.addingTimeInterval(-EmergencyLog.window - 1),
            t0.addingTimeInterval(-EmergencyLog.window - 2),
            t0.addingTimeInterval(-EmergencyLog.window - 3)
        ])
        let state = pairedState(activeSession: running, emergency: stale)
        #expect(state.emergency.remainingAllowance(at: t0) == EmergencyLog.allowance)
        _ = try SessionEngine.validateEmergency(state: state, now: t0)
    }

    @Test("spending one decrements the allowance")
    func spendingDecrements() {
        var state = pairedState(activeSession: running)
        SessionEngine.close(&state, reason: .emergency, at: t0.addingTimeInterval(60))
        #expect(state.emergency.remainingAllowance(at: t0.addingTimeInterval(60)) == EmergencyLog.allowance - 1)
    }
}

@Suite("Reconciliation and closing")
struct ReconcileTests {
    @Test("an expired session is detected")
    func detectsExpiry() {
        let session = Session(startedAt: t0, plannedEnd: t0.addingTimeInterval(.brickMinutes(30)))
        let state = pairedState(activeSession: session)
        #expect(!SessionEngine.needsExpiry(state: state, now: t0.addingTimeInterval(.brickMinutes(29))))
        #expect(SessionEngine.needsExpiry(state: state, now: t0.addingTimeInterval(.brickMinutes(30))))
    }

    @Test("closing files the session in history exactly once")
    func closeIsIdempotent() {
        let session = Session(startedAt: t0, plannedEnd: t0.addingTimeInterval(.brickMinutes(30)))
        var state = pairedState(activeSession: session)
        SessionEngine.close(&state, reason: .scheduled, at: session.plannedEnd)
        SessionEngine.close(&state, reason: .scheduled, at: session.plannedEnd)
        #expect(state.activeSession == nil)
        #expect(state.history.count == 1)
        #expect(state.history[0].endReason == .scheduled)
        #expect(state.history[0].endedAt == session.plannedEnd)
    }

    @Test("only emergency ends spend allowance")
    func onlyEmergencySpends() {
        let session = Session(startedAt: t0, plannedEnd: t0.addingTimeInterval(.brickMinutes(30)))
        var state = pairedState(activeSession: session)
        SessionEngine.close(&state, reason: .tappedBrick, at: t0.addingTimeInterval(.brickMinutes(30)))
        #expect(state.emergency.uses.isEmpty)
    }
}

@Suite("History")
struct HistoryTests {
    @Test("history is capped and keeps the most recent sessions")
    func historyIsCapped() {
        var state = pairedState()
        for index in 0..<(BrickState.historyLimit + 25) {
            let start = t0.addingTimeInterval(Double(index) * 3600)
            state.activeSession = Session(startedAt: start, plannedEnd: start.addingTimeInterval(1800))
            SessionEngine.close(&state, reason: .scheduled, at: start.addingTimeInterval(1800))
        }
        #expect(state.history.count == BrickState.historyLimit)
        let expectedFirst = t0.addingTimeInterval(Double(25) * 3600)
        #expect(state.history.first?.startedAt == expectedFirst)
    }
}

@Suite("Ending without a brick")
struct BiometricEndTests {
    private func biometricState(minimumDuration: TimeInterval, session: Session) -> BrickState {
        var state = pairedState(minimumDuration: minimumDuration, activeSession: session)
        state.tag = nil
        state.unlock = .biometric
        return state
    }

    @Test("refuses before the minimum duration, exactly as the brick does")
    func refusesBeforeMinimum() {
        let session = Session(startedAt: t0, plannedEnd: t0.addingTimeInterval(.brickMinutes(90)))
        let state = biometricState(minimumDuration: .brickMinutes(30), session: session)
        #expect(throws: BrickError.tooEarlyToEnd(availableAt: t0.addingTimeInterval(.brickMinutes(30)))) {
            try SessionEngine.validateEnd(state: state, now: t0.addingTimeInterval(.brickMinutes(29)))
        }
    }

    @Test("opens exactly at the minimum")
    func opensAtTheMinimum() throws {
        let session = Session(startedAt: t0, plannedEnd: t0.addingTimeInterval(.brickMinutes(90)))
        let state = biometricState(minimumDuration: .brickMinutes(30), session: session)
        let ended = try SessionEngine.validateEnd(
            state: state, now: t0.addingTimeInterval(.brickMinutes(30))
        )
        #expect(ended.id == session.id)
    }

    @Test("refuses when nothing is running")
    func refusesWithoutASession() {
        var state = pairedState()
        state.tag = nil
        state.unlock = .biometric
        #expect(throws: BrickError.noActiveSession) {
            try SessionEngine.validateEnd(state: state, now: t0)
        }
    }
}
