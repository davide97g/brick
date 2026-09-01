import Foundation
import Testing
@testable import BrickKit

@Suite("Persistence")
struct StateStoreTests {
    @Test("state survives a round trip through the shared file")
    func roundTrip() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("brick-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = FileStateStore(url: url)
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        var state = BrickState(
            tag: BrickTag(uid: "04A1B2C3D4E580", placeNote: "on your desk", pairedAt: start),
            blocklist: BlocklistConfig(selectionData: Data([0xAB]), appCount: 7),
            activeSession: Session(startedAt: start, plannedEnd: start.addingTimeInterval(3600))
        )
        state.emergency.record(at: start)
        store.save(state)

        #expect(FileStateStore(url: url).load() == state)
    }

    @Test("a missing file reads as empty rather than crashing")
    func missingFile() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("absent-\(UUID().uuidString).json")
        #expect(FileStateStore(url: url).load() == BrickState())
    }
}
