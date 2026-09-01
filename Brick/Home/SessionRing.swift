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

    private let tickCount = 72

    var body: some View {
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
                        ? (isOpen ? Theme.chalk : Theme.ash)
                        : (isElapsed ? Theme.chalk : Theme.graphite)

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

            VStack(spacing: 10) {
                Text(Format.countdown(remaining))
                    .readout(size: 52)
                    .foregroundStyle(Theme.chalk)
                    .contentTransition(.numericText())
                Text(caption)
                    .engraved()
            }
            .padding(.horizontal, 58)
        }
        .frame(width: 274, height: 274)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Format.spokenRemaining(remaining)) remaining. \(caption).")
    }
}
