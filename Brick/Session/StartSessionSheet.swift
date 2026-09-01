import BrickKit
import SwiftUI

struct StartSessionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Double

    private let options: [Double] = [15, 30, 45, 60, 90, 120, 180, 240, 360, 480]

    init(defaultDuration: TimeInterval) {
        _minutes = State(initialValue: max(15, (defaultDuration / 60).rounded()))
    }

    private var controller: BrickController { model.controller }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Text(Format.duration(.brickMinutes(minutes)))
                    .font(.system(size: 64, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text("Ends at \(Format.clockTime(controller.now.addingTimeInterval(.brickMinutes(minutes))))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Length", selection: $minutes) {
                    ForEach(options, id: \.self) { option in
                        Text(Format.duration(.brickMinutes(option))).tag(option)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 140)

                if controller.state.blocklist.minimumDuration > 0 {
                    Label(
                        "The brick won't end this for the first \(Format.duration(min(controller.state.blocklist.minimumDuration, .brickMinutes(minutes)))).",
                        systemImage: "lock"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }

                Spacer()

                Button {
                    Task {
                        await model.scan {
                            try await controller.startSessionByTap(duration: .brickMinutes(minutes))
                        }
                        if controller.activeSession != nil { dismiss() }
                    }
                } label: {
                    Text(model.scanning ? "Hold near your brick…" : "Tap your brick to start")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.scanning)
            }
            .padding(24)
            .navigationTitle("Start a session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
