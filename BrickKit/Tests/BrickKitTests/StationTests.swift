import Foundation
import Testing
@testable import BrickKit

private let t0 = Date(timeIntervalSince1970: 1_760_000_000)
private let deskUID = "04AAAAAAAAAA80"
private let bedUID = "04BBBBBBBBBB80"

/// Two tags, two occasions: the tag decides which one a tap starts.
private func stationState() -> BrickState {
    let work = BlockProfile(
        name: "Deep work",
        selectionData: Data([0x01]),
        appCount: 12,
        defaultDuration: .brickMinutes(90),
        minimumDuration: .brickMinutes(45)
    )
    let night = BlockProfile(
        name: "Night",
        selectionData: Data([0x02]),
        appCount: 30,
        defaultDuration: .brickMinutes(480),
        minimumDuration: .brickMinutes(360)
    )
    return BrickState(
        tags: [
            BrickTag(uid: deskUID, name: "desk slab", placeNote: "on your desk", profileID: work.id, pairedAt: t0),
            BrickTag(uid: bedUID, name: "bedside", placeNote: "by the bed", profileID: night.id, pairedAt: t0)
        ],
        profiles: [work, night]
    )
}

@Suite("Stations")
struct StationTests {

    @Test("the tag decides which profile a tap starts")
    func tagPicksProfile() throws {
        let state = stationState()
        let night = try #require(state.profiles.last)

        let session = try SessionEngine.validateStartByTap(
            state: state, scannedUID: bedUID, duration: .brickMinutes(480), now: t0
        )
        #expect(session.profileID == night.id)
        #expect(session.startedByTag == bedUID)
    }

    @Test("the minimum is the profile's own, not the first one's")
    func minimumIsPerProfile() throws {
        var state = stationState()
        state.activeSession = try SessionEngine.validateStartByTap(
            state: state, scannedUID: bedUID, duration: .brickMinutes(480), now: t0
        )
        let opensAt = t0.addingTimeInterval(.brickMinutes(360))
        #expect(throws: BrickError.tooEarlyToEnd(availableAt: opensAt)) {
            // 45 minutes is enough for deep work and nowhere near enough here.
            try SessionEngine.validateEnd(state: state, now: t0.addingTimeInterval(.brickMinutes(45)))
        }
        #expect(throws: Never.self) {
            try SessionEngine.validateEnd(state: state, now: opensAt)
        }
    }

    @Test("an unpaired tag starts nothing")
    func foreignTagStartsNothing() {
        #expect(throws: BrickError.wrongTag(scanned: "DEADBEEF")) {
            try SessionEngine.validateStartByTap(
                state: stationState(), scannedUID: "DEADBEEF", duration: .brickMinutes(60), now: t0
            )
        }
    }

    @Test("a tag whose profile has nothing selected refuses to start")
    func emptyProfileRefuses() {
        var state = stationState()
        state.profiles[1] = BlockProfile(id: state.profiles[1].id, name: "Night")
        #expect(throws: BrickError.emptyBlocklist) {
            try SessionEngine.validateStartByTap(
                state: state, scannedUID: bedUID, duration: .brickMinutes(60), now: t0
            )
        }
    }

    @Test("a tag with no profile of its own falls back to the first")
    func unassignedTagUsesTheFirstProfile() throws {
        var state = stationState()
        state.tags[1].profileID = nil
        let session = try SessionEngine.validateStartByTap(
            state: state, scannedUID: bedUID, duration: .brickMinutes(60), now: t0
        )
        #expect(session.profileID == state.profiles.first?.id)
    }

    @Test("the 15-minute floor holds whichever station starts it")
    func floorHolds() {
        #expect(throws: BrickError.durationTooShort(minimum: .brickMinimumSession)) {
            try SessionEngine.validateStartByTap(
                state: stationState(), scannedUID: deskUID, duration: .brickMinutes(14), now: t0
            )
        }
    }

    @Test("one session at a time, whichever station is tapped next")
    func oneSessionAtATime() throws {
        var state = stationState()
        state.activeSession = try SessionEngine.validateStartByTap(
            state: state, scannedUID: deskUID, duration: .brickMinutes(90), now: t0
        )
        #expect(throws: BrickError.sessionAlreadyActive) {
            try SessionEngine.validateStartByTap(
                state: state, scannedUID: bedUID, duration: .brickMinutes(480), now: t0
            )
        }
    }

    @Test("the same tag paired twice is refused")
    func noDuplicateTags() {
        let state = stationState()
        #expect(state.tag(withUID: "04aaaaaaaaaa80") != nil)
        #expect(state.tags.count == 2)
    }
}
