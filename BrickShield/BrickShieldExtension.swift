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
        let now = Date()
        let session = state?.activeSession
        let remaining = session?.remaining(at: now) ?? 0

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.black.withAlphaComponent(0.55),
            icon: nil,
            title: ShieldConfiguration.Label(
                text: remaining > 0 ? ShieldCopy.remaining(remaining) : "Bricked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: ShieldCopy.wayOut(state, now: now),
                color: UIColor.white.withAlphaComponent(0.7)
            )
        )
    }
}

enum ShieldCopy {
    /// The extension can't ask which biometry this phone has, so the biometric
    /// line names none — it points at the app, where the real prompt lives.
    static func wayOut(_ state: BrickState?, now: Date = Date()) -> String {
        guard let state else { return "Your brick has the way out." }
        switch state.unlock {
        case .brick:
            // The same rules the app reads, from the same file: a route says
            // how many taps are left and which brick is next, a lone brick
            // just says where it is.
            return SessionEngine.routeStatus(state: state, now: now)?.description
                ?? state.tag?.whereItIs
                ?? "Your brick has the way out."
        case .biometric:
            return "Unlock in Brick, once the gate opens."
        }
    }

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
