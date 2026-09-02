import BrickKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var placeNote = ""
    @State private var reviewCode = ""

    private var controller: BrickController { model.controller }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    BlocklistView()
                } label: {
                    Text("What it blocks").foregroundStyle(Theme.chalk)
                }

                LabeledContent {
                    Text(controller.unlockMethod == .brick ? "The brick" : controller.biometricName)
                        .foregroundStyle(Theme.ash)
                } label: {
                    Text("Way in and out").foregroundStyle(Theme.chalk)
                }

                if let tag = controller.state.tag {
                    LabeledContent {
                        Text(String(tag.uid.suffix(6)))
                            .monospaced()
                            .foregroundStyle(Theme.ash)
                    } label: {
                        Text("Tag").foregroundStyle(Theme.chalk)
                    }

                    LabeledContent {
                        Text(Format.day(tag.pairedAt)).foregroundStyle(Theme.ash)
                    } label: {
                        Text("Paired").foregroundStyle(Theme.chalk)
                    }

                    // Only meaningful when there is an object to be somewhere.
                    TextField("Where you keep it", text: $placeNote, prompt: Text("on your desk"))
                        .foregroundStyle(Theme.chalk)
                        .onSubmit { controller.updatePlaceNote(placeNote) }
                }
            } header: {
                InkSectionHeader(text: controller.state.isPaired ? "Your brick" : "Your setup")
            }

            Section {
                if controller.unlockMethod == .brick {
                    Button("Use \(controller.biometricName) instead") {
                        Task { await model.scan { try await controller.useBiometricUnlock() } }
                    }
                    .foregroundStyle(controller.canSwitchKey ? Theme.chalk : Theme.graphite)
                    .disabled(!controller.canSwitchKey)
                } else {
                    Button(controller.state.isPaired ? "Go back to the brick" : "Pair a brick") {
                        Task { await switchToBrick() }
                    }
                    .foregroundStyle(model.scanning ? Theme.graphite : Theme.chalk)
                    .disabled(model.scanning || controller.activeSession != nil)
                }
            } footer: {
                Text(keyFooter).foregroundStyle(Theme.ash)
            }

            if controller.state.isPaired {
                Section {
                    Button("Unpair brick") {
                        do {
                            try controller.unpairBrick()
                        } catch {
                            model.present(error)
                        }
                    }
                    .foregroundStyle(controller.activeSession != nil ? Theme.graphite : Theme.oxide)
                    .disabled(controller.activeSession != nil)
                } footer: {
                    Text(controller.activeSession != nil
                         ? "You can't unpair while a session is running."
                         : "Pairing a different brick starts from scratch.")
                        .foregroundStyle(Theme.ash)
                }
            }

            if !controller.state.history.isEmpty {
                Section {
                    ForEach(controller.state.history.reversed()) { session in
                        HStack(alignment: .firstTextBaseline) {
                            Text(Format.duration(session.elapsed(at: session.endedAt ?? session.plannedEnd)))
                                .font(.system(size: 16, weight: .regular))
                                .monospacedDigit()
                                .foregroundStyle(Theme.chalk)
                            Spacer()
                            Text(Format.day(session.startedAt))
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.ash)
                        }
                    }
                } header: {
                    InkSectionHeader(text: "History")
                }
            }

            Section {
                if model.demoTag.isEnabled {
                    Button("Turn off demo tag") { model.demoTag.disable() }
                        .foregroundStyle(Theme.oxide)
                } else {
                    TextField("Access code", text: $reviewCode, prompt: Text("access code"))
                        .foregroundStyle(Theme.chalk)
                        .monospaced()
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .onSubmit {
                            if !model.demoTag.enable(withCode: reviewCode) {
                                model.alert = AlertContent(
                                    title: "That code isn't right",
                                    message: "Leave this alone unless you were given a code."
                                )
                            }
                            reviewCode = ""
                        }
                }
            } header: {
                InkSectionHeader(text: "App Review")
            } footer: {
                Text(model.demoTag.isEnabled
                     ? "Demo tag is on. Sessions start and end without an NFC tag, and the brick stops being the way in. Turn it off to use your own brick."
                     : "For App Review. A code here replaces the NFC tag with a simulated one, so the app can be tested without a brick.")
                    .foregroundStyle(Theme.ash)
            }

            Section {
                EmptyView()
            } footer: {
                Text("Brick keeps everything on this iPhone. No account, no sync, no analytics, no network requests.")
                    .foregroundStyle(Theme.ash)
            }
        }
        .inkList("Settings")
        .navigationDestination(isPresented: blocklistPreviewBinding) { BlocklistView() }
        .task { placeNote = controller.state.tag?.placeNote ?? "" }
        .onChange(of: placeNote) { _, newValue in controller.updatePlaceNote(newValue) }
    }

    /// Switching back means having a brick again: pair one if there is none.
    private func switchToBrick() async {
        await model.scan {
            if controller.state.isPaired {
                try controller.useBrickUnlock()
            } else {
                try await controller.pairBrick()
            }
        }
    }

    private var keyFooter: String {
        if controller.activeSession != nil {
            return "You can't change the way out while a session is running."
        }
        switch controller.unlockMethod {
        case .brick:
            return controller.biometricsAvailable
                ? "\(controller.biometricName) works when you have no brick. It is weaker: the key stays in your hand, so only the minimum duration and your emergency unlocks hold."
                : "\(controller.biometricName) isn't set up on this iPhone, so the brick is the only way out."
        case .biometric:
            return "\(controller.biometricName) starts and ends sessions. The brick is the stronger version: the way out sits across the room."
        }
    }

    /// Screenshot hook: `-uiPreview blocklist` pushes straight through to it.
    private var blocklistPreviewBinding: Binding<Bool> {
        #if DEBUG
        Binding(get: { model.uiPreview == "blocklist" }, set: { _ in })
        #else
        .constant(false)
        #endif
    }
}
