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
            blocklist: BlockProfile(selectionData: Data([0xAB]), appCount: 7),
            activeSession: Session(startedAt: start, plannedEnd: start.addingTimeInterval(3600))
        )
        state.emergency.record(at: start)
        store.save(state)

        #expect(FileStateStore(url: url).load() == state)
    }

    @Test("a state file written before biometrics existed still loads paired")
    func migratesFileWithoutUnlockKey() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("legacy-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        // Shape written by every build before `unlock` existed. Decoding must
        // not throw: `load()` swallows the error and would silently unpair.
        let legacy = """
        {"blocklist":{"appCount":3,"categoryCount":0,"webDomainCount":0,\
        "defaultDuration":3600,"minimumDuration":1800},\
        "history":[],"emergency":{"uses":[]},\
        "tag":{"uid":"04A1B2C3D4E580","ndefID":"\(UUID().uuidString)",\
        "placeNote":"on your desk","pairedAt":"2026-01-01T09:00:00Z"}}
        """
        try Data(legacy.utf8).write(to: url)

        let loaded = FileStateStore(url: url).load()
        #expect(loaded.tag?.uid == "04A1B2C3D4E580")
        #expect(loaded.unlock == .brick)
        #expect(loaded.blocklist.appCount == 3)
    }

    @Test("a missing file reads as empty rather than crashing")
    func missingFile() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("absent-\(UUID().uuidString).json")
        #expect(FileStateStore(url: url).load() == BrickState())
    }
}
