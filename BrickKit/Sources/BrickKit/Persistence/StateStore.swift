import Foundation

/// Read/write access to `BrickState`, shared by the app and its extensions.
public protocol StateStore: AnyObject, Sendable {
    func load() -> BrickState
    func save(_ state: BrickState)
}

extension StateStore {
    /// Read-modify-write convenience; the whole state is small enough that
    /// rewriting it wholesale is simpler than any diffing scheme.
    @discardableResult
    public func mutate<T>(_ body: (inout BrickState) -> T) -> T {
        var state = load()
        let result = body(&state)
        save(state)
        return result
    }
}

/// Test double, and the store the SwiftUI previews use.
public final class InMemoryStateStore: StateStore, @unchecked Sendable {
    private let lock = NSLock()
    private var state: BrickState

    public init(_ state: BrickState = BrickState()) { self.state = state }

    public func load() -> BrickState {
        lock.lock(); defer { lock.unlock() }
        return state
    }

    public func save(_ newValue: BrickState) {
        lock.lock(); defer { lock.unlock() }
        state = newValue
    }
}

/// JSON in the App Group container. Extensions get the same file, which is the
/// whole reason the App Group exists.
public final class FileStateStore: StateStore, @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()

    public init(url: URL) { self.url = url }

    /// - Parameter appGroupID: e.g. `group.com.davideghiotto.brick`.
    public convenience init?(appGroupID: String, filename: String = "brick-state.json") {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return nil }
        self.init(url: container.appendingPathComponent(filename))
    }

    public func load() -> BrickState {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder.brick.decode(BrickState.self, from: data)
        else { return BrickState() }
        return decoded
    }

    public func save(_ state: BrickState) {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? JSONEncoder.brick.encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

extension JSONEncoder {
    static var brick: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var brick: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
