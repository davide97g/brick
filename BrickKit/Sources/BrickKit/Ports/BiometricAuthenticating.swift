import Foundation

/// Face ID / Touch ID, as the stand-in key for a user with no brick.
///
/// The prompt itself is the whole point: it is one deliberate act that can't be
/// done by a thumb already halfway to the app. It is not a secret — the user
/// owns their own face — so it binds nothing on its own. What binds is the
/// minimum duration and the emergency quota, which apply identically either way.
public protocol BiometricAuthenticating: AnyObject, Sendable {
    /// Hardware present and enrolled. False means this can never be the key.
    var isAvailable: Bool { get }
    /// "Face ID" or "Touch ID" — copy has to name the real thing.
    var name: String { get }
    /// Throws `BrickError.biometricCancelled` when the user dismissed it, and
    /// `.biometricFailed` for everything else.
    func authenticate(reason: String) async throws
}

public final class StubBiometrics: BiometricAuthenticating, @unchecked Sendable {
    private let lock = NSLock()
    private var _available: Bool
    private var _result: Result<Void, Error>
    private var _prompts: [String] = []

    public let name: String

    public init(available: Bool = true, name: String = "Face ID") {
        _available = available
        _result = .success(())
        self.name = name
    }

    public var isAvailable: Bool {
        lock.lock(); defer { lock.unlock() }
        return _available
    }

    /// Reasons passed to `authenticate`, in order — the assertion that a flow
    /// actually asked for a face rather than quietly skipping it.
    public var prompts: [String] {
        lock.lock(); defer { lock.unlock() }
        return _prompts
    }

    public func stub(available: Bool) {
        lock.lock(); defer { lock.unlock() }
        _available = available
    }

    public func stub(_ result: Result<Void, Error>) {
        lock.lock(); defer { lock.unlock() }
        _result = result
    }

    public func authenticate(reason: String) async throws {
        try recordPrompt(reason).get()
    }

    private func recordPrompt(_ reason: String) -> Result<Void, Error> {
        lock.lock(); defer { lock.unlock() }
        _prompts.append(reason)
        return _result
    }
}

/// Picks between two authenticators at call time, mirroring `SwitchingTagReader`.
/// A review device with no enrolled face would otherwise be as stuck as one
/// with no brick.
public final class SwitchingBiometrics: BiometricAuthenticating, @unchecked Sendable {
    private let primary: BiometricAuthenticating
    private let alternate: BiometricAuthenticating
    private let useAlternate: @Sendable () -> Bool

    public init(
        primary: BiometricAuthenticating,
        alternate: BiometricAuthenticating,
        useAlternate: @escaping @Sendable () -> Bool
    ) {
        self.primary = primary
        self.alternate = alternate
        self.useAlternate = useAlternate
    }

    private var current: BiometricAuthenticating { useAlternate() ? alternate : primary }

    public var isAvailable: Bool { current.isAvailable }
    public var name: String { current.name }

    public func authenticate(reason: String) async throws {
        try await current.authenticate(reason: reason)
    }
}
