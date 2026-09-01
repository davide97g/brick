import BrickKit
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The shield a blocked app shows. It is the only surface the user sees while
/// the phone is restricted, so it says the two things worth knowing: how long
/// is left, and where the brick is.
///
/// Deliberately buttonless. There is nothing to negotiate here — the way out is
/// the object, or the clock.
class BrickShieldExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        brickShield()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        brickShield()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        brickShield()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        brickShield()
    }

    private func brickShield() -> ShieldConfiguration {
        let state = FileStateStore.shared()?.load()
        let session = state?.activeSession
        let remaining = session?.remaining(at: Date()) ?? 0

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.black.withAlphaComponent(0.55),
            icon: nil,
            title: ShieldConfiguration.Label(
                text: remaining > 0 ? ShieldCopy.remaining(remaining) : "Bricked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: state?.tag?.whereItIs ?? "Your brick has the way out.",
                color: UIColor.white.withAlphaComponent(0.7)
            )
        )
    }
}

enum ShieldCopy {
    /// "43 minutes left" / "1h 12m left" — coarse on purpose. A ticking second
    /// counter would invite watching it.
    static func remaining(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded(.up))
        if minutes < 60 { return "\(minutes) minute\(minutes == 1 ? "" : "s") left" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)h left" : "\(hours)h \(rest)m left"
    }
}
