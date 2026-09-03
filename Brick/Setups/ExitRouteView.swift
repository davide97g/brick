import BrickKit
import SwiftUI

/// The walk that ends a session early: an ordered list of bricks to tap.
///
/// One step is the original product — go back to the object. Several make the
/// price of leaving a route through the flat, and a first step that isn't the
/// brick you started at is the cross-key: start at the desk, only the kitchen
/// lets you out.
struct ExitRouteView: View {
    @Environment(AppModel.self) private var model
    let setupID: UUID

    private var controller: BrickController { model.controller }

    private var setup: BlockProfile {
        controller.state.profile(id: setupID) ?? BlockProfile()
    }

    private var isRunning: Bool {
        controller.activeSession != nil && controller.activeProfile.id == setupID
    }

    /// A tag appears once: a route that sent you back to the same shelf twice
    /// would be theatre rather than distance.
    private var addableBricks: [BrickTag] {
        controller.state.tags.filter { !setup.exitRoute.contains($0.uid) }
    }

    var body: some View {
        List {
            Section {
                if setup.exitRoute.isEmpty {
                    Text("The brick that started it")
                        .foregroundStyle(Theme.ash)
                } else {
                    ForEach(Array(setup.exitRoute.enumerated()), id: \.element) { index, uid in
                        step(index: index, uid: uid)
                    }
                    .onMove { source, destination in
                        var route = setup.exitRoute
                        route.move(fromOffsets: source, toOffset: destination)
                        write(route)
                    }
                    .onDelete { offsets in
                        var route = setup.exitRoute
                        route.remove(atOffsets: offsets)
                        write(route)
                    }
                }
            } header: {
                InkSectionHeader(text: "Taps, in order")
            } footer: {
                Text(footer).foregroundStyle(Theme.ash)
            }

            if !addableBricks.isEmpty {
                Section {
                    ForEach(addableBricks) { brick in
                        Button {
                            write(setup.exitRoute + [brick.uid])
                        } label: {
                            HStack {
                                Text(brick.displayName).foregroundStyle(Theme.chalk)
                                Spacer()
                                Text(brick.placeNote)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.ash)
                            }
                        }
                        .disabled(isRunning)
                    }
                } header: {
                    InkSectionHeader(text: "Add a step")
                }
            }

            if setup.exitRoute.count > 1 {
                Section {
                    Picker(selection: windowBinding) {
                        ForEach([5.0, 10.0, 20.0, 30.0], id: \.self) { minutes in
                            Text(Format.duration(.brickMinutes(minutes)))
                                .tag(TimeInterval.brickMinutes(minutes))
                        }
                    } label: {
                        Text("Walk expires after").foregroundStyle(Theme.chalk)
                    }
                } footer: {
                    Text("A pause longer than this, or a tap on the wrong brick, starts the walk again.")
                        .foregroundStyle(Theme.ash)
                }
            }
        }
        .inkList("The walk back")
        .toolbar {
            if setup.exitRoute.count > 1 {
                EditButton().foregroundStyle(Theme.chalk)
            }
        }
    }

    private func step(index: Int, uid: String) -> some View {
        HStack(spacing: 14) {
            Text("\(index + 1)")
                .engraved(Theme.graphite)
                .frame(width: 12, alignment: .leading)
            Text(controller.state.tag(withUID: uid)?.displayName ?? "Missing brick")
                .foregroundStyle(Theme.chalk)
            Spacer()
            Text(controller.state.tag(withUID: uid)?.placeNote ?? "")
                .font(.footnote)
                .foregroundStyle(Theme.ash)
        }
    }

    private var footer: String {
        if isRunning {
            return "This setup is running. Its way out is fixed until the session ends."
        }
        switch setup.exitRoute.count {
        case 0:
            return "Ending early means going back to whichever brick started the session."
        case 1:
            return "Ending early means tapping this brick — which doesn't have to be the one that started the session."
        default:
            return "Tap them in this order. Getting it wrong costs the whole walk."
        }
    }

    private var windowBinding: Binding<TimeInterval> {
        Binding(
            get: { setup.routeWindow },
            set: { newValue in
                var updated = setup
                updated.routeWindow = newValue
                controller.updateProfile(updated)
            }
        )
    }

    private func write(_ route: [String]) {
        do {
            try controller.setExitRoute(route, forProfile: setupID)
        } catch {
            model.present(error)
        }
    }
}
