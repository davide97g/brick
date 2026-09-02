import Foundation
import Testing

@testable import BrickKit

/// The demo-tag seam App Review needs: the wrong side of this switch would
/// either leave a reviewer unable to test the app, or leave a shipping user
/// able to end a session without walking back to the brick.
@Suite("Switching tag adapters")
struct SwitchingTagTests {
    @Test("reads the primary tag while the alternate is off")
    func readsPrimary() async throws {
        let reader = SwitchingTagReader(
            primary: StubTagReader(uid: "AAAAAA"),
            alternate: StubTagReader(uid: "BBBBBB"),
            useAlternate: { false }
        )
        #expect(try await reader.readTagUID() == "AAAAAA")
    }

    @Test("reads the alternate tag once it is on")
    func readsAlternate() async throws {
        let reader = SwitchingTagReader(
            primary: StubTagReader(uid: "AAAAAA"),
            alternate: StubTagReader(uid: "BBBBBB"),
            useAlternate: { true }
        )
        #expect(try await reader.readTagUID() == "BBBBBB")
    }

    @Test("the side is chosen per scan, not once at construction")
    func choosesPerScan() async throws {
        let flag = Flag()
        let reader = SwitchingTagReader(
            primary: StubTagReader(uid: "AAAAAA"),
            alternate: StubTagReader(uid: "BBBBBB"),
            useAlternate: { flag.value }
        )
        #expect(try await reader.readTagUID() == "AAAAAA")
        flag.value = true
        #expect(try await reader.readTagUID() == "BBBBBB")
    }

    @Test("writes go to the same side the reads do")
    func writesFollowTheSwitch() async throws {
        let primary = RecordingTagWriter(uid: "AAAAAA")
        let alternate = RecordingTagWriter(uid: "BBBBBB")
        let writer = SwitchingTagWriter(
            primary: primary,
            alternate: alternate,
            useAlternate: { true }
        )
        let id = UUID()
        #expect(try await writer.writeIdentity(id) == "BBBBBB")
        #expect(primary.written.isEmpty)
        #expect(alternate.written == [id])
    }

    /// A `var` captured by a `@Sendable` closure can't be mutated afterwards;
    /// a reference with its own lock can.
    private final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = false
        var value: Bool {
            get { lock.withLock { _value } }
            set { lock.withLock { _value = newValue } }
        }
    }
}
