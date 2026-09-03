import SwiftUI

/// A ten-second hold, and the only place colour appears in the app.
///
/// The valve has to exist — the brick is deliberately out of reach — but it
/// should never be something a thumb does by reflex. The oxide fill creeping
/// across the pill is the interface admitting something is being spent.
struct EmergencyUnlockButton: View {
    var remainingAllowance: Int
    /// Reverse mode spends the same allowance on the opposite thing, so the
    /// label is the caller's to name.
    var title = "Hold to unlock"
    var holdingTitle = "Keep holding"
    var surface: Surface = .standard
    var action: () -> Void

    @State private var progress: Double = 0
    @State private var holdTask: Task<Void, Never>?

    private let holdDuration: TimeInterval = 10
    private var isSpent: Bool { remainingAllowance == 0 }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Capsule().strokeBorder(surface.cardText.opacity(0.18), lineWidth: 1)

                GeometryReader { proxy in
                    Capsule()
                        .fill(Theme.oxide.opacity(0.9))
                        .frame(width: proxy.size.width * progress)
                }
                .clipShape(Capsule())

                Text(progress > 0 ? holdingTitle : title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(fillHasReachedLabel ? Theme.paper : labelColor)
            }
            .frame(height: 54)
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginHold() }
                    .onEnded { _ in cancelHold() }
            )
            .disabled(isSpent)

            Text(allowanceText)
                .engraved(surface.cardMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Emergency unlock")
        .accessibilityHint(
            isSpent
                ? "None left this week"
                : "Hold for ten seconds. \(remainingAllowance) left this week."
        )
        .accessibilityAddTraits(isSpent ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { action() }
        .onDisappear { cancelHold() }
    }

    private var labelColor: Color {
        isSpent ? surface.cardMuted : Theme.oxide
    }

    /// Once the fill passes the centre the label sits on oxide, not paper.
    private var fillHasReachedLabel: Bool { progress > 0.42 }

    private var allowanceText: String {
        isSpent ? "None left this week" : "\(remainingAllowance) left this week"
    }

    private func beginHold() {
        guard holdTask == nil, !isSpent else { return }
        holdTask = Task { @MainActor in
            let steps = 60
            for step in 1...steps {
                try? await Task.sleep(for: .seconds(holdDuration / Double(steps)))
                if Task.isCancelled { return }
                withAnimation(.linear(duration: holdDuration / Double(steps))) {
                    progress = Double(step) / Double(steps)
                }
            }
            action()
            reset()
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        reset()
    }

    private func reset() {
        holdTask = nil
        withAnimation(.snappy) { progress = 0 }
    }
}
