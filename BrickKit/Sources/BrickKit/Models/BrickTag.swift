import Foundation

/// The single physical brick, identified by its factory NFC tag UID.
///
/// The UID is a 7-byte NTAG serial rendered as uppercase hex. It cannot be
/// rewritten, so it survives someone overwriting the tag's NDEF content.
/// `ndefID` is the UUID we additionally write to the tag, kept so a future
/// Universal Link route can identify the same brick without re-pairing.
public struct BrickTag: Codable, Equatable, Sendable {
    public var uid: String
    public var ndefID: UUID
    public var placeNote: String
    public var pairedAt: Date

    public init(uid: String, ndefID: UUID = UUID(), placeNote: String = "", pairedAt: Date) {
        self.uid = uid
        self.ndefID = ndefID
        self.placeNote = placeNote
        self.pairedAt = pairedAt
    }

    /// Copy shown on the shield when a session is running.
    public var whereItIs: String {
        placeNote.isEmpty ? "Your brick is where you left it." : "Your brick is \(placeNote)."
    }
}
