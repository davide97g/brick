import BrickKit
import FamilyControls
import SwiftUI

/// One occasion: what it blocks, how long it runs, and which bricks it belongs
/// to. The only place the app touches `FamilyActivitySelection` — it is encoded
/// to bytes immediately and handed to BrickKit, which never decodes it.
struct SetupDetailView: View {
    @Environment(AppModel.self) private var model
    let setupID: UUID

    // `includeEntireCategory: true` is load-bearing. With the default `false`,
    // picking a category hands back a token that shields nothing: the apps
    // inside it are never covered, and a session blocks absolutely nothing
    // while the UI claims "1 category". Verified on device.
    @State private var selection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var pickerShown = false
    @State private var loaded = false
    @State private var name = ""

    private var controller: BrickController { model.controller }

    /// A setup deleted from under this screen leaves it showing a blank; the
    /// fallback keeps the bindings valid until the pop happens.
    private var setup: BlockProfile {
        controller.state.profile(id: setupID) ?? BlockProfile()
    }

    private var isRunning: Bool {
        controller.activeSession != nil
            && controller.activeProfile.id == setupID
    }

    private var isArmed: Bool { controller.armedProfile?.id == setupID }

    private var modeBinding: Binding<ProfileMode> {
        Binding(
            get: { setup.mode },
            set: { newValue in
                do {
                    try controller.setMode(newValue, forProfile: setupID)
                } catch {
                    model.present(error)
                }
            }
        )
    }

    private var allowanceBinding: Binding<Int> {
        Binding(
            get: { setup.permitAllowance },
            set: { newValue in
                var updated = setup
                updated.permitAllowance = newValue
                controller.updateProfile(updated)
            }
        )
    }

    private var bricks: [BrickTag] {
        controller.state.tags.filter { $0.profileID == setupID }
    }

