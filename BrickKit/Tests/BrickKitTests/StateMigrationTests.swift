import Foundation
import Testing
@testable import BrickKit

/// `load()` swallows any decode error and returns empty state, so a state file
/// that fails to decode does not look like a bug: it looks like the user was
/// silently unpaired and their blocklist thrown away. These are the tests that
/// stop that happening.
@Suite("Migration")
struct StateMigrationTests {

    private func write(_ json: String) -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("brick-migration-\(UUID().uuidString).json")
        try? Data(json.utf8).write(to: url)
        return url
    }

    /// Byte for byte the shape the shipped build writes: one `tag`, one
    /// `blocklist`, a running session with none of the new keys.
    private let shipped = """
    {"blocklist":{"appCount":12,"categoryCount":2,"webDomainCount":0,\
    "defaultDuration":5400,"minimumDuration":2700,"selectionData":"qwE="},\
    "unlock":"brick","history":[],"emergency":{"uses":[]},\
    "activeSession":{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF",\
    "startedAt":"2026-01-01T09:00:00Z","plannedEnd":"2026-01-01T10:30:00Z"},\
    "tag":{"uid":"04A1B2C3D4E580","ndefID":"6F9619FF-8B86-D011-B42D-00CF4FC964FE",\
    "placeNote":"on your desk","pairedAt":"2026-01-01T08:00:00Z"}}
    """

    @Test("the shipped state file becomes one tag and one profile")
    func migratesShippedFile() {
        let url = write(shipped)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = FileStateStore(url: url).load()
        #expect(loaded.tags.count == 1)
        #expect(loaded.tags.first?.uid == "04A1B2C3D4E580")
        #expect(loaded.tags.first?.placeNote == "on your desk")
        #expect(loaded.profiles.count == 1)
        #expect(loaded.profiles.first?.appCount == 12)
        #expect(loaded.profiles.first?.minimumDuration == .brickMinutes(45))
        #expect(loaded.profiles.first?.mode == .block)
        #expect(loaded.profiles.first?.exitRoute.isEmpty == true)
    }

    @Test("the migrated tag points at the migrated profile")
    func migratedTagKeepsItsProfile() {
        let url = write(shipped)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = FileStateStore(url: url).load()
        #expect(loaded.tags.first?.profileID == loaded.profiles.first?.id)
        #expect(SessionEngine.profile(forTagUID: "04A1B2C3D4E580", in: loaded)?.appCount == 12)
    }

    @Test("a session running through the update keeps running, under the migrated rules")
    func migratedSessionSurvives() throws {
        let url = write(shipped)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = FileStateStore(url: url).load()
        let session = try #require(loaded.activeSession)
        #expect(session.isActive)
        #expect(session.kind == .block)
        #expect(session.profileID == nil)
        // No profileID, so the rules come from the only profile there is.
        #expect(SessionEngine.profile(for: session, in: loaded).minimumDuration == .brickMinutes(45))

        let opensAt = session.startedAt.addingTimeInterval(.brickMinutes(45))
        #expect(throws: BrickError.tooEarlyToEnd(availableAt: opensAt)) {
            try SessionEngine.validateEnd(state: loaded, now: opensAt.addingTimeInterval(-1))
        }
        #expect(throws: Never.self) {
            try SessionEngine.validateEnd(state: loaded, now: opensAt)
        }
    }

    @Test("the exit is the paired tag, with no route recorded anywhere")
    func migratedExitIsTheOneTag() throws {
        let url = write(shipped)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = FileStateStore(url: url).load()
        let session = try #require(loaded.activeSession)
        #expect(SessionEngine.exitRoute(for: session, in: loaded) == ["04A1B2C3D4E580"])
    }

    @Test("a file written before biometrics existed still loads paired")
    func migratesFileWithoutUnlockKey() {
        let url = write("""
        {"blocklist":{"appCount":3,"categoryCount":0,"webDomainCount":0,\
        "defaultDuration":3600,"minimumDuration":1800},\
        "history":[],"emergency":{"uses":[]},\
        "tag":{"uid":"04A1B2C3D4E580","ndefID":"6F9619FF-8B86-D011-B42D-00CF4FC964FE",\
        "placeNote":"on your desk","pairedAt":"2026-01-01T09:00:00Z"}}
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = FileStateStore(url: url).load()
        #expect(loaded.tag?.uid == "04A1B2C3D4E580")
        #expect(loaded.unlock == .brick)
        #expect(loaded.blocklist.appCount == 3)
    }

    @Test("keys from a future build are ignored rather than fatal")
    func unknownKeysAreIgnored() {
        let url = write("""
        {"tags":[],"profiles":[],"history":[],"emergency":{"uses":[]},\
        "somethingNobodyHasWrittenYet":{"deep":[1,2,3]}}
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(FileStateStore(url: url).load() == BrickState())
    }

    @Test("an unpaired file with a blocklist keeps the blocklist")
    func unpairedFileKeepsItsBlocklist() {
        let url = write("""
        {"blocklist":{"appCount":5,"categoryCount":0,"webDomainCount":0,\
        "defaultDuration":3600,"minimumDuration":1800},"unlock":"biometric",\
        "history":[],"emergency":{"uses":[]}}
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = FileStateStore(url: url).load()
        #expect(loaded.tags.isEmpty)
        #expect(loaded.profiles.count == 1)
        #expect(loaded.profiles.first?.appCount == 5)
        #expect(loaded.hasKey)
    }

    @Test("the legacy keys are read once and never written back")
    func migrationIsWrittenBackInTheNewShape() throws {
        let url = write(shipped)
        defer { try? FileManager.default.removeItem(at: url) }

        let store = FileStateStore(url: url)
        store.save(store.load())

        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(raw.contains("\"tags\""))
        #expect(raw.contains("\"profiles\""))
        #expect(!raw.contains("\"blocklist\""))
        #expect(FileStateStore(url: url).load().tags.first?.uid == "04A1B2C3D4E580")
    }

    @Test("a corrupt file still reads as empty rather than crashing")
    func corruptFile() {
        let url = write("{ this is not json")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(FileStateStore(url: url).load() == BrickState())
    }
}
