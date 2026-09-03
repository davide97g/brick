import SwiftUI

/// An engraved bezel: 72 tick marks, elapsed ones lit, the rest recessed.
///
/// The mark that matters is `gate` — a longer tick at the point where the
/// minimum duration is satisfied and the brick becomes able to end the session.
/// Until the sweep reaches it, going back to the object buys nothing, and the
/// dial says so before you walk.
struct SessionBezel: View {
    /// 0…1 through the session.
    var progress: Double
    /// 0…1 position of the minimum-duration mark, or nil if there isn't one.
    var gate: Double?
    var remaining: TimeInterval
    var caption: String
    /// The gate has been passed: the brick works now.
    var isOpen: Bool
    var surface: Surface = .standard

    /// Shrinks at accessibility text sizes: the readout inside it grows to a
    /// ceiling, and a fixed 274 would push the controls off screen.
    var size: CGFloat = 274
    /// Drops the bezel entirely, leaving the readout.
    var compact = false

    private let tickCount = 72

    private var readoutStack: some View {
        VStack(spacing: 10) {
            Text(Format.countdown(remaining))
                .readout(size: compact ? 44 : 52)
                .foregroundStyle(surface.fieldText)
                .contentTransition(.numericText())
            Text(caption)
                .engraved(surface.fieldMuted)
        }
    }

    var body: some View {
        // Past a point the bezel is a frame around text that no longer fits in
        // it. At accessibility sizes the readout stands on its own.
        if compact {
            readoutStack
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Format.spokenRemaining(remaining)) remaining. \(caption).")
        } else {
            dial
        }
    }

    private var dial: some View {
        ZStack {
            Canvas { context, size in
                let radius = min(size.width, size.height) / 2
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let elapsedTicks = Int((Double(tickCount) * progress).rounded())
                let gateTick = gate.map { Int((Double(tickCount) * $0).rounded()) }

                for index in 0..<tickCount {
                    let isGate = index == gateTick
                    let isElapsed = index < elapsedTicks

                    let length: CGFloat = isGate ? 22 : (isElapsed ? 13 : 9)
                    let width: CGFloat = isGate ? 2.5 : 1.5
                    let color: Color = isGate
                        ? (isOpen ? surface.fieldText : surface.fieldMuted)
                        : (isElapsed ? surface.fieldText : surface.fieldRecessed)

                    let angle = Angle.degrees(Double(index) / Double(tickCount) * 360 - 90)
                    let outer = CGPoint(
                        x: center.x + cos(angle.radians) * radius,
                        y: center.y + sin(angle.radians) * radius
                    )
                    let inner = CGPoint(
                        x: center.x + cos(angle.radians) * (radius - length),
                        y: center.y + sin(angle.radians) * (radius - length)
                    )

                    var path = Path()
                    path.move(to: inner)
                    path.addLine(to: outer)
                    context.stroke(
                        path,
                        with: .color(color),
                        style: StrokeStyle(lineWidth: width, lineCap: .round)
                    )
                }
            }

            readoutStack
                .padding(.horizontal, 58)
        }
        .instrumentTypeSize()
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Format.spokenRemaining(remaining)) remaining. \(caption).")
    }
}
