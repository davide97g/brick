import BrickKit
import CoreNFC
import Foundation

/// Writes the brick's identity to the tag as an NDEF text record, then locks
/// the tag read-only so it can't be casually repurposed.
///
/// Locking is permanent — NTAG's lock bits are one-way. That is the intent: the
/// object should keep meaning one thing.
final class CoreNFCTagWriter: NSObject, TagWriting, NFCTagReaderSessionDelegate, @unchecked Sendable {
    enum Failure: LocalizedError {
        case unavailable
        case unsupportedTag
        case notWritable

        var errorDescription: String? {
            switch self {
            case .unavailable: return "This iPhone can't write NFC tags."
            case .unsupportedTag: return "That tag isn't a supported type."
            case .notWritable: return "That tag is locked and can't be written."
            }
        }
    }

    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<String, Error>?
    private var identity = UUID()

    func writeIdentity(_ id: UUID) async throws -> String {
        guard NFCTagReaderSession.readingAvailable else { throw Failure.unavailable }
        identity = id
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
            session?.alertMessage = "Hold your iPhone near your brick to pair it."
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
        guard let tag = tags.first, case let .miFare(mifare) = tag else {
            session.invalidate(errorMessage: "Unsupported tag.")
            finish(.failure(Failure.unsupportedTag))
            return
        }

        let uid = mifare.identifier.map { String(format: "%02X", $0) }.joined()

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                self.finish(.failure(error))
                return
            }
            self.write(to: tag, mifare: mifare, uid: uid, session: session)
        }
    }

    // MARK: Writing

    private func write(
        to tag: NFCTag,
        mifare: NFCMiFareTag,
        uid: String,
        session: NFCTagReaderSession
    ) {
        mifare.queryNDEFStatus { [weak self] status, _, error in
            guard let self else { return }

            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                self.finish(.failure(error))
                return
            }

            // An already-locked tag still identifies the brick by UID, so pair
            // on that rather than failing the whole flow.
            guard status == .readWrite else {
                session.alertMessage = "Brick paired."
                session.invalidate()
                self.finish(.success(uid))
                return
            }

            let message = NFCNDEFMessage(records: [self.identityRecord()])
            mifare.writeNDEF(message) { error in
                if let error {
                    session.invalidate(errorMessage: error.localizedDescription)
                    self.finish(.failure(error))
                    return
                }
                // Best effort: a tag that refuses to lock is still perfectly
                // usable, so don't fail pairing over it.
                mifare.writeLock { _ in
                    session.alertMessage = "Brick paired."
                    session.invalidate()
                    self.finish(.success(uid))
                }
            }
        }
    }

    private func identityRecord() -> NFCNDEFPayload {
        NFCNDEFPayload(
            format: .nfcWellKnown,
            type: Data("T".utf8),
            identifier: Data(),
            payload: textPayload("brick:\(identity.uuidString)")
        )
    }

    /// NDEF text record: status byte (UTF-8, 2-byte language code) + "en" + text.
    private func textPayload(_ text: String) -> Data {
        let language = "en"
        var payload = Data([UInt8(language.utf8.count)])
        payload.append(contentsOf: Array(language.utf8))
        payload.append(contentsOf: Array(text.utf8))
        return payload
    }

    private func finish(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        self.session = nil
        continuation.resume(with: result)
    }
}
