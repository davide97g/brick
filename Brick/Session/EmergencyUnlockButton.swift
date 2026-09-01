import SwiftUI

/// A ten-second hold. The valve has to exist — the brick is deliberately out of
/// reach — but it should never be something a thumb does by reflex.
struct EmergencyUnlockButton: View {
    var remainingAllowance: Int
    var action: () -> Void

    @State private var progress: Double = 0
    @State private var holdTask: Task<Void, Never>?

    private let holdDuration: TimeInterval = 10

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Capsule().fill(Color.primary.opacity(0.06))
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: proxy.size.width * progress)
                }
                Text(progress > 0 ? "Keep holding…" : "Hold to unlock in an emergency")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(remainingAllowance > 0 ? Color.red : Color.secondary)
            }
            .frame(height: 52)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginHold() }
                    .onEnded { _ in cancelHold() }
            )
            .disabled(remainingAllowance == 0)
            .opacity(remainingAllowance == 0 ? 0.5 : 1)

            Text(remainingAllowance == 0
                 ? "No emergency unlocks left this week"
                 : "\(remainingAllowance) left this week")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onDisappear { cancelHold() }
    }

    private func beginHold() {
        guard holdTask == nil, remainingAllowance > 0 else { return }
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