    var body: some View {
        List {
            Section {
                TextField("Name", text: $name, prompt: Text("Deep work"))
                    .foregroundStyle(Theme.chalk)
                    .onSubmit { rename() }

                Button {
                    pickerShown = true
                } label: {
                    HStack {
                        Text("Apps, categories and sites")
                            .foregroundStyle(Theme.chalk)
                        Spacer()
                        Text(setup.summary)
                            .foregroundStyle(Theme.ash)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.graphite)
                    }
                }
                .disabled(isRunning)
            } footer: {
                Text(setup.mode == .block
                     ? "Changes apply to your next session, not the one running."
                     : "Changes apply the next time this goes up.")
                    .foregroundStyle(Theme.ash)
            }

            Section {
                if setup.mode == .block {
                    durationPicker(
                        title: "Default",
                        value: setup.defaultDuration,
                        options: [15, 30, 45, 60, 90, 120, 180, 240, 360, 480]
                    ) { newValue in
                        var updated = setup
                        updated.defaultDuration = max(.brickMinimumSession, newValue)
                        controller.updateProfile(updated)
                    }
                }

                durationPicker(
                    title: setup.mode == .block ? "Locked for at least" : "Stands for at least",
                    value: setup.minimumDuration,
                    options: setup.mode == .block
                        ? [0, 5, 15, 30, 45, 60, 90, 180, 360]
                        : [60, 180, 360, 720, 1440]
                ) { newValue in
                    var updated = setup
                    updated.minimumDuration = max(0, newValue)
                    controller.updateProfile(updated)
                }
            } header: {
                InkSectionHeader(text: setup.mode == .block ? "Session length" : "How long it stands")
            } footer: {
                Text(setup.mode == .block
                     ? "Until the minimum has passed, tapping the brick won't end the session — that's what makes it a commitment rather than a switch. Emergency unlocks still work."
                     : "How long it has to stand before it can be taken down.")
                    .foregroundStyle(Theme.ash)
            }

            Section {
                Picker(selection: modeBinding) {
                    Text("Tap to block").tag(ProfileMode.block)
                    Text("Tap to open").tag(ProfileMode.reverse)
                } label: {
                    Text("Direction").foregroundStyle(Theme.chalk)
                }
                .pickerStyle(.segmented)
                .disabled(isRunning || isArmed)

                if setup.mode == .reverse {
                    Picker(selection: allowanceBinding) {
                        ForEach(1...6, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    } label: {
                        Text("Openings a day").foregroundStyle(Theme.chalk)
                    }

                    durationPicker(
                        title: "Each opening",
                        value: setup.permitDuration,
                        options: [15, 30, 45, 60]
                    ) { newValue in
                        var updated = setup
                        updated.permitDuration = max(.brickMinimumSession, newValue)
                        controller.updateProfile(updated)
                    }
                }
            } header: {
                InkSectionHeader(text: "Direction")
            } footer: {
                Text(setup.mode == .block
                     ? "Tapping a brick blocks these apps for a while."
                     : "These apps stay blocked. Tapping a brick opens them for one window, then they close again — and taking the whole thing down is behind the minimum above.")
                    .foregroundStyle(Theme.ash)
            }

            if setup.mode == .block {
                Section {
                    NavigationLink {
                        ExitRouteView(setupID: setupID)
                    } label: {
                        LabeledContent {
                            Text(routeSummary).foregroundStyle(Theme.ash)
                        } label: {
                            Text("Way out").foregroundStyle(Theme.chalk)
                        }
                    }
                } footer: {
                    Text(routeFooter).foregroundStyle(Theme.ash)
                }
            }

            Section {
                if bricks.isEmpty {
                    Text("No brick starts this one yet.")
                        .foregroundStyle(Theme.ash)
                } else {
                    ForEach(bricks) { brick in
                        LabeledContent {
                            Text(String(brick.uid.suffix(6)))
                                .monospaced()
                                .foregroundStyle(Theme.ash)
                        } label: {
                            Text(brick.displayName).foregroundStyle(Theme.chalk)
                        }
                    }
                }
            } header: {
                InkSectionHeader(text: "Started by")
            } footer: {
                Text("Tapping one of these bricks starts this setup. Assign them under Bricks.")
                    .foregroundStyle(Theme.ash)
            }
        }
        .inkList(setup.name.isEmpty ? "Setup" : setup.name)
        .familyActivityPicker(isPresented: $pickerShown, selection: $selection)
        .onChange(of: selection) { _, newValue in
            guard loaded else { return }
            persist(newValue)
        }
        .task {
            name = setup.name
            if let existing = try? SelectionCoder.decode(setup.selectionData) {
                selection = SelectionCoder.wholeCategories(existing)
            }
            loaded = true
        }
        .onChange(of: name) { _, _ in rename() }
    }

    private var routeSummary: String {
        switch setup.exitRoute.count {
        case 0: return "The brick that started it"
        case 1: return controller.state.tag(withUID: setup.exitRoute[0])?.displayName ?? "1 tap"
        default: return "\(setup.exitRoute.count) taps"
        }
    }

    private var routeFooter: String {
        switch setup.exitRoute.count {
        case 0:
            return "Ending early means tapping the brick you started with. Add steps to make it a walk instead — including a different brick from the one that started it."
        case 1:
            return "Ending early means tapping this brick, wherever it is."
        default:
            return "Tap them in this order. A wrong tag, or a pause longer than the window, starts the walk again."
        }
    }

    private func rename() {
        var updated = setup
        updated.name = name
        controller.updateProfile(updated)
    }

    private func durationPicker(
        title: String,
        value: TimeInterval,
        options: [Double],
        onChange: @escaping (TimeInterval) -> Void
    ) -> some View {
        Picker(selection: Binding(get: { value }, set: onChange)) {
            ForEach(options, id: \.self) { minutes in
                Text(minutes == 0 ? "No minimum" : Format.duration(.brickMinutes(minutes)))
                    .tag(TimeInterval.brickMinutes(minutes))
            }
        } label: {
            Text(title).foregroundStyle(Theme.chalk)
        }
    }

    private func persist(_ newValue: FamilyActivitySelection) {
        var updated = setup
        updated.selectionData = try? SelectionCoder.encode(newValue)
        updated.appCount = newValue.applicationTokens.count
        updated.categoryCount = newValue.categoryTokens.count
        updated.webDomainCount = newValue.webDomainTokens.count
        controller.updateProfile(updated)
    }
}
