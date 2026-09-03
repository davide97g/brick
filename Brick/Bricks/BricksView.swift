import BrickKit
import SwiftUI

/// Every paired tag. One is the brick; several are stations — a slab on the
/// desk, a sticker under a shelf, one by the front door.
struct BricksView: View {
    @Environment(AppModel.self) private var model

    private var controller: BrickController { model.controller }
    private var bricks: [BrickTag] { controller.state.tags }

    var body: some View {
        List {
            Section {
                if bricks.isEmpty {
                    Text("Nothing paired yet.").foregroundStyle(Theme.ash)
                } else {
                    ForEach(bricks) { brick in
                        NavigationLink {
                            BrickDetailView(uid: brick.uid)
                        } label: {
                            row(brick)
                        }
                    }
                }
            } header: {
                InkSectionHeader(text: "Paired")
            }

            Section {
                Button(model.scanning ? "Hold near the tag" : "Pair another") {
                    Task { await model.scan { try await controller.pairBrick() } }
                }
                .foregroundStyle(canPair ? Theme.chalk : Theme.graphite)
                .disabled(!canPair)
            } footer: {
                Text(controller.activeSession != nil
                     ? "You can't pair while a session is running."
                     : "Any NFC tag works. A printed cover makes it something you can leave on a shelf.")
                    .foregroundStyle(Theme.ash)
            }

            Section {
                Button(model.scanning ? "Hold near the tag" : "Join a shared brick") {
                    Task { await model.scan { try await controller.pairBrick(writeIdentity: false) } }
                }
                .foregroundStyle(canPair ? Theme.chalk : Theme.graphite)
                .disabled(!canPair)
            } header: {
                InkSectionHeader(text: "Shared")
            } footer: {
                Text("Pairs a brick someone else already set up without writing to it. One object on the table, a phone each: every phone keeps its own setups, its own sessions and its own quota, and nothing is synced between them.")
                    .foregroundStyle(Theme.ash)
            }
        }
        .inkList("Bricks")
    }

    private var canPair: Bool {
        !model.scanning && controller.activeSession == nil
    }

    private func row(_ brick: BrickTag) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(brick.displayName).foregroundStyle(Theme.chalk)
            Text(detail(brick))
                .font(.footnote)
                .foregroundStyle(Theme.ash)
        }
        .padding(.vertical, 2)
    }

    private func detail(_ brick: BrickTag) -> String {
        var parts: [String] = []
        if !brick.placeNote.isEmpty { parts.append(brick.placeNote) }
        if let setup = controller.state.profile(id: brick.profileID) {
            parts.append(setup.name)
        }
        parts.append(String(brick.uid.suffix(6)))
        return parts.joined(separator: " · ")
    }
}

/// One station: what it's called, where it lives, and what a tap on it starts.
struct BrickDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let uid: String

    @State private var name = ""
    @State private var placeNote = ""
    @State private var loaded = false

    private var controller: BrickController { model.controller }
    private var brick: BrickTag? { controller.state.tag(withUID: uid) }

    var body: some View {
        List {
            Section {
                TextField("Name", text: $name, prompt: Text("desk slab"))
                    .foregroundStyle(Theme.chalk)
                TextField("Where you keep it", text: $placeNote, prompt: Text("on your desk"))
                    .foregroundStyle(Theme.chalk)
            } footer: {
                Text("The shield names this brick and where it is, so a blocked app tells you where to walk.")
                    .foregroundStyle(Theme.ash)
            }

            Section {
                Picker(selection: setupBinding) {
                    ForEach(controller.state.profiles) { setup in
                        Text(setup.name.isEmpty ? "Untitled" : setup.name)
                            .tag(Optional(setup.id))
                    }
                    Text("Ask each time").tag(UUID?.none)
                } label: {
                    Text("Starts").foregroundStyle(Theme.chalk)
                }
            } header: {
                InkSectionHeader(text: "What a tap starts")
            }

            Section {
                LabeledContent {
                    Text(String(uid.suffix(6))).monospaced().foregroundStyle(Theme.ash)
                } label: {
                    Text("Tag").foregroundStyle(Theme.chalk)
                }
                if let pairedAt = brick?.pairedAt {
                    LabeledContent {
                        Text(Format.day(pairedAt)).foregroundStyle(Theme.ash)
                    } label: {
                        Text("Paired").foregroundStyle(Theme.chalk)
                    }
                }
            }

            Section {
                Button("Unpair this brick") {
                    do {
                        try controller.unpairTag(uid: uid)
                        dismiss()
                    } catch {
                        model.present(error)
                    }
                }
                .foregroundStyle(controller.activeSession != nil ? Theme.graphite : Theme.oxide)
                .disabled(controller.activeSession != nil)
            } footer: {
                Text(controller.activeSession != nil
                     ? "You can't unpair while a session is running."
                     : "It also leaves any exit route it was part of.")
                    .foregroundStyle(Theme.ash)
            }
        }
        .inkList(brick?.displayName ?? "Brick")
        .task {
            name = brick?.name ?? ""
            placeNote = brick?.placeNote ?? ""
            loaded = true
        }
        .onChange(of: name) { _, newValue in
            guard loaded else { return }
            controller.updateTag(uid: uid, name: newValue)
        }
        .onChange(of: placeNote) { _, newValue in
            guard loaded else { return }
            controller.updateTag(uid: uid, placeNote: newValue)
        }
    }

    private var setupBinding: Binding<UUID?> {
        Binding(
            get: { brick?.profileID },
            set: { controller.updateTag(uid: uid, profileID: .some($0)) }
        )
    }
}
