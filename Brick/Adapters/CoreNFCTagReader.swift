import BrickKit
import CoreNFC
import Foundation

/// Real tag reading: a foreground `NFCTagReaderSession` returning the tag's
/// factory UID as uppercase hex.
///
/// The UID is read-only silicon, so it keeps identifying the brick even if the
/// NDEF content is later overwritten.
final class CoreNFCTagReader: NSObject, TagReading, NFCTagReaderSessionDelegate, @unchecked Sendable {
    enum Failure: LocalizedError {
        case unavailable
        case unsupportedTag
        case cancelled

        var errorDescription: String? {
            switch self {
            case .unavailable: return "This iPhone can't read NFC tags."
            case .unsupportedTag: return "That tag isn't a supported type."
            case .cancelled: return "Scan cancelled."
            }
        }
    }

    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<String, Error>?
    private let prompt: String

    init(prompt: String = "Hold your iPhone near your brick.") {
        self.prompt = prompt
    }

    func readTagUID() async throws -> String {
        guard NFCTagReaderSession.readingAvailable else { throw Failure.unavailable }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
            session?.alertMessage = prompt
            session?.begin()
            self.session = session
        }
    }

    // MARK: NFCTagReaderSessionDelegate

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        finish(.failure(error))
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard case let .miFare(tag) = tags.first else {
            session.invalidate(errorMessage: "Unsupported tag.")
            finish(.failure(Failure.unsupportedTag))
            return
        }
        session.connect(to: tags[0]) { [weak self] error in
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                self?.finish(.failure(error))
                return
            }
            let uid = tag.identifier.map { String(format: "%02X", $0) }.joined()
            session.alertMessage = "Brick recognised."
            session.invalidate()
            self?.finish(.success(uid))
        }
    }

    private func finish(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        self.session = nil
        continuation.resume(with: result)
    }
}
