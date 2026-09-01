import BrickKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var placeNote = ""

    private var controller: BrickController { model.controller }

    var body: some View {
        List {
            Section("Your brick") {
                NavigationLink("What it blocks") { BlocklistView() }

                if let tag = controller.state.tag {
                    LabeledContent("Tag", value: String(tag.uid.suffix(6)))
                        .monospaced()
                    LabeledContent("Paired", value: Format.day(tag.pairedAt))
                }

                TextField("Where you keep it", text: $placeNote, prompt: Text("on your desk"))
                    .onSubmit { controller.updatePlaceNote(placeNote) }
            }

            Section {
                Button("Unpair brick", role: .destructive) {
                    do {
                        try controller.unpairBrick()
                    } catch {
                        model.present(error)
                    }
                }
                .disabled(controller.activeSession != nil)
            } footer: {
                Text(controller.activeSession != nil
                     ? "You can't unpair while a session is running."
                     : "Pairing a different brick starts from scratch.")
            }

            if !controller.state.history.isEmpty {
                Section("History") {
                    ForEach(controller.state.history.reversed()) { session in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Format.duration(session.elapsed(at: session.endedAt ?? session.plannedEnd)))
                                .font(.body.weight(.medium))
                            Text(Format.day(session.startedAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                EmptyView()
            } footer: {
                Text("Brick keeps everything on this iPhone. No account, no sync, no analytics, no network requests.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { placeNote = controller.state.tag?.placeNote ?? "" }
        .onChange(of: placeNote) { _, newValue in controller.updatePlaceNote(newValue) }
    }
}
