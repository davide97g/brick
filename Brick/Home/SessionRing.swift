import SwiftUI

struct SessionRing: View {
    var progress: Double
    var remaining: TimeInterval
    var caption: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ringTrack, lineWidth: 14)

            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(Theme.sessionGradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.9), value: progress)

            VStack(spacing: 6) {
                Text(Format.countdown(remaining))
                    .font(.system(size: 52, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 34)
        }
        .frame(width: 260, height: 260)
    }
}
