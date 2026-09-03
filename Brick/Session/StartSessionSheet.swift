import BrickKit
import SwiftUI

struct StartSessionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Double
    @State private var setupID: UUID?

    private let options: [Double] = [15, 30, 45, 60, 90, 120, 180, 240, 360, 480]

    init(defaultDuration: TimeInterval) {
        _minutes = State(initialValue: max(15, (defaultDuration / 60).rounded()))
    }

    private var controller: BrickController { model.controller }

    private var setup: BlockProfile {
        controller.state.profile(id: setupID) ?? controller.state.profiles.first ?? BlockProfile()
    }

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
                    if controller.state.profiles.count > 1 { setupControl }

                    if setup.minimumDuration > 0 {
                        Text(lockNotice)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ashOnPaper)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            await model.scan {
                                try await controller.startSessionUsingKey(
                                    duration: .brickMinutes(minutes),
                                    profileID: setupID
                                )
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
        .task {
            setupID = controller.state.profiles.first?.id
        }
    }

    /// With a brick there is nothing to choose here: the tag decides, which is
    /// the whole point of having more than one.
    @ViewBuilder
    private var setupControl: some View {
        switch controller.unlockMethod {
        case .brick:
            Text("The brick you tap decides which setup starts.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ashOnPaper)
                .multilineTextAlignment(.center)
        case .biometric:
            Picker(selection: setupBinding) {
                ForEach(controller.state.profiles) { option in
                    Text(option.name.isEmpty ? "Untitled" : option.name).tag(Optional(option.id))
                }
            } label: {
                Text("Setup")
            }
            .pickerStyle(.segmented)
        }
    }

    private var setupBinding: Binding<UUID?> {
        Binding(
            get: { setupID },
            set: { newValue in
                setupID = newValue
                // Each setup carries its own default length; switching should
                // bring it with it rather than keep the last one's.
                if let chosen = controller.state.profile(id: newValue) {
                    minutes = max(15, (chosen.defaultDuration / 60).rounded())
                }
            }
        )
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
        let locked = min(setup.minimumDuration, .brickMinutes(minutes))
        let subject = controller.unlockMethod == .brick ? "The brick" : controller.biometricName
        return "\(subject) won't end this for the first \(Format.duration(locked))."
    }
}
