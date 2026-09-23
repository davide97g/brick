import CoreNFC
import Foundation

/// A scratchpad over Core NFC: everything a foreground session can do to a
/// cheap NTAG, with the result printed rather than interpreted.
///
/// Deliberately never calls `writeLock` — the production writer does, and it is
/// one-way silicon. A spike that bricks the tags it touches is useless.
@MainActor
final class NFCLab: NSObject, ObservableObject {
    enum Job {
        case inspect
        case writeText(String)
        case writeURI(String)
        case erase
    }

    @Published var log: [String] = ["Ready. Tap a button, then hold a tag to the top of the phone."]
    @Published var busy = false

    private var session: NFCTagReaderSession?
    private var job: Job = .inspect

    var available: Bool { NFCTagReaderSession.readingAvailable }

    func run(_ job: Job, prompt: String) {
        guard available else { return say("This iPhone can't read NFC tags.") }
        self.job = job
        log = []
        busy = true
        let session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: nil)
        session?.alertMessage = prompt
        session?.begin()
        self.session = session
    }

    nonisolated func say(_ line: String) {
        Task { @MainActor in self.log.append(line) }
    }

    nonisolated func done() {
        Task { @MainActor in
            self.busy = false
            self.session = nil
        }
    }
}

// MARK: - Session

extension NFCLab: NFCTagReaderSessionDelegate {
    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        let nsError = error as NSError
        // Cancel and timeout arrive here too; they are not worth shouting about.
        if nsError.code != NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue {
            say("Session ended: \(error.localizedDescription)")
        }
        done()
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        say("Detected \(describe(tag)) — \(tags.count) tag(s) in field.")

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                self.say("Connect failed: \(error.localizedDescription)")
                self.done()
                return
            }
            guard case let .miFare(mifare) = tag else {
                session.invalidate(errorMessage: "This spike only drives MIFARE/NTAG tags.")
                self.say("Connected, but not a MIFARE tag — nothing further to do.")
                self.done()
                return
            }
            self.say("UID: \(self.hex(mifare.identifier))")
            self.say("Family: \(self.family(mifare.mifareFamily))")
            if let historical = mifare.historicalBytes, !historical.isEmpty {
                self.say("Historical bytes: \(self.hex(historical))")
            }
            self.status(of: mifare, session: session)
        }
    }

    /// Everything after connection funnels through the NDEF status: capacity
    /// and writability are the two facts that decide what is possible.
    private nonisolated func status(of tag: NFCMiFareTag, session: NFCTagReaderSession) {
        tag.queryNDEFStatus { [weak self] status, capacity, error in
            guard let self else { return }
            if let error {
                self.say("queryNDEFStatus failed: \(error.localizedDescription)")
                self.finish(session, "Read failed")
                return
            }
            self.say("NDEF: \(self.describe(status)), capacity \(capacity) bytes")

            Task { @MainActor in
                switch self.job {
                case .inspect: self.inspect(tag, session: session)
                case let .writeText(text):
                    self.write(NFCNDEFMessage(records: [Self.textRecord(text)]), to: tag, status: status, session: session)
                case let .writeURI(uri):
                    guard let record = NFCNDEFPayload.wellKnownTypeURIPayload(string: uri) else {
                        self.say("Not a URI Core NFC will encode: \(uri)")
                        self.finish(session, "Bad URI")
                        return
                    }
                    self.write(NFCNDEFMessage(records: [record]), to: tag, status: status, session: session)
                case .erase:
                    self.write(NFCNDEFMessage(records: [NFCNDEFPayload(format: .empty, type: Data(), identifier: Data(), payload: Data())]),
                               to: tag, status: status, session: session)
                }
            }
        }
    }
}

// MARK: - Jobs

