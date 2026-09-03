import BrickKit
import SwiftUI

/// The occasions the phone can be bricked for. One is the shipped product;
/// several is the point of having several bricks.
struct SetupsView: View {
    @Environment(AppModel.self) private var model

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
                .onDelete(perform: delete)
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
        var parts = [setup.summary, Format.duration(setup.defaultDuration)]
        let bricks = controller.state.tags.filter { $0.profileID == setup.id }.count
        if bricks > 0 { parts.append("\(bricks) brick\(bricks == 1 ? "" : "s")") }
        let steps = setup.exitRoute.count
        if steps > 1 { parts.append("\(steps)-tap exit") }
        return parts.joined(separator: " · ")
    }

    /// Deleting the setup a session is running under is refused by the
    /// controller: the rules a session started under are the rules it ends
    /// under.
    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            do {
                try controller.removeProfile(id: setups[index].id)
            } catch {
                model.present(error)
            }
        }
    }
}
