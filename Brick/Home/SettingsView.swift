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
                }

                TextField("Where you keep it", text: $placeNote, prompt: Text("on your desk"))
                    .foregroundStyle(Theme.chalk)
                    .onSubmit { controller.updatePlaceNote(placeNote) }
            } header: {
                InkSectionHeader(text: "Your brick")
            }

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

    /// Screenshot hook: `-uiPreview blocklist` pushes straight through to it.
    private var blocklistPreviewBinding: Binding<Bool> {
        #if DEBUG
        Binding(get: { model.uiPreview == "blocklist" }, set: { _ in })
        #else
        .constant(false)
        #endif
    }
}