extension NFCLab {
    /// Read the NDEF message, then go under it: a raw READ command for the
    /// first four pages, which no NDEF abstraction exposes.
    private nonisolated func inspect(_ tag: NFCMiFareTag, session: NFCTagReaderSession) {
        tag.readNDEF { [weak self] message, error in
            guard let self else { return }
            if let error {
                self.say("No NDEF message (\(error.localizedDescription))")
            } else if let message {
                self.say("Records: \(message.records.count)")
                for (index, record) in message.records.enumerated() {
                    self.say("  [\(index)] \(self.describe(record))")
                }
            }
            // 0x30 = READ, returns 16 bytes starting at the given page.
            tag.sendMiFareCommand(commandPacket: Data([0x30, 0x00])) { data, error in
                if let error {
                    self.say("Raw READ 0x00 failed: \(error.localizedDescription)")
                } else {
                    self.say("Raw pages 0–3: \(self.hex(data))")
                    self.say("  (page 2 byte 2–3 are the lock bits; page 3 is the one-way OTP/CC)")
                }
                self.finish(session, "Read")
            }
        }
    }

    private nonisolated func write(
        _ message: NFCNDEFMessage,
        to tag: NFCMiFareTag,
        status: NFCNDEFStatus,
        session: NFCTagReaderSession
    ) {
        guard status == .readWrite else {
            self.say("Tag is \(describe(status)) — nothing written.")
            finish(session, "Locked")
            return
        }
        say("Payload size: \(message.length) bytes")
        tag.writeNDEF(message) { [weak self] error in
            guard let self else { return }
            if let error {
                self.say("Write failed: \(error.localizedDescription)")
                self.finish(session, "Write failed")
                return
            }
            self.say("Written. Reading it straight back…")
            tag.readNDEF { message, error in
                if let error {
                    self.say("Read-back failed: \(error.localizedDescription)")
                } else if let message {
                    for (index, record) in message.records.enumerated() {
                        self.say("  [\(index)] \(self.describe(record))")
                    }
                }
                self.finish(session, "Written")
            }
        }
    }

    private nonisolated func finish(_ session: NFCTagReaderSession, _ message: String) {
        session.alertMessage = message
        session.invalidate()
        done()
    }
}

// MARK: - Encoding and description

extension NFCLab {
    /// NDEF text record: status byte (UTF-8, 2-byte language code) + "en" + text.
    static func textRecord(_ text: String) -> NFCNDEFPayload {
        var payload = Data([UInt8(2)])
        payload.append(contentsOf: Array("en".utf8))
        payload.append(contentsOf: Array(text.utf8))
        return NFCNDEFPayload(format: .nfcWellKnown, type: Data("T".utf8), identifier: Data(), payload: payload)
    }

    nonisolated func hex(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    private nonisolated func describe(_ tag: NFCTag) -> String {
        switch tag {
        case .miFare: return "MIFARE / NTAG"
        case .iso7816: return "ISO 7816 smartcard"
        case .iso15693: return "ISO 15693 (vicinity)"
        case .feliCa: return "FeliCa"
        @unknown default: return "unknown tag"
        }
    }

    private nonisolated func family(_ family: NFCMiFareFamily) -> String {
        switch family {
        case .ultralight: return "Ultralight / NTAG21x"
        case .plus: return "MIFARE Plus"
        case .desfire: return "DESFire"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }

    private nonisolated func describe(_ status: NFCNDEFStatus) -> String {
        switch status {
        case .notSupported: return "not NDEF-formatted"
        case .readWrite: return "read/write"
        case .readOnly: return "locked read-only"
        @unknown default: return "unknown"
        }
    }

    private nonisolated func describe(_ record: NFCNDEFPayload) -> String {
        let type = String(data: record.type, encoding: .utf8) ?? hex(record.type)
        if let url = record.wellKnownTypeURIPayload() {
            return "URI record: \(url.absoluteString)"
        }
        let (payloadText, locale) = record.wellKnownTypeTextPayload()
        if let payloadText {
            return "Text record (\(locale?.identifier ?? "?")): \(payloadText)"
        }
        let body = String(data: record.payload, encoding: .utf8) ?? hex(record.payload)
        return "type \(type), \(record.payload.count) bytes: \(body)"
    }
}
