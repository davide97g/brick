import Foundation

/// One paired physical tag, identified by its factory NFC UID.
///
/// The UID is a 7-byte NTAG serial rendered as uppercase hex. It cannot be
/// rewritten, so it survives someone overwriting the tag's NDEF content.
/// `ndefID` is the UUID we additionally write to the tag, kept so a future
/// Universal Link route can identify the same tag without re-pairing.
///
/// There can be several: a slab on the desk, a sticker under the kitchen
/// shelf, one by the front door. Which profile a tap starts is the tag's own
/// business — that is what makes a station a station.
public struct BrickTag: Codable, Equatable, Sendable, Identifiable {
    public var uid: String
    public var ndefID: UUID
    /// What the user calls it: "desk slab", "kitchen tile".
    public var name: String
    /// Where the shield says it is: "on your desk".
    public var placeNote: String
    /// The profile a tap starts. `nil` means the app asks.
    public var profileID: UUID?
    public var pairedAt: Date

    public var id: String { uid }

    public init(
        uid: String,
        ndefID: UUID = UUID(),
        name: String = "",
        placeNote: String = "",
        profileID: UUID? = nil,
        pairedAt: Date
    ) {
        self.uid = uid
        self.ndefID = ndefID
        self.name = name
        self.placeNote = placeNote
        self.profileID = profileID
        self.pairedAt = pairedAt
    }

    /// Never empty: an unnamed tag still has to be referable in a route.
    public var displayName: String {
        name.isEmpty ? "Your brick" : name
    }

    /// Copy shown on the shield when a session is running.
    public var whereItIs: String {
        if !placeNote.isEmpty { return "\(displayName) is \(placeNote)." }
        return name.isEmpty ? "Your brick is where you left it." : "\(name) is where you left it."
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case uid, ndefID, name, placeNote, profileID, pairedAt
    }

    /// Field by field: tags written before profiles existed carry no `name`
    /// and no `profileID`, and a throw here empties the whole state file.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(String.self, forKey: .uid)
        ndefID = try container.decodeIfPresent(UUID.self, forKey: .ndefID) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        placeNote = try container.decodeIfPresent(String.self, forKey: .placeNote) ?? ""
        profileID = try container.decodeIfPresent(UUID.self, forKey: .profileID)
        pairedAt = try container.decodeIfPresent(Date.self, forKey: .pairedAt) ?? Date()
    }
}
