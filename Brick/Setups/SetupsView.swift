import BrickKit
import SwiftUI

/// The occasions the phone can be bricked for. One is the shipped product;
/// several is the point of having several bricks.
struct SetupsView: View {
    @Environment(AppModel.self) private var model
    @State private var pendingDeletion: BlockProfile?

    private var controller: BrickController { model.controller }
    private var setups: [BlockProfile] { controller.state.profiles }

    var body: some View {
        List {
            Section {
                ForEach(setups) { setup in
                    NavigationLink {
                        SetupDetailView(setupID: setup.id)
                    } label: {
                        row(setup)
                    }
                }
                .onDelete { offsets in
                    pendingDeletion = offsets.first.map { setups[$0] }
                }
            } footer: {
                Text("A brick starts the setup it belongs to, so the bedside sticker can mean something different from the one on your desk.")
                    .foregroundStyle(Theme.ash)
            }

            Section {
                Button("Add a setup") {
                    controller.addProfile(BlockProfile(name: "New setup"))
                }
                .foregroundStyle(Theme.chalk)
            }
        }
        .inkList("Setups")
        .confirmationDialog(
            "Delete \(pendingDeletion?.name ?? "this setup")?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let setup = pendingDeletion { delete(setup) }
                pendingDeletion = nil
            }
            Button("Keep it", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("What it blocks goes with it, and choosing those apps again is a job. Its bricks stay paired.")
        }
    }

    private func row(_ setup: BlockProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(setup.name.isEmpty ? "Untitled" : setup.name)
                .foregroundStyle(Theme.chalk)
            Text(detail(setup))
                .font(.footnote)
                .foregroundStyle(Theme.ash)
        }
        .padding(.vertical, 2)
    }

    private func detail(_ setup: BlockProfile) -> String {
        var parts = [setup.summary]
        // The default length means nothing in reverse; what a tap buys does.
        if setup.mode == .reverse {
            parts.append("opens \(Format.duration(setup.permitDuration)), \(setup.permitAllowance)× a day")
        } else {
            parts.append(Format.duration(setup.defaultDuration))
        }
        let bricks = controller.state.tags.filter { $0.profileID == setup.id }.count
        if bricks > 0 { parts.append("\(bricks) brick\(bricks == 1 ? "" : "s")") }
        let steps = setup.exitRoute.count
        if steps > 1 { parts.append("\(steps)-tap walk back") }
        return parts.joined(separator: " · ")
    }

    /// Deleting the setup a session is running under — or the last one left —
    /// is refused by the controller: the rules a session started under are the
    /// rules it ends under, and every screen needs a setup to point at.
    private func delete(_ setup: BlockProfile) {
        do {
            try controller.removeProfile(id: setup.id)
        } catch {
            model.present(error)
        }
    }
}
