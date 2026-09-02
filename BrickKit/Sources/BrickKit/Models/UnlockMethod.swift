import Foundation

/// How a session is started and ended.
///
/// The brick is the product. Biometrics exist because a brick you haven't
/// printed yet blocks the app entirely, and an app that can't be used is worth
/// less than a weaker version of itself. The weakness is real and is stated
/// where the choice is made: with `.biometric` the key is in the same hand as
/// the craving, so only the minimum duration and the emergency quota still
/// stand between the user and their apps.
public enum UnlockMethod: String, Codable, Equatable, Sendable {
    case brick
    case biometric
}
