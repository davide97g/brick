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
        ZStack {
            Theme.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .engraved()
                        .frame(minWidth: 60, minHeight: 44, alignment: .leading)
                    Spacer()
                    Text("New session").engraved(Theme.chalk)
                    Spacer()
                    Color.clear.frame(width: 60, height: 44)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Text(Format.duration(.brickMinutes(minutes)))
                        .readout(size: 66)
                        .foregroundStyle(Theme.chalk)
                        .contentTransition(.numericText())

                    Text("ends at \(Format.clockTime(controller.now.addingTimeInterval(.brickMinutes(minutes))))")
                        .engraved()
                }

                Picker("Length", selection: $minutes) {
                    ForEach(options, id: \.self) { option in
                        Text(Format.duration(.brickMinutes(option)))
                            .foregroundStyle(Theme.chalk)
                            .tag(option)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                .padding(.top, 4)

                Spacer(minLength: 0)

                PaperCard {
                    if controller.state.blocklist.minimumDuration > 0 {
                        Text(lockNotice)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ashOnPaper)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            await model.scan {
                                try await controller.startSessionUsingKey(duration: .brickMinutes(minutes))
                            }
                            if controller.activeSession != nil { dismiss() }
                        }
                    } label: {
                        Text(startButtonTitle)
                    }
                    .buttonStyle(SolidPill())
                    .disabled(model.scanning)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var startButtonTitle: String {
        switch controller.unlockMethod {
        case .brick:
            return model.scanning ? "Hold near your brick" : "Tap your brick to start"
        case .biometric:
            return "Start with \(controller.biometricName)"
        }
    }

    private var lockNotice: String {
        let locked = min(controller.state.blocklist.minimumDuration, .brickMinutes(minutes))
        let subject = controller.unlockMethod == .brick ? "The brick" : controller.biometricName
        return "\(subject) won't end this for the first \(Format.duration(locked))."
    }
}
